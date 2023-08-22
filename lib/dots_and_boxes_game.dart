// ignore_for_file: avoid_print

import 'dart:core';
import 'package:flutter/material.dart';

import 'box.dart';
import 'dot.dart';
import 'draw_dots.dart';
import 'line.dart';

enum Direction { n, e, s, w }

enum Who { nobody, p1, p2 }

typedef Coord = (int x, int y);

const dotSizeFactor = 1 / 6;
const halfDotSizeFactor = 1 / 12;

const dotsHorizontal = 3;
const dotsVertical = 3;

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGame();
}

class _DotsAndBoxesGame extends State<DotsAndBoxesGame> {
  late final Set<Dot> dots; // These are always displayed.
  late final Set<Line> lines; // These are only displayed if drawn.
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
    lines = {};
    final List<Dot> boxDots = [];
    for (int x = 0; x < dotsHorizontal - 1; x++) {
      for (int y = 0; y < dotsVertical - 1; y++) {
        Box box = Box((x, y));

        var nw = dots.where((dot) => dot.position == (x, y)).single;
        var ne = dots.where((dot) => dot.position == (x + 1, y)).single;
        var se = dots.where((dot) => dot.position == (x + 1, y + 1)).single;
        var sw = dots.where((dot) => dot.position == (x, y + 1)).single;

        boxDots.add(nw);
        boxDots.add(ne);
        boxDots.add(se);
        boxDots.add(sw);

        for (final dot in boxDots) {
          dot.boxes.add(box);
        }

        // Create lines that surround the box:
        var n = Line(nw.position, ne.position);
        var e = Line(ne.position, se.position);
        var s = Line(sw.position, se.position);
        var w = Line(nw.position, sw.position);

        // Add them to global set of lines (ignoring rejection if any already exist):
        lines.add(n);
        lines.add(e);
        lines.add(s);
        lines.add(w);

        // Add the ones that ended up in the global set to the box:
        box.lines[lines.where((line) => line == n).single] = Direction.n;
        box.lines[lines.where((line) => line == e).single] = Direction.e;
        box.lines[lines.where((line) => line == s).single] = Direction.s;
        box.lines[lines.where((line) => line == w).single] = Direction.w;

        boxes.add(box);
      }
    }

    resetGame();
  }

  void resetGame() {
    for (final line in lines) {
      line.drawer = Who.nobody;
    }
    for (final box in boxes) {
      box.closer = Who.nobody;
    }

    debugPrint('dots={\n  ${dots.join(',\n  ')}\n}');
    debugPrint('lines={\n  ${lines.join(',\n  ')}\n}');
    debugPrint('boxes={\n  ${boxes.join(',\n\n  ')} \n }');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return Stack(children: [
        //DrawBoxes(boxes),
        DrawDots(width, height, dots),
      ]);
    });
  }
}
