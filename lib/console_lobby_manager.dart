import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

//import 'package:path_provider/path_provider.dart';
import 'package:pubnub/pubnub.dart';
import 'package:uuid/uuid.dart';

import 'game_info.dart';

enum LobbyManagerMsgType {
  requestList, // Lobby-->Mgr
  updateList, //  Mgr-->Lobby
  createGame, //  Lobby-->Mgr
  created, //     Mgr-->Lobby
  joinGame, //    Lobby-->Mgr
  joined, //      Mgr-->Lobby
  rejected, //    Mgr-->Lobby
}

const int secsToWaitForStartupCheck = 3;
const int secsBetweenGameListUpdates = 20;

final log = Logger('Logger');

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  _LobbyManager();
}

class _LobbyManager {
  late Timer startupTimer;
  bool startupFinished = false;

  late Timer updateTimer;
  bool gameChangesMade = false;

  late final PubNub pubnub;
  late final String uuid;

  late Subscription subscription;
  late Channel channel;

  late List<GameInfo> gameList = [];

  Future<File> get _gameListFile async {
    return File('./gameList.json');
  }

  Future<File> saveGameList() async {
    log.info('Saving game list...');
    final file = await _gameListFile;

    // Write the game list to file:
    return file.writeAsString(json.encode(gameList.toList().map((game) => game.toJson()).toList()));
  }

  Future<List<GameInfo>> loadGameList() async {
    log.info('Loading game list...');
    try {
      final file = await _gameListFile;

      // Read the file
      final gameListJson = await file.readAsString();

      return (json.decode(gameListJson) as List).map((i) => GameInfo.fromJson(i)).toList()..sort();
    } catch (e) {
      log.severe("Unable to load game list!");
      return List<GameInfo>.empty();
    }
  }

  _LobbyManager() {
    initializeState();
  }

  void initializeState() async {
    log.info('**************************');
    log.info('* Starting lobby manager *');
    log.info('**************************');

    gameList = await loadGameList();
    if (gameList.isEmpty) {
      gameList = <GameInfo>[
        GameInfo(gameId: '001', numDots: 12, numPlayers: 2),
        GameInfo(gameId: '002', numDots: 12, numPlayers: 2),
        GameInfo(gameId: '003', numDots: 20, numPlayers: 3),
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
      saveGameList();
    } else {
      log.info('Game list is not empty.');
    }

    startPubnub();
    subscribeToLobbyChannel();

    log.info('Checking for already running instance...');
    _sendRequestListMsgToMgr();

    startupTimer = Timer(const Duration(seconds: secsToWaitForStartupCheck), () {
      startupFinished = true;
      log.info('No existing manager found; continuing startup');
      _sendUpdateListMsgToLobby();

      updateTimer = Timer.periodic(
        const Duration(seconds: secsBetweenGameListUpdates),
        (timer) {
          if (gameChangesMade) {
            gameChangesMade = false;
            _sendUpdateListMsgToLobby();
          } else {
            log.info('No changes made; suppressing update');
          }
        },
      );
    });
  }

  //
  // PubNub Methods
  //

  void startPubnub() async {
    uuid = const Uuid().v4();
    pubnub = PubNub(
        defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
    log.info('My userId is $uuid');
  }

  void unsubscribeFromLobbyChannel() async {
    try {
      log.info('Unsubscribing from lobby channel');
      await subscription.cancel();
    } catch (e) {
      log.warning('Unsubscribe call failed (probably due to no subscription yet active)');
    }
  }

  void subscribeToLobbyChannel() async {
    log.info('Subscribing to lobby channel');
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
    bool senderIsMe = false;
    if (message.uuid.toString() == uuid) {
      senderIsMe = true;
      log.info('Sent a message to lobby: "${message.payload}"');
    } else {
      log.info('Received a message from lobby: "${message.payload}"');
    }

    switch (LobbyManagerMsgType.values
        .firstWhere((mt) => mt.name == json.decode(message.payload['msgType']))) {
      case LobbyManagerMsgType.requestList:
        log.info(">>>>> Request-list-game message");
        if (!senderIsMe) {
          _sendUpdateListMsgToLobby();
        }
        break;

      case LobbyManagerMsgType.updateList:
        // The only way we receive this is 1) we sent it, or 2) another running mgr sent it:
        if (startupFinished || senderIsMe) {
          // Either we've finished startup or we sent it, so there's nothing to worry about.
        } else {
          // An already running manager sent it during ur startup; exit immediately.
          log.warning("An already running manager detected; unsubscribing immediately!");
          subscription.cancel();
          startupTimer.cancel();
          exit(-1);
        }
        break;

      case LobbyManagerMsgType.createGame:
        log.info(">>>>> Create-game message");
        final userId = json.decode(message.payload['userId']);
        final GameInfo newGame = GameInfo.fromJson(json.decode(message.payload['game']));
        gameList.add(newGame);
        gameChangesMade = true;
        _sendCreatedMsgToLobby(userId, newGame);
        break;

      case LobbyManagerMsgType.joinGame:
        log.info(">>>>> Join-game message");
        final userId = json.decode(message.payload['userId']);
        final String gameId = json.decode(message.payload['gameId']);
        final GameInfo? game = gameList.where((item) => item.gameId == gameId).firstOrNull;
        if (game == null) {
          _sendRejectedMsgToLobby(userId, "That game doesn't exist.");
        } else {
          if (game.status == GameStatus.playing) {
            _sendRejectedMsgToLobby(userId, 'That game is already full and playing.');
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

    if (gameChangesMade) {
      saveGameList();
    }
  }

  // Send request-list message. This will cause any already running managers to reply with
  //   a game list. This will notify this run not to function as a manager.
  void _sendRequestListMsgToMgr() async {
    await channel.publish({"msgType": json.encode(LobbyManagerMsgType.requestList.name)});
  }

  void _sendUpdateListMsgToLobby() async {
    // appendMessageToLog('in _sendUpdateListMsgToLobby(")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.updateList.name),
      "gameList": json.encode(gameList.toList().map((game) => game.toJson()).toList())
    });
  }

  void _sendCreatedMsgToLobby(String userId, GameInfo game) async {
    // appendMessageToLog('in _sendCreatedMsgToLobby(userId:|$userId|, game:|$game|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.created.name),
      "userId": json.encode(userId),
      "game": json.encode(game)
    });
  }

  void _sendJoinedMsgToLobby(String userId, GameInfo game) async {
    // appendMessageToLog('in _sendJoinedMsgToLobby(userId:|$userId|, game:|$game|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.joined.name),
      "userId": json.encode(userId),
      "game": json.encode(game)
    });
  }

  void _sendRejectedMsgToLobby(String userId, String msg) async {
    // appendMessageToLog('in _sendRejectedMsgToLobby(userId:|$userId|, msg:|$msg|")');
    await channel.publish({
      "msgType": json.encode(LobbyManagerMsgType.rejected.name),
      "userId": json.encode(userId),
      "rejectionMsg": json.encode(msg)
    });
  }
}
