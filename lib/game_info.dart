enum GameStatus {
  waiting(1, 'Waiting for more'),
  playing(2, 'Playing now'),
  idle(3, 'Idle');

  const GameStatus(this.value, this.label);

  final int value;
  final String label;
}

class GameInfo implements Comparable<GameInfo> {
  final String gameId;
  final int numDots;
  final int numPlayers;
  int numJoined = 0;
  GameStatus status = GameStatus.idle;
  DateTime lastChange = DateTime.timestamp();

  GameInfo({required this.gameId, required this.numDots, required this.numPlayers});

  void setNumJoined(int numJoined) {
    this.numJoined = numJoined;
    status = (numJoined == numPlayers ? GameStatus.playing : GameStatus.waiting);
    lastChange = DateTime.timestamp();
  }

  void setGameStatus(GameStatus status) {
    this.status = status;
    lastChange = DateTime.timestamp();
  }

  @override
  String toString() {
    return 'GameInfo($gameId, $numDots, $numPlayers, $numJoined, ${status.label}, $lastChange)';
  }

  @override
  int compareTo(GameInfo other) {
    int cmp = status.value.compareTo(other.status.value);
    if (cmp != 0) return cmp;
    cmp = (numPlayers - numJoined).compareTo(other.numPlayers - other.numJoined);
    if (cmp != 0) return cmp;
    return numDots.compareTo(other.numDots);
  }
}
