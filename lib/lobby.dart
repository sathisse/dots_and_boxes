import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pubnub/pubnub.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'main.dart' show uuid, pubnub;
import 'lobby_manager.dart' show LobbyManagerMsgType;

import 'create_new_game_dialog.dart';
import 'game_info.dart';

class Lobby extends StatefulWidget {
  const Lobby({super.key});

  @override
  State<Lobby> createState() => _Lobby();
}

class _Lobby extends State<Lobby> {
  _Lobby();

  late Subscription subscription;
  late Channel channel;

  late AutoScrollController scrollController;
  late List<GameInfo> gameList;
  late String selectedGameId;

  @override
  void initState() {
    super.initState();

    scrollController = AutoScrollController(
        viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
        axis: Axis.vertical);

    gameList = [];
    selectedGameId = '';

    subscribeToLobbyChannel();

    _sendRequestListMsgToMgr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const Row(children: [
          SizedBox(width: 40),
          if (kDebugMode)
            Expanded(
                flex: 10,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('GameId', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Dots', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Players', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Game Status', style: TextStyle(fontWeight: FontWeight.bold))))
        ]),
        const SizedBox(height: 10),
        Expanded(
            child: ListView(
                scrollDirection: Axis.vertical,
                controller: scrollController,
                children: gameList.asMap().entries.map<Widget>((item) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 0.0),
                      child: getRow(item.key, item.value));
                }).toList())),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, semanticLabel: 'Leave game'),
          tooltip: 'Create new game',
          onPressed: () {
            setState(() {
              Navigator.of(context).push(CreateNewGameDialog<void>(createNewGame: createNewGame));
            });
          },
        ),
      ]),
    );
  }

  Widget getRow(int index, GameInfo item) {
    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      highlightColor: Colors.white.withOpacity(0.1),
      child: GestureDetector(
        onTap: () {
          debugPrint("Game ${item.gameId} pressed");
          scrollToItem(item.gameId);
        },
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                  color: item.gameId != selectedGameId ? Colors.white10 : Colors.white60),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              color: Colors.black.withAlpha(25)),
          child: Row(children: [
            IconButton(
                tooltip: 'Join game',
                onPressed: () {
                  scrollToItem(item.gameId);
                  debugPrint(
                      'Joining game ${item.gameId}, with ${item.numDots} dots and ${item.numPlayers} players');
                  _sendStartGameMsgToMgr(uuid, item.gameId);
                },
                icon: const Icon(Icons.play_circle_outline)),
            // if (kDebugMode)
            Expanded(flex: 10, child: Align(alignment: Alignment.center, child: Text(item.gameId))),
            Expanded(
                flex: 33,
                child: Align(alignment: Alignment.center, child: Text(item.numDots.toString()))),
            Expanded(
                flex: 33,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('${item.numJoined} of ${item.numPlayers}'))),
            Expanded(
                flex: 33,
                child: Align(alignment: Alignment.center, child: Text(item.status.label))),
          ]),
        ),
      ),
    );
  }

  void scrollToItem(String gameId) async {
    setState(() {
      selectedGameId = gameId;
    });
    scrollToSelected();
  }

  void scrollToSelected() async {
    final index = gameList.indexWhere((item) => item.gameId == selectedGameId);
    // debugPrint('scroll index is $index');
    await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    await scrollController.highlight(index);
  }

  void createNewGame(String gameId, int numDots, int numPlayers) {
    if (gameId == 'Local') {
      debugPrint('Starting local-only game');
    } else {
      _sendCreateGameToMgr(
          uuid, GameInfo(gameId: gameId, numDots: numDots, numPlayers: numPlayers));
      debugPrint('Requested creation of game $gameId with $numDots dots and $numPlayers players.');
    }
  }

  //
  // PubNub Methods
  //

  void unsubscribeFromLobbyChannel() async {
    try {
      debugPrint('Unsubscribing from lobby channel');
      await subscription.cancel();
    } catch (e) {
      debugPrint('Remote unsubscribe call failed (probably due to no subscription active)');
    }
  }

  void subscribeToLobbyChannel() async {
    debugPrint('Subscribing to lobby channel');
    unsubscribeFromLobbyChannel();

    var channelName = 'DotsAndBoxes.lobby';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // Sets up a listener for new messages:
    subscription.messages.forEach((message) => handleMessageFromManager(message));
  }

  //
  // Lobby Message Methods
  //

  void handleMessageFromManager(message) {
    if (message.uuid.toString() == uuid) {
      debugPrint('Sent a message to lobby: "${message.payload}"');
    } else {
      debugPrint('Received a message from lobby: "${message.payload}"');
    }

    switch (LobbyManagerMsgType.values
        .firstWhere((mt) => mt.name == json.decode(message.payload['msgType']))) {
      case LobbyManagerMsgType.updateList:
        debugPrint(">>>>> Update-list message");
        setState(() {
          gameList = (json.decode(message.payload['gameList']) as List)
              .map((i) => GameInfo.fromJson(i))
              .toList()
            ..sort();
        });
        scrollToSelected();
        break;

      case LobbyManagerMsgType.created:
        debugPrint(">>>>> Created message");
        final requestingUserId = json.decode(message.payload['userId']);
        if (requestingUserId == uuid) {
          final GameInfo newGame = GameInfo.fromJson(json.decode(message.payload['game']));
          gameList.add(newGame);
          gameList.sort();
          scrollToItem(newGame.gameId);
        }
        break;

      case LobbyManagerMsgType.joined:
        debugPrint(">>>>> Joined message");
        final userId = json.decode(message.payload['userId']);
        final GameInfo game = GameInfo.fromJson(json.decode(message.payload['game']));
        debugPrint('user $userId joined game ${game.gameId} as player ${game.numJoined}');

        setState(() {
          // ToDo: Probably should validate that the game was in fact still in the list:
          gameList[gameList.indexWhere((g) => g.gameId == game.gameId)] = game;
          debugPrint('gameList is now $gameList');
        });
        // ToDo: Start the game.
        break;

      case LobbyManagerMsgType.rejected:
        debugPrint(">>>>> Rejected message");
        final userId = json.decode(message.payload['userId']);
        final String rejectionMsg = json.decode(message.payload['rejectionMsg']);
        debugPrint('user $userId was rejected because "$rejectionMsg"');
        // ToDo: Inform the user.
        break;

      // The following lobby messages are not ignored by the lobby:
      case LobbyManagerMsgType.requestList:
      case LobbyManagerMsgType.createGame:
      case LobbyManagerMsgType.joinGame:
        break;
    }

    setState(() {});
  }

  void _sendRequestListMsgToMgr() async {
    await channel.publish({"msgType": json.encode(LobbyManagerMsgType.requestList.name)});
  }

  void _sendCreateGameToMgr(String userId, GameInfo game) async {
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.createGame.name),
      "userId": json.encode(userId),
      "game": json.encode(game)
    });
    // "gameList": json.encode([game].toList().map((game) => game.toJson()).toList())});
  }

  void _sendStartGameMsgToMgr(String userId, String gameId) async {
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.joinGame.name),
      "userId": json.encode(userId),
      "gameId": json.encode(gameId)
    });
  }
}
