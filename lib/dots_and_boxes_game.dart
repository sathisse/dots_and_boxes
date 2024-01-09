import 'dart:core';
import 'dart:convert';

import 'package:dots_and_boxes/game_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final Map<Who, Player> players = {
  Who.nobody: Player("", Colors.transparent),
  Who.p1: Player("Player 1", Colors.orange),
  Who.p2: Player("Player 2", Colors.blue)
};

int numberOfDots = 12;
late int dotsHorizontal;
late int dotsVertical;
late bool isConnected;

class DotsAndBoxesGame extends ConsumerStatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  ConsumerState<DotsAndBoxesGame> createState() => _DotsAndBoxesGame();
}

class _DotsAndBoxesGame extends ConsumerState<DotsAndBoxesGame> {
  late Set<Dot> dots; // These are always displayed.
  late Set<Line> lines; // These are only displayed if drawn.
  late Set<Box> boxes; // These are only displayed if closed.

  late Who currentPlayer;
  late String winnerText;
  late bool showRestartConfirmation;
  late bool gameStarted;

  late Who playerId = Who.nobody;
  late bool isConnected = false;
  late String gameId = "<not connected>";
  late String lastActionTxt = "<not connected>";

  @override
  void initState() {
    super.initState();

    var dimChoices = getDimensionChoices();
    var dims = dimChoices.entries
        .where((dim) => dim.value.$1 * dim.value.$2 >= dimChoices.keys.toList()[4])
        .first;
    // debugPrint("dims=$dims");
    configureBoard(dims);
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
    ref.listen(gameActionsProvider, onGameAction);

    return LayoutBuilder(builder: (context, constraints) {
      late final int quarterTurns;
      quarterTurns = constraints.maxWidth < constraints.maxHeight ? 3 : 0;

      return Stack(children: [
        GameConnection(configureBoard: configureBoard, onConnected: onConnected),
        if (isConnected)
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
        Align(alignment: Alignment.bottomLeft, child: Text(lastActionTxt)),
        Align(alignment: Alignment.bottomCenter, child: Text('-- ${players[playerId]?.name} --')),
        Align(alignment: Alignment.bottomRight, child: Text(gameId)),
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

  onLineRequested(Dot src, Dot dest, [drawer = Who.nobody]) {
    debugPrint('onLineRequested with $src, $dest, and playerId=$playerId');
    if (drawer == Who.nobody && currentPlayer != playerId) {
      return;
    }

    switch (lines
        .where((x) => x == Line(src.position, dest.position) && x.drawer == Who.nobody)
        .toList()) {
      case []:
        debugPrint("Line is not valid");

      case [Line line]:
        gameStarted = true;
        drawRequestedLine(line);

        if (drawer == Who.nobody) {
          ref.read(localLineProvider.notifier).state = line;
        }
    }
  }

  drawRequestedLine(Line line) {
    debugPrint('drawRequestedLine with $line and currentPlayer=$currentPlayer');
    line.drawer = currentPlayer;
    var closedABox = false;
    for (final box in boxes.where((box) => box.lines.containsValue(line))) {
      if (box.isClosed()) {
        box.closer = currentPlayer;
        closedABox = true;
        players[currentPlayer]?.score = boxes.where((box) => box.closer == currentPlayer).length;
      }
    }

    if (boxes.where((box) => box.closer == Who.nobody).isEmpty) {
      endGame();
    } else if (!closedABox) {
      switchPlayer();
    }

    setState(() {});
  }

  switchPlayer() {
    if (currentPlayer == Who.p1) {
      currentPlayer = Who.p2;
    } else {
      currentPlayer = Who.p1;
    }

    lastActionTxt = "${players[currentPlayer]?.name}'s turn";
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

  onConnected(String gameId, Who playerId) {
    debugPrint("gameId set to $gameId; playerId set to $playerId");
    isConnected = true;
    this.gameId = gameId;
    this.playerId = playerId;
    setState(() {});
  }

  onGameAction(List<dynamic>? previous, List<dynamic> next) {
    var action = next.last;
    debugPrint("next=$next; action=$action");

    MsgType msgType = MsgType.values.firstWhere((mt) => mt.name == json.decode(action['msgType']));
    debugPrint("mt = $msgType");

    switch (msgType) {
      case MsgType.join:
        lastActionTxt = "<Requesting to join game>";
        break;

      case MsgType.added:
        // Not used for actions.
        break;

      case MsgType.addedMe:
        playerId = Who.values.firstWhere((w) => w.name == json.decode(action['playerId']));
        numberOfDots = json.decode(action['numberOfDots']);
        lastActionTxt = "Joined game as ${players[playerId]?.name}";
        configureBoard(getDimensionChoices()
            .entries
            .where((dim) => dim.value.$1 * dim.value.$2 >= numberOfDots)
            .first);
        gameStarted = true;
        break;

      case MsgType.addedOther:
        var newPlayerId = Who.values.firstWhere((w) => w.name == json.decode(action['playerId']));
        lastActionTxt = "${players[newPlayerId]?.name} has joined game";
        gameStarted = true;
        break;

      case MsgType.rejected:
        lastActionTxt = "Join request rejected";
        break;

      case MsgType.line:
        Line line = Line.fromJson(json.decode(action['line']));
        if (line.drawer != playerId) {
          debugPrint("Line = $line");
          lastActionTxt = "${players[line.drawer]?.name} added a line";
          onLineRequested(Dot(line.start), Dot(line.end), line.drawer);
          // drawRequestedLine(line);
        }
        break;

      case MsgType.leave:
        break;
    }

    setState(() {});
  }
}
