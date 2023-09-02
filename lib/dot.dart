import 'dots_and_boxes_game.dart';

class Dot {
  final Coord position;

  Dot(this.position);

  @override
  String toString() {
    return 'Dot($position)';
  }
}
