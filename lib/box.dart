import 'dots_and_boxes_game.dart';
import 'line.dart';

class Box {
  final Coord position;
  final List<Line> lines = []; // How many lines are still nobody? If 0, box is closed.
  Who closer = Who.nobody;

  Box(this.position);

  @override
  String toString() {
    return 'Box($position,  ${closer.name},\n  {${lines.join(',  ')}},)';
  }

  bool isClosed() {
    return lines.where((key) => key.drawer == Who.nobody).isEmpty;
  }
}
