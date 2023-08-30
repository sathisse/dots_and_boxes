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

  // Only include the coordinates (in either order) to determine equality:
  @override
  bool operator ==(Object other) {
    // TODO: Make the coords be a set and compare the sets?
    return other is Line &&
        ((start == other.start && end == other.end) || (start == other.end && end == other.start));
  }

  // Only include the coordinates (in either order) to determine equality:
  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
