// import 'dot.dart';
import 'dot.dart';
import 'dots_and_boxes_game.dart';
import 'line.dart';

// enum Direction { n, e, s, w }

class Box {
  final Coord position;
  final List<Dot> dots = [];
  final List<Line> lines = []; // How many lines are still nobody? If 0, box is closed.
  Who closer = Who.nobody;

  Box(this.position);

  @override
  String toString() {
    return 'Box($position,\n  '
        '{${dots.map((dot) => 'Dot(${dot.position}').join(', ')}},\n'
        '  {${lines.join(',  ')}},\n  ${closer.name})';
  }

  bool isClosed() {
    return lines.where((line) => line.drawer == Who.nobody).isEmpty;
  }
}
