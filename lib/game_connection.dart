import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pubnub/pubnub.dart';
import 'package:uuid/uuid.dart';

import 'main.dart';
import 'game_size_slider.dart';
import 'line.dart';

enum GameMsgType {
  join,
  added,
  addedMe,
  addedOther,
  rejected,
  line,
  leave;
}

const gameIdLength = 3;

final commsToGuiProvider =
    StateProvider<List<dynamic>>((ref) => <dynamic>["<no connected players>"]);

final guiToCommsProvider =
    StateProvider<List<dynamic>>((ref) => <dynamic>[Line((-1, -1), (-1, -1))]);

class GameConnection extends ConsumerStatefulWidget {
  const GameConnection({super.key});

  @override
  ConsumerState<GameConnection> createState() => _GameConnection();
}

class _GameConnection extends ConsumerState<GameConnection> {
  _GameConnection();

  late bool createGame;
  late String gameId;
  late int playerIndex;
  late int numberOfDots;
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
    numberOfDots = 12;
    numPlayers = 2;
    joinedPlayers = 1;
    isConnected = false;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(guiToCommsProvider, handleMessageFromGui);

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
                          unsubscribeFromGameChannel();
                          gameId = '';
                        }
                      });
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
                      subscribeToGameChannel();
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
                  GameSizeSlider(setNumberOfDots: setNumberOfDots, isEnabled: createGame),
                  ElevatedButton(
                      onPressed: !createGame
                          ? null
                          : () {
                              subscribeToGameChannel(creator: true);
                            },
                      child: const Text("Create Game"))
                ],
              )
            ]),
        ]),
      ),
    );
  }

  void setNumberOfDots(int numberOfDots) {
    this.numberOfDots = numberOfDots;
  }

  //
  // PubNub Methods
  //

    void createGameId() async {
    gameId = const Uuid().v4().substring(0, gameIdLength);
    debugPrint('Game ID: $gameId');
    joinedPlayers = 1;
  }

  void unsubscribeFromGameChannel() async {
    try {
      debugPrint('Unsubscribing from channel');
      await subscription.cancel();
    } catch (e) {
      debugPrint('remote unsubscribe call failed (probably due to no subscription active)');
    }

    isConnected = false;
  }

  void subscribeToGameChannel({bool creator = false}) async {
    debugPrint('Subscribing to channel');
    unsubscribeFromGameChannel();

    // ToDo: How to know if gameId is valid for non-creators?
    var channelName = 'DotsAndBoxes.$gameId';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // ToDo: if retrying gameId, we don't seem to be subscribing to the new channel:
    // Sets up a listener for new messages:
    subscription.messages.forEach((message) => handleMessageFromComms(message));

    if (creator) {
      playerIndex = 1;
      isConnected = true;
      _sendAddedMeMsgToGui(gameId, playerIndex, numberOfDots, numPlayers, joinedPlayers);
    } else {
      _sendJoinMsgToComms();
    }

    setState(() {});
  }

  //
  // Comms-to-Comms Message Methods
  //

  void handleMessageFromComms(message) {
    if (message.uuid.toString() == uuid) {
      debugPrint('Comms: Sent a message to comms: "${message.payload}"');
    } else {
      debugPrint('Comms: Received a message from comms: "${message.payload}"');
    }

    switch (
        GameMsgType.values.firstWhere((mt) => mt.name == json.decode(message.payload['msgType']))) {
      case GameMsgType.join:
        var userId = message.uuid.value;
        debugPrint(">>>>> Join-request message from user $userId");

        if (playerIndex == 1) {
          if (joinedPlayers < numPlayers) {
            _sendAddedMsgToComms(userId, ++joinedPlayers);
          } else {
            debugPrint('The game is full!');
            _sendRejectedMsgToComms(userId);
          }
        } else if (userId == UserId(uuid).value) {
          _sendMessageToGui(message.payload);
        }
        break;
      case GameMsgType.added:
        final String userId = json.decode(message.payload['userId']);
        final int playerIndex = json.decode(message.payload['playerIndex']);
        numPlayers = json.decode(message.payload['numPlayers']);
        joinedPlayers = max(joinedPlayers, playerIndex);
        numberOfDots = json.decode(message.payload['numberOfDots']);
        debugPrint(">>>>> Player-added message with $userId, $playerIndex, $numberOfDots");

        if (userId == UserId(uuid).value) {
          debugPrint("That's me! Let's configure the game...");
          this.playerIndex = playerIndex;
          isConnected = true;
          _sendAddedMeMsgToGui(gameId, playerIndex, numberOfDots, numPlayers, joinedPlayers);
        } else {
          debugPrint("Someone else was added; there's nothing to do.");
          _sendAddedOtherMsgToGui(playerIndex);
        }
        break;

      case GameMsgType.addedMe:
      case GameMsgType.addedOther:
        // Not used for CommsToComms messages.
        break;

      case GameMsgType.rejected:
        String userId = json.decode(message.payload['userId']);
        debugPrint(">>>>> Player-rejected message with $userId");

        if (userId == UserId(uuid).value) {
          debugPrint("That's me! Let's let the player know that that can't join the game...");
          _sendMessageToGui(message.payload);
        } else {
          debugPrint("Someone else was rejected; there's nothing to do.");
        }
        break;

      case GameMsgType.line:
        debugPrint(">>>>> Line-requested message with ${json.decode(message.payload['line'])}");

        _sendMessageToGui(message.payload);
        break;

      case GameMsgType.leave:
        debugPrint(">>>>> Leave-game message");
        _sendMessageToGui(message.payload);
        break;
    }

    setState(() {});
  }

  void _sendMessageToComms(dynamic message) async {
    await channel.publish(message);
  }

  void _sendJoinMsgToComms() async {
    await channel.publish({"msgType": json.encode(GameMsgType.join.name)});
  }

  void _sendAddedMsgToComms(String userId, int playerIndex) async {
    await channel.publish({
      "msgType": json.encode(GameMsgType.added.name),
      "userId": json.encode(userId),
      "numPlayers": json.encode(numPlayers),
      "playerIndex": json.encode(playerIndex),
      "numberOfDots": json.encode(numberOfDots)
    });
  }

  void _sendRejectedMsgToComms(String userId) async {
    await channel.publish(
        {"msgType": json.encode(GameMsgType.rejected.name), "userId": json.encode(userId)});
  }

  //
  // To/from GUI Message Methods
  //

  void handleMessageFromGui(List<dynamic>? previous, List<dynamic> next) {
    debugPrint("Received a message from GUI: ${next.last}");

    final message = next.last;
    GameMsgType msgType =
        GameMsgType.values.firstWhere((mt) => mt.name == json.decode(message['msgType']));
    switch (msgType) {
      case GameMsgType.join:
      case GameMsgType.added:
      case GameMsgType.addedMe:
      case GameMsgType.addedOther:
      case GameMsgType.rejected:
        // Not used for GuiToComms messages.
        break;

      case GameMsgType.line:
        _sendMessageToComms(message);
        break;

      case GameMsgType.leave:
        _sendMessageToComms(message);
        gameId = "";
        isConnected = false;
        unsubscribeFromGameChannel();
        setState(() {});
        break;
    }
  }

  void _sendMessageToGui(dynamic message) {
    ref.read(commsToGuiProvider.notifier).state =
        ref.read(commsToGuiProvider.notifier).state.toList()..add(message);
  }

  void _sendAddedMeMsgToGui(
      String gameId, int playerIndex, int numberOfDots, int numPlayers, int joinedPlayers) {
    dynamic message = {
      "msgType": json.encode(GameMsgType.addedMe.name),
      "gameId": json.encode(gameId),
      "playerIndex": json.encode(playerIndex),
      "numberOfDots": json.encode(numberOfDots),
      "numPlayers": json.encode(numPlayers),
      "joinedPlayers": json.encode(joinedPlayers)
    };
    _sendMessageToGui(message);
  }

  void _sendAddedOtherMsgToGui(int playerIndex) {
    dynamic message = {
      "msgType": json.encode(GameMsgType.addedOther.name),
      "joinedPlayers": json.encode(joinedPlayers),
      "playerIndex": json.encode(playerIndex)
    };
    _sendMessageToGui(message);
  }
}
