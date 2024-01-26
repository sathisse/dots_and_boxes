import 'package:flutter/material.dart';

class Player {
  final String name;
  final Color color;
  int score = 0;
  bool isGone = false;

  Player(this.name, this.color);

  @override
  String toString() {
    return 'Player($name, $color, $score, $isGone)';
  }
}
