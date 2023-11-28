import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pubnub/pubnub.dart';
import 'package:uuid/uuid.dart';

import 'dots_and_boxes_game.dart';
import 'line.dart';

enum MsgType {
  join,
  added,
  rejected,
  line,
  leave;
}

const gameIdLength = 3;

final gameActionsProvider =
    StateProvider<List<String>>((ref) => <String>["<no connected players>"]);

class GameConnection extends ConsumerStatefulWidget {
  final Function onConnected;

  const GameConnection({required this.onConnected, super.key});

  @override
  ConsumerState<GameConnection> createState() => _GameConnection();
}

class _GameConnection extends ConsumerState<GameConnection> {
  _GameConnection();

  late final String uuid;
  late final PubNub pubnub;

  late bool createGame;
  late String gameId;
  late String statusTxt;
  late int numPlayers;
  late bool isConnected;

  late Subscription subscription;
  late Channel channel;
  late Who playerId;

  @override
  void initState() {
    createGame = false;
    gameId = "";
    statusTxt = "";
    numPlayers = 1;
    isConnected = false;
    playerId = Who.nobody;

    startPubnub();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(children: [
          if (!isConnected)
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                const Text('Create new game?'),
                Checkbox(
                    value: createGame,
                    onChanged: (bool? value) {
                      createGame = value ?? false;
                      setState(() {
                        if (createGame) {
                          createGameId();
                          subscribeToChannel(creator: true);
                        } else {
                          unsubscribeFromChannel();
                          gameId = '';
                        }
                      });
                      setState(() {});
                    }),
              ]),
              SizedBox(
                width: 100.0,
                child: TextFormField(
                  controller: TextEditingController()..text = gameId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Game ID',
                  ),
                  enabled: !createGame,
                  maxLength: 6,
                  onChanged: (value) {
                    if (value.length == gameIdLength) {
                      gameId = value;
                      subscribeToChannel();
                      setState(() {});
                    }
                  },
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 25.0),
              Text(statusTxt),
              const SizedBox(height: 25.0),
              IconButton(
                icon: const Icon(Icons.arrow_right_alt),
                onPressed: isConnected ? _sendLineMsg : null,
              ),
              IconButton(
                icon: const Icon(Icons.person_remove),
                onPressed: isConnected ? _sendLeaveMsg : null,
              ),
            ]),
        ]),
      ),
    );
  }

  void startPubnub() async {
    numPlayers = 1;
    uuid = const Uuid().v4();
    pubnub = PubNub(
        defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
    debugPrint('My userId is $uuid');
  }

  void createGameId() async {
    gameId = const Uuid().v4().substring(0, gameIdLength);
    debugPrint('Game ID: $gameId');
    numPlayers = 1;
  }

  void unsubscribeFromChannel() async {
    try {
      debugPrint('Unsubscribing from channel');
      await subscription.cancel();
      debugPrint('Unsubscribed from channel');
    } catch (e) {
      debugPrint('remote unsubscribe call failed (probably due to no subscription active)');
    }

    isConnected = false;
    statusTxt = 'Unsubscribed from channel';
  }

  void subscribeToChannel({bool creator = false}) async {
    unsubscribeFromChannel();

    // ToDo: How to know if gameId is valid for non-creators?
    var channelName = 'DotsAndBoxes.$gameId';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // ToDo: if retrying gameId, we dob;t seem to be subscribing to the new channel:
    // Sets up a listener for new messages:
    subscription.messages.forEach((message) {
      // debugPrint('x: ${message.originalMessage}');
      if (message.uuid.toString() == uuid) {
        debugPrint('Sent message ${message.payload}');
      } else {
        debugPrint('Received message "${message.payload}"');
      }

      MsgType msgType =
          MsgType.values.firstWhere((mt) => mt.name == json.decode(message.payload['msgType']));
      switch (msgType) {
        case MsgType.join:
          var userId = message.uuid.value;
          debugPrint(">>>>> Join-request  message from user $userId");
          if (playerId == Who.p1) {
            _addPlayer(userId);
          } else {
            _sendRejectedMsg(userId);
          }
          break;
        case MsgType.added:
          String userId = json.decode(message.payload['userId']);
          var newPlayerId =
              Who.values.firstWhere((w) => w.name == json.decode(message.payload['playerId']));
          int numberOfDots = json.decode(message.payload['numberOfDots']);
          debugPrint(">>>>> Player-added message with $userId, $playerId, and $numberOfDots dots");

          // ref.read(gameActionsProvider.notifier).state.add("anotherAction");
          ref.read(gameActionsProvider.notifier).state = ref
              .read(gameActionsProvider.notifier)
              .state
              .toList()
            ..add("${players[newPlayerId]?.name} joined");

          if (userId == UserId(uuid).value) {
            debugPrint("That's me! Let's configure the game...");
            playerId = newPlayerId;
          } else {
            debugPrint("Someone else was added; there's nothing to do.");
          }
          break;
        case MsgType.rejected:
          String userId = json.decode(message.payload['userId']);
          debugPrint(">>>>> Player-rejected message with $userId");
          if (userId == UserId(uuid).value) {
            debugPrint("That's me! Let's let the player know that that can't join the game...");
          } else {
            debugPrint("Someone else was rejected; there's nothing to do.");
          }
          break;
        case MsgType.line:
          var line = json.decode(message.payload['line']);
          debugPrint(">>>>> Line-requested message with $line");
          break;
        case MsgType.leave:
          debugPrint(">>>>> Leave-game message");
          break;
      }
    });

    isConnected = true;
    widget.onConnected(gameId);
    statusTxt = "Subscribed to '$channelName' as ${creator ? 'p1' : 'non-creator'}";

    if (creator) {
      playerId = Who.p1;
    } else {
      _sendJoinMsg();
    }

    setState(() {});
  }

  void _sendJoinMsg() async {
    await channel.publish({"msgType": json.encode(MsgType.join.name)});
  }

  void _sendAddedMsg(String userId, Who playerId) async {
    await channel.publish({
      "msgType": json.encode(MsgType.added.name),
      "userId": json.encode(userId),
      "playerId": json.encode(playerId.name),
      "numberOfDots": json.encode(12)
    });
  }

  void _sendRejectedMsg(String userId) async {
    await channel
        .publish({"msgType": json.encode(MsgType.rejected.name), "userId": json.encode(userId)});
  }

  void _sendLineMsg() async {
    var aLine = Line((0, 0), (1, 0), drawer: Who.p1);
    await channel.publish({"msgType": json.encode(MsgType.line.name), "line": json.encode(aLine)});
  }

  void _sendLeaveMsg() async {
    await channel.publish({"msgType": json.encode(MsgType.leave.name)});
  }

  void _addPlayer(userId) {
    if (numPlayers < Who.values.length - 1) {
      numPlayers++;
      _sendAddedMsg(userId, Who.values[numPlayers]);
    } else {
      debugPrint('Max players already joined!');
    }
  }
}
