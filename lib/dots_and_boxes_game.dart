import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:format/format.dart';
import 'package:flame_audio/flame_audio.dart';

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

  late final AudioPool yayPool;

  late Set<Dot> dots; // These are always displayed.
  late Set<Line> lines; // These are only displayed if drawn.
  late Set<Box> boxes; // These are only displayed if closed.

  late double sliderValue;
  late Who currentPlayer;
  late String winnerText;

  late bool showRestartConfirmation;
  late bool gameStarted;

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
        box.lines[Direction.n] = lines.where((line) => line == n).single;
        box.lines[Direction.e] = lines.where((line) => line == e).single;
        box.lines[Direction.s] = lines.where((line) => line == s).single;
        box.lines[Direction.w] = lines.where((line) => line == w).single;

        boxes.add(box);
      }
    }

    var dotsJson = json.encode(dots.toList().map((dot) => dot.toJson()).toList());
    debugPrint('\ndots.json (${dotsJson.length} chars) = $dotsJson');
    debugPrint('old dots={${dots.join(',  ')}}');
    Set<Dot> newDots = (json.decode(dotsJson) as List).map((i) => Dot.fromJson(i)).toSet();
    debugPrint('new dots={${newDots.join(',  ')}}');
    // dots = newDots;

    var boxesJson = json.encode(boxes.toList().map((box) => box.toJson()).toList());
    debugPrint('\nboxes.json (${boxesJson.length} chars) = $boxesJson');
    debugPrint('old boxes={${boxes.join(',  ')} }');
    Set<Box> newBoxes = (json.decode(boxesJson) as List).map((i) => Box.fromJson(i)).toSet();
    debugPrint('new boxes={${newBoxes.join(',  ')}}');
    // boxes = newBoxes;

    var linesJson = json.encode(lines.toList().map((line) => line.toJson()).toList());
    debugPrint('\nlines.json (${linesJson.length} chars) = $linesJson');
    debugPrint('old lines={${lines.join(',  ')}}');
    Set<Line> newLines = (json.decode(linesJson) as List).map((i) => Line.fromJson(i)).toSet();
    debugPrint('new lines={${newLines.join(',  ')}}');
    // lines = newLines;

    resetGame();
  }

  resetGame() {
    showRestartConfirmation = false;
    gameStarted = false;

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

    // For testing, close some (or all) of the boxes:
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

      for (final box in boxes.where((box) => box.lines.containsValue(line))) {
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
    return LayoutBuilder(builder: (context, constraints) {
      late final int quarterTurns;
      quarterTurns = constraints.maxWidth < constraints.maxHeight ? 3 : 0;

      return Stack(children: [
        Column(children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.restart_alt, semanticLabel: 'restart'),
              tooltip: 'Restart game',
              onPressed: () {
                showRestartConfirmation = true;
                setState(() {});
              },
            ),
            Expanded(
                child: AnimatedOpacity(
                    opacity: gameStarted ? 0.25 : 1,
                    duration: const Duration(milliseconds: 500),
                    child: Slider(
                        value: sliderValue,
                        max: dimChoices.length.toDouble() - 1,
                        divisions: dimChoices.length - 2,
                        label: "${dimChoices.keys.toList()[sliderValue.floor()]} dots",
                        onChanged: onSliderChanged))),
            const SizedBox(width: 20),
            Column(children: [
              for (final player in players.values.skip(1))
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text("${player.name}: ",
                      style: TextStyle(
                          fontFamily: "RobotoMono",
                          fontWeight: FontWeight.bold,
                          color: player.color)),
                  const SizedBox(height: 20),
                  Text(('{:3d}'.format(player.score)),
                      style: TextStyle(
                          fontFamily: "RobotoMono",
                          fontWeight: FontWeight.bold,
                          color: player.color)),
                ]),
            ]),
          ]),
          Expanded(
              child: RotatedBox(
                  quarterTurns: quarterTurns,
                  child: Stack(children: [
                    DrawBoxes(boxes),
                    DrawDots(dots, onLineRequested: onLineRequested),
                  ]))),
        ]),
        if (winnerText.isNotEmpty)
          AlertDialog(
            title: const Text('Game Over'),
            content: Text(winnerText),
            actions: <Widget>[
              TextButton(onPressed: () => resetGame(), child: const Text('OK')),
            ],
          ),
        if (showRestartConfirmation)
          AlertDialog(
            title: const Text('Confirm game restart'),
            content: const Text("Restart game now?"),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    showRestartConfirmation = false;
                    endGame();
                  },
                  child: const Text('Yes, restart game')),
              TextButton(
                  onPressed: () {
                    showRestartConfirmation = false;
                    setState(() {});
                  },
                  child: const Text('No, continue game')),
            ],
          ),
      ]);
    });
  }

  onSliderChanged(double value) {
    if (gameStarted) return;
    debugPrint("Slider tab set to ${value.round()}");

    sliderValue = value;
    setState(() {});

    var dims = dimChoices.entries
        .where((dim) => dim.value.$1 * dim.value.$2 >= dimChoices.keys.toList()[value.floor()])
        .first;
    debugPrint("dims=$dims");
    if (dims.key != numberOfDots) {
      configureBoard(dims);
    }
  }

  onLineRequested(Dot src, Dot dest) {
    switch (lines.where((x) => x == Line(src.position, dest.position)).toList()) {
      case []:
        debugPrint("Line is not valid");

      case [Line line]:
        line.drawer = currentPlayer;
        gameStarted = true;
        var closedABox = false;

        for (final box in boxes.where((box) => box.lines.containsValue(line))) {
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
    if (currentPlayer == Who.p1) {
      currentPlayer = Who.p2;
    } else {
      currentPlayer = Who.p1;
    }
  }

  endGame() {
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
      FlameAudio.play("aw.wav");
      winnerText = "The game ended in a tie.";
    } else {
      FlameAudio.play("yay.mp3");
      winnerText = "$winner wins with $hiScore boxes closed!";
    }
    debugPrint(winnerText);

    setState(() {});
  }
}
