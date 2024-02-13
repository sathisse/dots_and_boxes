import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pubnub/pubnub.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:uuid/uuid.dart';

import 'game_info.dart';

enum LobbyManagerMsgType {
  requestList, // Lobby-->Mgr
  updateList, // Mgr-->Lobby
  createGame, // Lobby-->Mgr
  created, // Mgr-->Lobby
  joinGame, // Lobby-->Mgr
  joined, // Mgr-->Lobby
  rejected, // Mgr-->Lobby
}

const windowMargin = 8.0;
const int secsToWaitForStartupCheck = 3;
const int secsBetweenGameListUpdates = 20;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dots and Boxes Lobby Manager',
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Dots and Boxes Lobby Manager'),
        ),
        body: Center(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: windowMargin, vertical: windowMargin),
              child: const LobbyManager()),
        ),
      ),
    );
  }
}

class LobbyManager extends StatefulWidget {
  const LobbyManager({super.key});

  @override
  State<LobbyManager> createState() => _LobbyManager();
}

typedef LogMsg = ({DateTime timestamp, String message});

class _LobbyManager extends State<LobbyManager> {
  _LobbyManager();

  late Timer startupTimer;
  bool startupFinished = false;

  late Timer updateTimer;
  bool gameChangesMade = false;

  late final PubNub pubnub;
  late final String uuid;

  late Subscription subscription;
  late Channel channel;

  late AutoScrollController scrollController;
  late List<GameInfo> gameList = [];

  List<LogMsg> msgLog = [];

  @override
  void initState() {
    super.initState();

    scrollController = AutoScrollController(
        viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
        axis: Axis.vertical);

    appendMessageToLog('Starting lobby manager');

    gameList = <GameInfo>[
      GameInfo(gameId: '001', numDots: 12, numPlayers: 2)..numJoined = 1,
      GameInfo(gameId: '002', numDots: 12, numPlayers: 3)..numJoined = 1,
      GameInfo(gameId: '003', numDots: 20, numPlayers: 2),
      GameInfo(gameId: '004', numDots: 24, numPlayers: 5)..numJoined = 4,
      GameInfo(gameId: '005', numDots: 24, numPlayers: 4)..numJoined = 1,
      GameInfo(gameId: '006', numDots: 36, numPlayers: 2),
      GameInfo(gameId: '007', numDots: 36, numPlayers: 3),
      GameInfo(gameId: '008', numDots: 54, numPlayers: 2)..numJoined = 2,
      GameInfo(gameId: '009', numDots: 60, numPlayers: 2),
      GameInfo(gameId: '010', numDots: 48, numPlayers: 3),
      GameInfo(gameId: '011', numDots: 12, numPlayers: 5)..numJoined = 1,
      GameInfo(gameId: '012', numDots: 12, numPlayers: 3)..numJoined = 1,
      GameInfo(gameId: '013', numDots: 20, numPlayers: 2),
      GameInfo(gameId: '014', numDots: 24, numPlayers: 2)..numJoined = 2,
      GameInfo(gameId: '015', numDots: 24, numPlayers: 4)..numJoined = 1,
      GameInfo(gameId: '016', numDots: 36, numPlayers: 2),
    ];
    gameList.sort();

    startPubnub();
    subscribeToLobbyChannel();

    appendMessageToLog('Checking for already running instance...');
    _sendRequestListMsgToMgr();
    startupTimer = Timer(const Duration(seconds: secsToWaitForStartupCheck), () {
      startupFinished = true;
      appendMessageToLog('No existing manager found; continuing startup');
      _sendUpdateListMsgToLobby();
      updateTimer = Timer.periodic(
        const Duration(seconds: secsBetweenGameListUpdates),
        (timer) {
          if (gameChangesMade) {
            gameChangesMade = false;
            _sendUpdateListMsgToLobby();
          } else {
            appendMessageToLog('No changes made; suppressing update');
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Expanded(
            child: ListView(
                scrollDirection: Axis.vertical,
                controller: scrollController,
                children: msgLog.asMap().entries.map<Widget>((item) {
                  return getRow(item.key, item.value);
                }).toList())),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, semanticLabel: 'Exit manager app'),
          tooltip: 'Exit app',
          onPressed: () {
            setState(() {
              exit(1);
            });
          },
        ),
      ]),
    );
  }

