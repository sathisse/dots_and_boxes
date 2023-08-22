// ignore_for_file: avoid_print

import 'dart:core';
import 'package:flutter/material.dart';

import 'box.dart';
import 'dot.dart';
import 'line.dart';

enum Direction { n, e, s, w }

enum Who { nobody, p1, p2 }

typedef Coord = (int x, int y);

const dotSizeFactor = 1 / 6;
const halfDotSizeFactor = 1 / 12;

const dotsHorizontal = 5;
const dotsVertical = 4;

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGame();
}

class _DotsAndBoxesGame extends State<DotsAndBoxesGame> {
  late final Set<Dot> dots; // These are always displayed.
  late final Set<Box> boxes; // These are only displayed if closed.

  @override
  void initState() {
    super.initState();

    dots = {};
    for (int x = 0; x < dotsHorizontal; x++) {
      for (int y = 0; y < dotsVertical; y++) {
        dots.add(Dot((x, y)));
      }
    }

    boxes = {};
    for (int x = 0; x < dotsHorizontal - 1; x++) {
      for (int y = 0; y < dotsVertical - 1; y++) {
        Box box = Box((x, y));

        box.dots.add(dots.where((dot) => dot.position == (x, y)).single);
        box.dots.add(dots.where((dot) => dot.position == (x + 1, y)).single);
        box.dots.add(dots.where((dot) => dot.position == (x + 1, y + 1)).single);
        box.dots.add(dots.where((dot) => dot.position == (x, y + 1)).single);

        for (final dot in box.dots) {
          dot.boxes.add(box);
        }

        // Create lines that surround the box:

        // Add them to global set of lines (ignoring rejection if any already exist):
        box.lines.add(Line(dots.where((dot) => dot.position == (x, y)).single.position,
            dots.where((dot) => dot.position == (x + 1, y)).single.position));
        box.lines.add(Line(dots.where((dot) => dot.position == (x + 1, y)).single.position,
            dots.where((dot) => dot.position == (x + 1, y + 1)).single.position));
        box.lines.add(Line(dots.where((dot) => dot.position == (x, y + 1)).single.position,
            dots.where((dot) => dot.position == (x + 1, y + 1)).single.position));
        box.lines.add(Line(dots.where((dot) => dot.position == (x, y)).single.position,
            dots.where((dot) => dot.position == (x, y + 1)).single.position));

        boxes.add(box);
      }
    }

    resetGame();
  }

  void resetGame() {
    for (final box in boxes) {
      box.closer = Who.nobody;

      for (final line in box.lines) {
        line.drawer = Who.nobody;
      }
    }

    debugPrint('dots={\n  ${dots.join(',\n  ')}\n}');
    debugPrint('boxes={\n  ${boxes.join(',\n\n  ')} \n }');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return const Stack(children: [
        //DrawBoxes(boxes),
        //DrawDots(dots),
        Text("Hello, this is the Dots and Boxes game!")
      ]);
    });
  }
}
