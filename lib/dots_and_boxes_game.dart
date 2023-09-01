import 'dart:core';
import 'package:flutter/material.dart';
import 'package:format/format.dart';

import 'dot.dart';
import 'line.dart';
import 'box.dart';
import 'player.dart';
import 'utils.dart';
import 'draw_dots.dart';
import 'draw_boxes.dart';

enum Direction { n, e, s, w }

enum Who { nobody, p1, p2 }

typedef Coord = (int x, int y);

int numberOfDots = 12;
late int dotsHorizontal;
late int dotsVertical;

final Map<Who, Player> players = {
  Who.nobody: Player("", Colors.transparent),
  Who.p1: Player("Player 1", Colors.orange),
  Who.p2: Player("Player 2", Colors.blue)
};

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGame();
}

class _DotsAndBoxesGame extends State<DotsAndBoxesGame> {
  final dimChoices = getDimensionChoices();

  late Set<Dot> dots; // These are always displayed.
  late Set<Line> lines; // These are only displayed if drawn.
  late Set<Box> boxes; // These are only displayed if closed.

  late double sliderValue;
  late Who currentPlayer;
  late String winnerText;

  @override
  void initState() {
    super.initState();

    debugPrint('Dimension choices are: $dimChoices');
    sliderValue = 4;
    configureBoard(
        dimChoices.entries.where((dim) => dim.value.$1 * dim.value.$2 >= numberOfDots).first);
  }

  configureBoard(dims) {
    numberOfDots = dims.key;
    dotsHorizontal = dims.value.$1;
    dotsVertical = dims.value.$2;
    debugPrint('Nbr of dots set to $numberOfDots, dims set to ($dotsHorizontal, $dotsVertical)');

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
        boxDots.clear();
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

    // debugPrint('dots={\n  ${dots.join(',\n  ')}\n}');
    // debugPrint('lines={\n  ${lines.join(',\n  ')}\n}');
    // debugPrint('boxes={\n  ${boxes.join(',\n\n  ')} \n }');

    resetGame();
  }

  resetGame() {
    for (final line in lines) {
      line.drawer = Who.nobody;
    }
    for (final box in boxes) {
      box.closer = Who.nobody;
    }
    for (final player in players.values) {
      player.score = 0;
    }

    currentPlayer = Who.p1;
    winnerText = "";

    setState(() {});

    // TODO: For testing, close some (or all) of the boxes:
    // Future.delayed(const Duration(seconds: 1)).then((_) => closeSomeBoxes(percentage: 100));
  }

  // For testing, not actual game-play:
  Future<void> closeSomeBoxes({int percentage = 100}) async {
    var player = Who.p1;
    var shuffled = lines.toList()..shuffle();
    for (final line in shuffled.take((shuffled.length * percentage / 100).ceil())) {
      line.drawer = player;
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {});

      // TODO: Optimize this (make the mapping two-way?)
      for (final box in boxes.where((box) => box.lines.containsKey(line))) {
        if (box.isClosed()) {
          box.closer = player;
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {});
        }
      }

      // Switch players:
      if (player == Who.p1) {
        player = Who.p2;
      } else {
        player = Who.p1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Slider(
          value: sliderValue,
          min: 0,
          max: dimChoices.length.toDouble() - 1,
          divisions: dimChoices.length - 1,
          label: "${dimChoices.keys.toList()[sliderValue.floor()]} dots",
          onChanged: onSliderChanged),
      Stack(children: [
        DrawBoxes(boxes),
        DrawDots(dots, onLineRequested: onLineRequested),
      ]),
      if (winnerText.isNotEmpty)
        AlertDialog(
          title: const Text('Game Over'),
          content: Text(winnerText),
          actions: <Widget>[
            TextButton(
              onPressed: () => resetGame(),
              child: const Text('OK'),
            ),
          ],
        ),
      IconButton(
        icon: const Icon(Icons.restart_alt, semanticLabel: 'restart'),
        tooltip: 'Restart game',
        onPressed: () {
          log.d('Undoing last move');
          endGame();
        },
      ),
      Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        for (final player in players.values.skip(1))
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text("${player.name}: ",
                style: TextStyle(fontWeight: FontWeight.bold, color: player.color)),
            const SizedBox(height: 10),
            Text(('{:7d}'.format(player.score)),
                style: TextStyle(fontWeight: FontWeight.bold, color: player.color))
          ]),
      ])
    ]);
  }

  onSliderChanged(double value) {
    debugPrint("Slider tab set to $value");
    sliderValue = value;
    setState(() {});

    var dims = dimChoices.entries
        .where((dim) => dim.value.$1 * dim.value.$2 >= dimChoices.keys.toList()[value.floor()])
        .first;
    debugPrint("dims=$dims");
    if (dims.key != numberOfDots) {
      debugPrint("Changing board!");
      configureBoard(dims);
    }
  }

  onLineRequested(Dot src, Dot dest) {
    switch (lines.where((x) => x == Line(src.position, dest.position)).toList()) {
      case []:
        debugPrint("Line is not valid");

      case [Line line]:
        line.drawer = currentPlayer;

        var closedABox = false;
        for (final box in boxes.where((box) => box.lines.containsKey(line))) {
          if (box.isClosed()) {
            box.closer = currentPlayer;
            closedABox = true;
            players[currentPlayer]?.score =
                boxes.where((box) => box.closer == currentPlayer).length;
          }
        }

        if (boxes.where((box) => box.closer == Who.nobody).isEmpty) {
          endGame();
        } else if (!closedABox) {
          switchPlayer();
        }
    }

    setState(() {});
  }

  switchPlayer() {
    // Switch players:
    if (currentPlayer == Who.p1) {
      currentPlayer = Who.p2;
    } else {
      currentPlayer = Who.p1;
    }
  }

  endGame() {
    // Show end-game popup
    var hiScore = -1;
    var tie = false;
    var winner = Who.nobody.name;

    for (final player in players.values.skip(1)) {
      if (player.score == hiScore) {
        tie = true;
      } else if (player.score > hiScore) {
        tie = false;
        winner = player.name;
        hiScore = player.score;
      }
    }

    if (tie) {
      winnerText = "The game ended in a tie.";
    } else {
      winnerText = "$winner wins with $hiScore boxes closed!";
    }
    debugPrint(winnerText);

    setState(() {});
  }
}
