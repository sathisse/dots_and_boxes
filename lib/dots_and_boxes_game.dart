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

enum Who { nobody, p1, p2, p3, p4, p5 }

typedef Coord = (int x, int y);

final Map<Who, Player> players = {
  Who.nobody: Player("", Colors.transparent),
  Who.p1: Player("Player 1", Colors.orange),
  Who.p2: Player("Player 2", Colors.blue),
  Who.p3: Player("Player 3", Colors.red),
  Who.p4: Player("Player 4", Colors.green),
  Who.p5: Player("Player 5", Colors.yellow),
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
  late int numPlayers = 1;
  late int joinedPlayers;
  late String winnerText;
  late bool showLeaveGameConfirmation;
  late bool gameStarted;

  late int playerIndex = 0;
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

        final nw = dots.where((dot) => dot.position == (x, y)).single;
        final ne = dots.where((dot) => dot.position == (x + 1, y)).single;
        final se = dots.where((dot) => dot.position == (x + 1, y + 1)).single;
        final sw = dots.where((dot) => dot.position == (x, y + 1)).single;

        boxDots.add(nw);
        boxDots.add(ne);
        boxDots.add(se);
        boxDots.add(sw);

        // Create lines that surround the box:
        final n = Line(nw.position, ne.position);
        final e = Line(ne.position, se.position);
        final s = Line(sw.position, se.position);
        final w = Line(nw.position, sw.position);

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
    showLeaveGameConfirmation = false;
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
    final shuffled = lines.toList()..shuffle();
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
    ref.listen(commsToGuiProvider, onMsgFromComms);

    return LayoutBuilder(builder: (context, constraints) {
      late final int quarterTurns;
      quarterTurns = constraints.maxWidth < constraints.maxHeight ? 3 : 0;

      return Stack(children: [
        const GameConnection(),
        if (isConnected)
          Column(children: [
            Row(children: [
              for (final player in players.entries.skip(1).take(numPlayers))
                Container(
                  width: (constraints.maxWidth - 50) / numPlayers,
                  decoration: (currentPlayer == player.key
                      ? const BoxDecoration(color: Colors.white10)
                      : null),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("${player.value.name}: ",
                        // style: Theme.of(context).bannerTheme.contentTextStyle),
                        style: TextStyle(
                            fontFamily: "RobotoMono",
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: player.value.color)),
                    Text(('{:3d}'.format(player.value.score)),
                        style: TextStyle(
                            fontFamily: "RobotoMono",
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: player.value.color)),
                    const SizedBox(width: 10),
                  ]),
                ),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, semanticLabel: 'Leave game'),
                tooltip: 'Leave game',
                onPressed: () {
                  setState(() {
                    showLeaveGameConfirmation = true;
                  });
                },
              ),
            ]),
            Expanded(
                child: RotatedBox(
                    quarterTurns: quarterTurns,
                    child: Stack(children: [
                      DrawBoxes(boxes),
                      DrawDots(dots,
                          isMyTurn: currentPlayer == playerId, onLineRequested: onLineRequested),
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
        if (showLeaveGameConfirmation)
          AlertDialog(
            title: const Text('Confirm leave-game'),
            content: const Text("Leave game now?"),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    showLeaveGameConfirmation = false;
                    leaveGame();
                    setState(() {});
                  },
                  child: const Text('Yes, leave game')),
              TextButton(
                  onPressed: () {
                    showLeaveGameConfirmation = false;
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
    debugPrint(
        '...and gameStarted = $gameStarted, drawer = $drawer, and currentPlayer = $currentPlayer');
    if (!gameStarted || drawer == Who.nobody && currentPlayer != playerId) {
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
          dynamic message = {
            "msgType": json.encode(GameMsgType.line.name),
            "line": json.encode(line)
          };

          ref.read(guiToCommsProvider.notifier).state =
              ref.read(guiToCommsProvider.notifier).state.toList()..add(message);
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
    int nextPlayer = currentPlayer.index;
    do {
      if (++nextPlayer > numPlayers) {
        nextPlayer = 1;
      }
      currentPlayer = Who.values[nextPlayer];
    } while (players[currentPlayer]!.isGone);

    lastActionTxt = "${players[currentPlayer]?.name}'s turn";
  }

  void leaveGame() {
    dynamic message = {
      "msgType": json.encode(GameMsgType.leave.name),
      "playerIndex": json.encode(playerIndex)
    };

    ref.read(guiToCommsProvider.notifier).state =
        ref.read(guiToCommsProvider.notifier).state.toList()..add(message);

    // ToDo: Return to lobby (either here or in GameConnection).
    showLeaveGameConfirmation = false;
    isConnected = false;
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
      if (players[playerId]?.score == hiScore) {
        FlameAudio.play("yay.mp3");
        winnerText = "You win with $hiScore boxes closed!";
      } else {
        FlameAudio.play("no.wav");
        winnerText = "$winner wins with $hiScore boxes closed!";
      }
    }

    debugPrint(winnerText);

    setState(() {});
  }

  //
  // To/from GUI Message Methods
  //

  onMsgFromComms(List<dynamic>? previous, List<dynamic> next) {
    final message = next.last;
    debugPrint('GUI: received a message from Comms: "$message"');

    switch (GameMsgType.values.firstWhere((mt) => mt.name == json.decode(message['msgType']))) {
      case GameMsgType.join:
        lastActionTxt = "<Requesting to join game>";
        break;

      case GameMsgType.added:
        // Not used for CommsToGui messages.
        break;

      case GameMsgType.addedMe:
        joinedPlayers = json.decode(message['joinedPlayers']);
        gameId = json.decode(message['gameId']);
        playerIndex = json.decode(message['playerIndex']);
        playerId = Who.values[playerIndex];
        numberOfDots = json.decode(message['numberOfDots']);
        numPlayers = json.decode(message['numPlayers']);
        joinedPlayers = json.decode(message['joinedPlayers']);
        lastActionTxt = "Joined game as ${players[playerId]?.name}";
        configureBoard(getDimensionChoices()
            .entries
            .where((dim) => dim.value.$1 * dim.value.$2 >= numberOfDots)
            .first);
        isConnected = true;
        if (joinedPlayers == numPlayers) {
          gameStarted = true;
        }
        break;

      case GameMsgType.addedOther:
        joinedPlayers = json.decode(message['joinedPlayers']);
        lastActionTxt =
            "${players[Who.values[json.decode(message['playerIndex'])]]?.name} has joined game";
        debugPrint('joinedPlayers = $joinedPlayers and numPlayers = $numPlayers');
        if (joinedPlayers == numPlayers) {
          gameStarted = true;
        }
        break;

      case GameMsgType.rejected:
        lastActionTxt = "Sorry, the game is full.";
        break;

      case GameMsgType.line:
        Line line = Line.fromJson(json.decode(message['line']));
        if (line.drawer != playerId) {
          debugPrint("Line = $line");
          lastActionTxt = "${players[line.drawer]?.name} added a line";
          onLineRequested(Dot(line.start), Dot(line.end), line.drawer);
        }
        break;

      case GameMsgType.leave:
        final leavingPlayerIndex = json.decode(message['playerIndex']);
        debugPrint('');
        if (leavingPlayerIndex == playerIndex) {
          lastActionTxt = "You have left the game.";
        } else {
          final Player leavingPlayer = players[Who.values[leavingPlayerIndex]]!;
          leavingPlayer.isGone = true;
          lastActionTxt = "${leavingPlayer.name} has left the game.";
          if (players.entries.where((p) => p.value.isGone).length == numPlayers - 1) {
            endGame();
          }
        }
        break;
    }

    setState(() {});
  }
}
