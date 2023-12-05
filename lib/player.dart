import 'package:flutter/material.dart';

class Player {
  final String name;
  final Color color;
  int score = 0;

  Player(this.name, this.color);

  @override
  String toString() {
    // ToDo: This looks incomplete:
    return 'Player($color)';
  }
}
