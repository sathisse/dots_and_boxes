import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pubnub/pubnub.dart';
import 'package:uuid/uuid.dart';

// ignore: unused_import
import 'dots_and_boxes_game.dart';

// ignore: unused_import
import 'lobby.dart';

late final String uuid;
late final PubNub pubnub;

void main() {
  startPubNub();
  runApp(const ProviderScope(child: MyApp()));
}

const windowMargin = 8.0;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dots and Boxes',
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Dots and Boxes Game'),
        ),
        body: Center(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: windowMargin, vertical: windowMargin),
              child: const DotsAndBoxesGame()),
              // child: const Lobby()),
        ),
      ),
    );
  }
}

void startPubNub() async {
  uuid = const Uuid().v4();
  pubnub =
      PubNub(defaultKeyset: Keyset(subscribeKey: 'demo', publishKey: 'demo', userId: UserId(uuid)));
  debugPrint('My userId is $uuid');
}
