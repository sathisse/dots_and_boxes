import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'create_new_game_dialog.dart';
import 'game_info.dart';

class Lobby extends StatefulWidget {
  const Lobby({super.key});

  @override
  State<Lobby> createState() => _Lobby();
}

class _Lobby extends State<Lobby> {
  _Lobby();

  late AutoScrollController scrollController;
  late List<GameInfo> gameList;
  late int selectedGame;

  @override
  void initState() {
    super.initState();

    scrollController = AutoScrollController(
        viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
        axis: Axis.vertical);

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

    selectedGame = -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const Row(children: [
          SizedBox(width: 40),
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
                scrollDirection: Axis.vertical,
                controller: scrollController,
                children: gameList.asMap().entries.map<Widget>((item) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 0.0),
                      child: getRow(item.key, item.value));
                }).toList())),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, semanticLabel: 'Leave game'),
          tooltip: 'Create new game',
          onPressed: () {
            setState(() {
              Navigator.of(context).push(CreateNewGameDialog<void>(createNewGame: createNewGame));
            });
          },
        ),
      ]),
    );
  }

  Widget getRow(int index, GameInfo item) {
    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      highlightColor: Colors.white.withOpacity(0.1),
      child: GestureDetector(
        onTap: () {
          debugPrint("Game ${item.gameId} pressed");
          scrollToItem(item.gameId);
        },
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(color: index != selectedGame ? Colors.white10 : Colors.white60),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              color: Colors.black.withAlpha(25)),
          child: Row(children: [
            IconButton(
                tooltip: 'Join game',
                onPressed: () {
                  scrollToItem(item.gameId);
                  // Start/join game
                  debugPrint(
                      'Joining game ${item.gameId}, with ${item.numDots} dots and ${item.numPlayers} players');
                },
                icon: const Icon(Icons.play_circle_outline)),
            // if (kDebugMode)
            Expanded(flex: 10, child: Align(alignment: Alignment.center, child: Text(item.gameId))),
            Expanded(
                flex: 33,
                child: Align(alignment: Alignment.center, child: Text(item.numDots.toString()))),
            Expanded(
                flex: 33,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('${item.numJoined} of ${item.numPlayers}'))),
            Expanded(
                flex: 33,
                child: Align(alignment: Alignment.center, child: Text(item.status.label))),
          ]),
        ),
      ),
    );
  }

  void scrollToItem(String gameId) async {
    final index = gameList.indexWhere((item) => item.gameId == gameId);
    setState(() {
      selectedGame = index;
    });
    debugPrint('scroll index is $index');
    await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    await scrollController.highlight(index);
  }

  void createNewGame(String gameId, int numDots, int numPlayers) {
    setState(() {
      gameList.add(GameInfo(gameId: gameId, numDots: numDots, numPlayers: numPlayers));
      gameList.sort();
    });

    scrollToItem(gameId);
    debugPrint('Created new game ($gameId) with $numDots dots and $numPlayers players.');

    if (gameId == 'Local') {
      debugPrint('Starting local-only game');
    }
  }
}
