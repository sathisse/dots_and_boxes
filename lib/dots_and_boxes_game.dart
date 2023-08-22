// ignore_for_file: avoid_print

import 'dart:core';
import 'package:flutter/material.dart';


class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGame();
}

class _DotsAndBoxesGame extends State<DotsAndBoxesGame> {

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return const Stack(children: [
        Text("Hello, this is the Dots and Boxes game!")
      ]);
    });
  }
}
