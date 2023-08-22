import 'package:flutter/material.dart';
import 'dots_and_boxes_game.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Triangle Peg Game'),
        ),
        body: Center(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: const DotsAndBoxesGame()),
        ),
      ),
    );
  }
}
