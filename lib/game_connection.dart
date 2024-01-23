import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pubnub/pubnub.dart';
import 'package:uuid/uuid.dart';

import 'dots_and_boxes_game.dart';
import 'game_size_slider.dart';
import 'line.dart';

enum MsgType {
  join, // Both
  added, // comm only
  addedMe, // action only
  addedOther, // Action only
  rejected,
  line, // Both
  leave;
}

const gameIdLength = 3;

final gameActionsProvider =
    StateProvider<List<dynamic>>((ref) => <dynamic>["<no connected players>"]);

final localLineProvider = StateProvider<Line>((ref) => Line((-1, -1), (-1, -1)));

class GameConnection extends ConsumerStatefulWidget {
  final void Function(MapEntry<int, (int, int)>) configureBoard;
  final void Function(String gameId, int playerIndex, int numPlayers, int joinedPlayers)
      onConnected;

  const GameConnection({required this.configureBoard, required this.onConnected, super.key});

  @override
  ConsumerState<GameConnection> createState() => _GameConnection();
}

class _GameConnection extends ConsumerState<GameConnection> {
  _GameConnection();

  late final String uuid;
  late final PubNub pubnub;

  late bool createGame;
  late String gameId;
  late int playerIndex;
  late int joinedPlayers;
  late int numPlayers;
  late bool isConnected;

  late Subscription subscription;
  late Channel channel;

