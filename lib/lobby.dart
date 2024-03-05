import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pubnub/pubnub.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'create_new_game_dialog.dart';
import 'dots_and_boxes_game.dart';
import 'game_info.dart';
import 'lobby_manager.dart' show LobbyManagerMsgType;
import 'main.dart' show uuid, pubnub;

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
        if (gameList.isNotEmpty)
          Expanded(
            flex: 95,
            child: Column(
              children: [
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
                          child:
                              Text('Game Status', style: TextStyle(fontWeight: FontWeight.bold))))
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
              ],
            ),
          ),
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              TextButton.icon(
                label: const Text('Local game'),
                icon: const Icon(Icons.add_circle_outline, semanticLabel: 'Create local game'),
                onPressed: () {
                  setState(() {
                    Navigator.push(context,
                        CreateNewGameDialog(localGame: true, createNewGame: createNewGame));
                  });
                },
              ),
              const Spacer(),
              TextButton.icon(
                label: const Text('Network game'),
                icon: const Icon(Icons.add_circle_outline, semanticLabel: 'Create network game'),
                onPressed: () {
                  setState(() {
                    Navigator.of(context)
                        .push(CreateNewGameDialog(localGame: false, createNewGame: createNewGame));
                  });
                },
              ),
              const Spacer(),
            ],
          ),
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
                  _sendJoinGameMsgToMgr(uuid, item.gameId);
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
    await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    await scrollController.highlight(index);
  }

  void createNewGame(String gameId, int numDots, int numPlayers) {
    debugPrint('in createNewGame(gameId:|$gameId|, numDots:|$numDots|, numPlayers:|$numPlayers|")');
    if (gameId == 'Local') {
      // ignore: unused_local_variable
      final localGame = GameInfo(gameId: gameId, numDots: numDots, numPlayers: numPlayers)
        ..numJoined = numPlayers;
      debugPrint('Starting local-only game');
      // ToDo: Why doesn't it work to navigate here, but does in the message handler?
      // Navigator.push(
      //     savedContext,
      //     MaterialPageRoute(
      //         builder: (savedContext) =>
      //             DotsAndBoxesGame(game: GameInfo(gameId: 'Local', numDots: 6, numPlayers: 3))));
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => DotsAndBoxesGame(game: localGame)));
      // debugPrint('After Navigator push');
      _sendCreateGameToMgr(
          uuid, GameInfo(gameId: gameId, numDots: numDots, numPlayers: numPlayers));
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
        final creatingUserId = json.decode(message.payload['userId']);
        if (creatingUserId == uuid) {
          final GameInfo newGame = GameInfo.fromJson(json.decode(message.payload['game']));

          if (newGame.gameId == 'Local') {
            // ToDo: Why does navigation work here, but not in the createNewGame callback?
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => DotsAndBoxesGame(game: newGame)));
          } else {
            gameList.add(newGame);
            gameList.sort();
            scrollToItem(newGame.gameId);

            _sendJoinGameMsgToMgr(uuid, newGame.gameId);
          }
        }
        break;

      case LobbyManagerMsgType.joined:
        debugPrint(">>>>> Joined message");
        final userId = json.decode(message.payload['userId']);
        final joiningUserId = json.decode(message.payload['userId']);
        if (joiningUserId == uuid) {
          final GameInfo game = GameInfo.fromJson(json.decode(message.payload['game']));
          debugPrint('user $userId joined game ${game.gameId} as player ${game.numJoined}');

          setState(() {
            // ToDo: Probably should validate that the game was in fact still in the list:
            gameList[gameList.indexWhere((g) => g.gameId == game.gameId)] = game;
            debugPrint('gameList is now $gameList');
          });
          gameList.sort();
          scrollToItem(game.gameId);

          Navigator.push(
              context, MaterialPageRoute(builder: (context) => DotsAndBoxesGame(game: game)));
        }
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
  }

  void _sendJoinGameMsgToMgr(String userId, String gameId) async {
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.joinGame.name),
      "userId": json.encode(userId),
      "gameId": json.encode(gameId)
    });
  }
}
