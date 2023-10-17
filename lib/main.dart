import 'package:flutter/material.dart';
import 'dots_and_boxes_game.dart';

void main() {
  runApp(const MyApp());
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
        ),
      ),
    );
  }
}
