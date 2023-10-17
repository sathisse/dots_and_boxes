// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/material.dart';
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

class GameConnection extends StatefulWidget {
  final Function onConnected;

  const GameConnection({required this.onConnected, super.key});

  @override
  State<GameConnection> createState() => _GameConnection();
}

class _GameConnection extends State<GameConnection> {
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                if (value.length == 6) {
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
      ),
    );
  }

  void startPubnub() async {
    numPlayers = 1;
    uuid = const Uuid().v4();
    pubnub = PubNub(
        defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
    print('My userId is $uuid');
  }

  void createGameId() async {
    gameId = const Uuid().v4().substring(0, 6);
    numPlayers = 1;
  }

  void unsubscribeFromChannel() async {
    try {
      print('Unsubscribing from channel');
      await subscription.cancel();
      print('Unsubscribed from channel');
    } catch (e) {
      print('remote unsubscribe call failed (probably due to no subscription active)');
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
      // print('x: ${message.originalMessage}');
      if (message.uuid.toString() == uuid) {
        print('Sent message ${message.payload}');
      } else {
        print('Received message "${message.payload}"');
      }

      MsgType msgType =
          MsgType.values.firstWhere((mt) => mt.name == json.decode(message.payload['msgType']));
      switch (msgType) {
        case MsgType.join:
          var userId = message.uuid.value;
          print(">>>>> Join-request  message from user $userId");
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
          print(">>>>> Player-added message with $userId, $playerId, and $numberOfDots dots");
          if (userId == UserId(uuid).value) {
            print("That's me! Let's configure the game...");
            playerId = newPlayerId;
          } else {
            print("Someone else was added; there's nothing to do.");
          }
          break;
        case MsgType.rejected:
          String userId = json.decode(message.payload['userId']);
          print(">>>>> Player-rejected message with $userId");
          if (userId == UserId(uuid).value) {
            print("That's me! Let's let the player know that that can't join the game...");
          } else {
            print("Someone else was rejected; there's nothing to do.");
          }
          break;
        case MsgType.line:
          var line = json.decode(message.payload['line']);
          print(">>>>> Line-requested message with $line");
          break;
        case MsgType.leave:
          print(">>>>> Leave-game message");
          break;
      }
    });

    isConnected = true;
    widget.onConnected();
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
      print('Max players already joined!');
    }
  }
}