  Widget getRow(int index, LogMsg item) {
    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      highlightColor: Colors.white.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.timestamp.toString()),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(width: 25),
              Expanded(child: Text(item.message)),
            ],
          ),
        ],
      ),
    );
  }

  void scrollToEnd() async {
    await scrollController.scrollToIndex(msgLog.length - 1,
        preferPosition: AutoScrollPosition.begin);
  }

  void appendMessageToLog(String msg) {
    LogMsg logLine = (timestamp: DateTime.timestamp(), message: msg);
    msgLog.add(logLine);

    // Keep the log size manageable by removing all but the last N messages:
    msgLog = msgLog.getRange(max(msgLog.length - 1000, 0), msgLog.length).toList();
    setState(() {});
    scrollToEnd();

    debugPrint('${logLine.timestamp}: ${logLine.message}:');
  }

  //
  // PubNub Methods
  //

  void startPubnub() async {
    uuid = const Uuid().v4();
    pubnub = PubNub(
        defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
    appendMessageToLog('My userId is $uuid');
  }

  void unsubscribeFromLobbyChannel() async {
    try {
      appendMessageToLog('Unsubscribing from lobby channel');
      await subscription.cancel();
    } catch (e) {
      appendMessageToLog('Unsubscribe call failed (probably due to no subscription yet active)');
    }
  }

  void subscribeToLobbyChannel() async {
    appendMessageToLog('Subscribing to lobby channel');
    unsubscribeFromLobbyChannel();

    var channelName = 'DotsAndBoxes.lobby';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // Sets up a listener for new messages:
    subscription.messages.forEach((message) => handleMessageFromLobby(message));
  }

  //
  // Lobby Message Methods
  //

  void handleMessageFromLobby(message) {
    if (message.uuid.toString() == uuid) {
      appendMessageToLog('Sent a message to lobby: "${message.payload}"');
    } else {
      appendMessageToLog('Received a message from lobby: "${message.payload}"');
    }

    switch (LobbyManagerMsgType.values
        .firstWhere((mt) => mt.name == json.decode(message.payload['msgType']))) {
      case LobbyManagerMsgType.requestList:
        appendMessageToLog(">>>>> Request-list-game message");
        _sendUpdateListMsgToLobby();
        break;

      case LobbyManagerMsgType.updateList:
        // The only way we receive this is 1) we sent it, or 2) another running mgr sent it:
        if (startupFinished || message.uuid.toString() == uuid) {
          // Either we've finished startup or we sent it, so there's nothing to worry about.
        } else {
          // An already running manager sent it during ur startup; exit immediately.
          appendMessageToLog("An already running manager detected; unsubscribing immediately!");
          subscription.cancel();
          startupTimer.cancel();
        }
        break;

      case LobbyManagerMsgType.createGame:
        appendMessageToLog(">>>>> Create-game message");
        final userId = json.decode(message.payload['userId']);
        final GameInfo newGame = GameInfo.fromJson(json.decode(message.payload['game']));
        gameList.add(newGame);
        gameChangesMade = true;
        _sendCreatedMsgToLobby(userId, newGame);
        break;

      case LobbyManagerMsgType.joinGame:
        appendMessageToLog(">>>>> Join-game message");
        final userId = json.decode(message.payload['userId']);
        final String gameId = json.decode(message.payload['gameId']);
        final GameInfo? game = gameList.where((item) => item.gameId == gameId).firstOrNull;
        if (game == null) {
          _sendRejectedMsgToLobby(userId, "That game doesn't exist");
        } else {
          if (game.status == GameStatus.playing) {
            _sendRejectedMsgToLobby(userId, 'That game is already playing');
          } else {
            if (++game.numJoined == game.numPlayers) {
              game.status = GameStatus.playing;
            }
            gameChangesMade = true;
            _sendJoinedMsgToLobby(userId, game);
          }
        }
        break;

      // The following lobby messages are not ignored by the lobby manager:
      case LobbyManagerMsgType.created:
      case LobbyManagerMsgType.joined:
      case LobbyManagerMsgType.rejected:
        break;
    }

    scrollToEnd();
  }

  // Send request-list message. This will cause any already running managers to replay with
  //   a game list. This will notify this run to exit immediately.
  void _sendRequestListMsgToMgr() async {
    await channel.publish({"msgType": json.encode(LobbyManagerMsgType.requestList.name)});
  }

  void _sendUpdateListMsgToLobby() async {
    // appendMessageToLog('in _sendUpdateListMsgToLobby(")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.updateList.name),
      "gameList": json.encode(gameList.toList().map((game) => game.toJson()).toList())
    });
    scrollToEnd();
  }

  void _sendCreatedMsgToLobby(String userId, GameInfo game) async {
    appendMessageToLog('in _sendCreatedMsgToLobby(userId:|$userId|, game:|$game|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.created.name),
      "userId": json.encode(userId),
      "game": json.encode(game)
    });
    scrollToEnd();
  }

  void _sendJoinedMsgToLobby(String userId, GameInfo game) async {
    appendMessageToLog('in _sendJoinedMsgToLobby(userId:|$userId|, game:|$game|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.joined.name),
      "userId": json.encode(userId),
      "game": json.encode(game),
    });
    scrollToEnd();
  }

  void _sendRejectedMsgToLobby(String userId, String msg) async {
    appendMessageToLog('in _sendRejectedMsgToLobby(userId:|$userId|, msg:|$msg|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.rejected.name),
      "userId": json.encode(userId),
      "rejectionMsg": json.encode(msg)
    });
    scrollToEnd();
  }
}