  @override
  void initState() {
    createGame = false;
    gameId = "";
    playerIndex = 0;
    numPlayers = 2;
    joinedPlayers = 1;
    isConnected = false;

    startPubnub();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localLineProvider, onLineRequested);

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
                        } else {
                          unsubscribeFromChannel();
                          gameId = '';
                        }
                      });
                      setState(() {});
                    }),
              ]),
              SizedBox(
                width: 120.0,
                child: TextFormField(
                  controller: TextEditingController()..text = gameId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Game ID',
                  ),
                  enabled: !createGame,
                  maxLength: gameIdLength,
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
              Column(
                children: [
                  DropdownMenu<int>(
                    initialSelection: 2,
                    requestFocusOnTap: false,
                    enabled: createGame,
                    label: const Text("Number of Players"),
                    onSelected: (int? value) {
                      setState(() {
                        numPlayers = value!;
                      });
                    },
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 2, label: "2"),
                      DropdownMenuEntry(value: 3, label: "3"),
                      DropdownMenuEntry(value: 4, label: "4"),
                      DropdownMenuEntry(value: 5, label: "5"),
                    ],
                  ),
                  GameSizeSlider(configureBoard: widget.configureBoard, isEnabled: createGame),
                  ElevatedButton(
                      onPressed: !createGame
                          ? null
                          : () {
                              subscribeToChannel(creator: true);
                            },
                      child: const Text("Create Game"))
                ],
                // )
              )
            ]),
        ]),
      ),
    );
  }

  void startPubnub() async {
    uuid = const Uuid().v4();
    pubnub = PubNub(
        defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
    debugPrint('My userId is $uuid');
  }

  void createGameId() async {
    gameId = const Uuid().v4().substring(0, gameIdLength);
    debugPrint('Game ID: $gameId');
    joinedPlayers = 1;
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
  }

  void subscribeToChannel({bool creator = false}) async {
    debugPrint('Subscribing to channel');
    unsubscribeFromChannel();

    // ToDo: How to know if gameId is valid for non-creators?
    var channelName = 'DotsAndBoxes.$gameId';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // ToDo: if retrying gameId, we don't seem to be subscribing to the new channel:
    // Sets up a listener for new messages:
    subscription.messages.forEach((message) => handleMessage(message));

    if (creator) {
      playerIndex = 1;
      isConnected = true;
      widget.onConnected(gameId, playerIndex, numPlayers, joinedPlayers);
    } else {
      _sendJoinMsg();
    }

    setState(() {});
  }

  void handleMessage(message) {
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
        debugPrint(">>>>> Join-request message from user $userId");

        if (playerIndex == 1) {
          if (joinedPlayers < numPlayers) {
            _sendAddedMsg(userId, ++joinedPlayers);
          } else {
            debugPrint('The game is full!');
            _sendRejectedMsg(userId);
          }
        } else if (userId == UserId(uuid).value) {
          _appendMessageToState(message.payload);
        }
        break;
      case MsgType.added:
        final String userId = json.decode(message.payload['userId']);
        final int playerIndex = json.decode(message.payload['playerIndex']);
        numPlayers = json.decode(message.payload['numPlayers']);
        joinedPlayers = max(joinedPlayers, playerIndex);
        numberOfDots = json.decode(message.payload['numberOfDots']);
        debugPrint(">>>>> Player-added message with $userId, $playerIndex, $numberOfDots");

        if (userId == UserId(uuid).value) {
          debugPrint("That's me! Let's configure the game...");
          isConnected = true;
          widget.onConnected(gameId, playerIndex, numPlayers, joinedPlayers);
          _appendAddedMeMsg(playerIndex, numberOfDots);
        } else {
          debugPrint("Someone else was added; there's nothing to do.");
          _appendAddedOtherMsg(playerIndex);
        }
        break;

      case MsgType.addedMe:
      case MsgType.addedOther:
        // Not used for communication with other player(s)
        break;

      case MsgType.rejected:
        String userId = json.decode(message.payload['userId']);
        debugPrint(">>>>> Player-rejected message with $userId");

        if (userId == UserId(uuid).value) {
          debugPrint("That's me! Let's let the player know that that can't join the game...");
          _appendMessageToState(message.payload);
        } else {
          debugPrint("Someone else was rejected; there's nothing to do.");
        }
        break;

      case MsgType.line:
        debugPrint(">>>>> Line-requested message with ${json.decode(message.payload['line'])}");

        _appendMessageToState(message.payload);
        break;

      case MsgType.leave:
        debugPrint(">>>>> Leave-game message");
        break;
    }
  }

  _appendMessageToState(dynamic message) {
    // Update the state with a player-added message:
    ref.read(gameActionsProvider.notifier).state =
        ref.read(gameActionsProvider.notifier).state.toList()..add(message);
  }

  void _appendAddedMeMsg(int playerIndex, int numberOfDots) {
    dynamic message = {
      "msgType": json.encode(MsgType.addedMe.name),
      "joinedPlayers": json.encode(joinedPlayers),
      "playerIndex": json.encode(playerIndex),
      "numberOfDots": json.encode(numberOfDots)
    };
    _appendMessageToState(message);
  }

  void _appendAddedOtherMsg(int playerIndex) {
    dynamic message = {
      "msgType": json.encode(MsgType.addedOther.name),
      "joinedPlayers": json.encode(joinedPlayers),
      "playerIndex": json.encode(playerIndex)
    };
    _appendMessageToState(message);
  }

  void _sendJoinMsg() async {
    await channel.publish({"msgType": json.encode(MsgType.join.name)});
  }

  void _sendAddedMsg(String userId, int playerIndex) async {
    await channel.publish({
      "msgType": json.encode(MsgType.added.name),
      "userId": json.encode(userId),
      "numPlayers": json.encode(numPlayers),
      "playerIndex": json.encode(playerIndex),
      "numberOfDots": json.encode(numberOfDots)
    });
  }

  void _sendRejectedMsg(String userId) async {
    await channel
        .publish({"msgType": json.encode(MsgType.rejected.name), "userId": json.encode(userId)});
  }

  void _sendLineMsg(Line line) async {
    await channel.publish({"msgType": json.encode(MsgType.line.name), "line": json.encode(line)});
  }

// ignore: unused_element
  void _sendLeaveMsg() async {
    await channel.publish({"msgType": json.encode(MsgType.leave.name)});
  }

  onLineRequested(Line? previous, Line next) {
    debugPrint("Received a line request: $next");
    _sendLineMsg(next);
  }
}
