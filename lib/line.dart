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
}
