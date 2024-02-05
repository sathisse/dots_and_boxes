import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'game_info.dart';

const gameIdLength = 3;

class Lobby extends ConsumerStatefulWidget {
  const Lobby({super.key});

  @override
  ConsumerState<Lobby> createState() => _Lobby();
}

class _Lobby extends ConsumerState<Lobby> {
  _Lobby();

  late List<GameInfo> gameList;

  @override
  void initState() {
    super.initState();

    gameList = <GameInfo>[
      GameInfo(gameId: '001', numDots: 12, numPlayers: 2)..setNumJoined(1),
      GameInfo(gameId: '002', numDots: 12, numPlayers: 3)..setNumJoined(1),
      GameInfo(gameId: '003', numDots: 20, numPlayers: 2),
      GameInfo(gameId: '004', numDots: 24, numPlayers: 5)..setNumJoined(4),
      GameInfo(gameId: '005', numDots: 24, numPlayers: 4)..setNumJoined(1),
      GameInfo(gameId: '006', numDots: 36, numPlayers: 2),
      GameInfo(gameId: '007', numDots: 36, numPlayers: 3),
      GameInfo(gameId: '008', numDots: 54, numPlayers: 2)..setNumJoined(2),
      GameInfo(gameId: '009', numDots: 60, numPlayers: 2),
      GameInfo(gameId: '010', numDots: 48, numPlayers: 3),
      GameInfo(gameId: '011', numDots: 12, numPlayers: 5)..setNumJoined(1),
      GameInfo(gameId: '012', numDots: 12, numPlayers: 3)..setNumJoined(1),
      GameInfo(gameId: '013', numDots: 20, numPlayers: 2),
      GameInfo(gameId: '014', numDots: 24, numPlayers: 2)..setNumJoined(2),
      GameInfo(gameId: '015', numDots: 24, numPlayers: 4)..setNumJoined(1),
      GameInfo(gameId: '016', numDots: 36, numPlayers: 2),
    ];
    gameList.sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const Row(children: [
          if (kDebugMode)
            Expanded(
                flex: 10,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('GameId', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Dots', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Players', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Game Status', style: TextStyle(fontWeight: FontWeight.bold))))
        ]),
        const SizedBox(height: 10),
        Expanded(
            child: ListView(
                children: gameList.asMap().entries.map<Widget>((item) {
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 0.0),
              child: GestureDetector(
                onTap: () {
                  debugPrint("Game ${item.value.gameId} pressed");
                },
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white10),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: Colors.black.withAlpha(25)),
                  child: Row(children: [
                    if (kDebugMode)
                      Expanded(
                          flex: 10,
                          child:
                              Align(alignment: Alignment.center, child: Text(item.value.gameId))),
                    Expanded(
                        flex: 33,
                        child: Align(
                            alignment: Alignment.center,
                            child: Text(item.value.numDots.toString()))),
                    Expanded(
                        flex: 33,
                        child: Align(
                            alignment: Alignment.center,
                            child: Text('${item.value.numJoined} of ${item.value.numPlayers}'))),
                    Expanded(
                        flex: 33,
                        child: Align(
                            alignment: Alignment.center, child: Text(item.value.status.label))),
                  ]),
                ),
              ));
        }).toList())),
      ]),
    );
  }

  void createNewGame(int numDots, int numPlayers) {
    final gameId = const Uuid().v4().substring(0, gameIdLength);
    setState(() {
      gameList.add(GameInfo(gameId: gameId, numDots: numDots, numPlayers: numPlayers));
      gameList.sort();
    });

    debugPrint('Created new game with $numDots dots and $numPlayers players.');
  }
}
