import 'dots_and_boxes_game.dart';

class Line {
  final Coord start;
  final Coord end;
  Who drawer = Who.nobody;

  Line(this.start, this.end);

  @override
  String toString() {
    return 'Line($start to $end, ${drawer.name})';
  }

  // Only include the coordinates to determine equality:
  @override
  bool operator ==(Object other) {
    return other is Line && start == other.start && end == other.end;
  }

  // Only include the coordinates to determine equality:
  @override
  int get hashCode => Object.hash(start, end);
}
