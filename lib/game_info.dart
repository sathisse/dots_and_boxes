import 'package:json_annotation/json_annotation.dart';

part 'game_info.g.dart';

enum GameStatus {
  waiting(1, 'Waiting for more'),
  playing(2, 'Playing now'),
  idle(3, 'Idle');

  const GameStatus(this.value, this.label);

  final int value;
  final String label;
}

@JsonSerializable(explicitToJson: true)
class GameInfo implements Comparable<GameInfo> {
  final String gameId;
  final int numDots;
  final int numPlayers;

  int _numJoined = 0;
  GameStatus _status = GameStatus.idle;
  DateTime _lastChange = DateTime.timestamp();

  int get numJoined {
    return _numJoined;
  }

  set numJoined(int numJoined) {
    _numJoined = numJoined;
    _status = (numJoined == numPlayers ? GameStatus.playing : GameStatus.waiting);
    _lastChange = DateTime.timestamp();
  }

  GameStatus get status {
    return _status;
  }

  set status(GameStatus status) {
    _status = status;
    _lastChange = DateTime.timestamp();
  }

  GameInfo({required this.gameId, required this.numDots, required this.numPlayers}) {
    _lastChange = DateTime.timestamp();
  }

  factory GameInfo.fromJson(Map<String, dynamic> json) => _$GameInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GameInfoToJson(this);

  @override
  String toString() {
    return 'GameInfo($gameId, $numDots, $numPlayers, $numJoined, ${status.label}, $_lastChange)';
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
