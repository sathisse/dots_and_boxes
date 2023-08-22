import 'box.dart';
import 'dots_and_boxes_game.dart';

class Dot {
  final Coord position;
  final Set<Box> boxes = {};

  Dot(this.position);

  @override
  String toString() {
    return 'Dot($position, {${boxes.map((box) => 'Box(${box.position}').join(', ')}}';
  }
}
