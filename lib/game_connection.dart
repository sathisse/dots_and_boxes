import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pubnub/pubnub.dart';

import 'main.dart' show uuid, pubnub;
import 'line.dart';

enum GameMsgType {
  joinedGame,
  leftGame,
  addLine;
}

const gameIdLength = 3;

final commsToGuiProvider =
    StateProvider<List<dynamic>>((ref) => <dynamic>["<no connected players>"]);

final guiToCommsProvider =
    StateProvider<List<dynamic>>((ref) => <dynamic>[Line((-1, -1), (-1, -1))]);

// ToDo: this no longer needs to be a widget; how-to/can convert to use widget-less providers?
class GameConnection extends ConsumerStatefulWidget {
  final String gameId;

  const GameConnection({required this.gameId, super.key});

  @override
  ConsumerState<GameConnection> createState() => _GameConnection();
}

class _GameConnection extends ConsumerState<GameConnection> {
  _GameConnection();

  late bool isConnected;
  late Subscription subscription;
  late Channel channel;

  @override
  void initState() {
    super.initState();

    isConnected = false;

    subscribeToGameChannel();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(guiToCommsProvider, handleMessageFromGui);

    return const Scaffold();
  }

  //
  // PubNub Methods
  //

  void unsubscribeFromGameChannel() async {
    try {
      debugPrint('Unsubscribing from channel');
      await subscription.cancel();
    } catch (e) {
      debugPrint('remote unsubscribe call failed (probably due to no subscription active)');
    }

    isConnected = false;
  }

  void subscribeToGameChannel() async {
    debugPrint('Subscribing to channel');
    unsubscribeFromGameChannel();

    // ToDo: How to know if gameId is valid for non-creators?
    var channelName = 'DotsAndBoxes.${widget.gameId}';
    subscription = pubnub.subscribe(channels: {channelName});
    channel = pubnub.channel(channelName);

    // ToDo: if retrying gameId, we don't seem to be subscribing to the new channel:
    // Sets up a listener for new messages:
    subscription.messages.forEach((message) => handleMessageFromComms(message));
    isConnected = true;
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
      case GameMsgType.joinedGame:
        _sendMessageToGui(message.payload);
        break;

      case GameMsgType.addLine:
        debugPrint(">>>>> Line-requested message with ${json.decode(message.payload['line'])}");
        _sendMessageToGui(message.payload);
        break;

      case GameMsgType.leftGame:
        debugPrint(">>>>> Leave-game message");
        // final String userId = json.decode(message.payload['userId']);
        // if (userId != UserId(uuid).value) {
        //   debugPrint("That's me; nothing to do...");
        // } else {
          debugPrint("Someone left; let the GUI know.");
          _sendMessageToGui(message.payload);
        // }
        break;
    }

    setState(() {});
  }

  void _sendMessageToComms(dynamic message) async {
    await channel.publish(message);
  }

  void _sendJoinedGameMsgToComms(int numJoined) async {
    debugPrint('in _sendJoinedGameMsgToComms(numJoined:|$numJoined|")');
    await channel.publish(
        {"msgType": json.encode(GameMsgType.joinedGame.name),
         "numJoined": json.encode(numJoined)});
  }

  void _sendLeftGameMsgToComms(int playerIndex) async {
    debugPrint('in _sendLeftGameMsgToComms(playerIndex:|$playerIndex|")');
    await channel.publish({
      "msgType": json.encode(GameMsgType.leftGame.name),
      // "userId": json.encode(UserId(uuid).value),
      "playerIndex": json.encode(playerIndex)
    });
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
      case GameMsgType.joinedGame:
        int numJoined = json.decode(message['numJoined']);
        _sendJoinedGameMsgToComms(numJoined);
        break;

      case GameMsgType.addLine:
        _sendMessageToComms(message);
        break;

      case GameMsgType.leftGame:
        _sendLeftGameMsgToComms(json.decode(message['playerIndex']));
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
}
