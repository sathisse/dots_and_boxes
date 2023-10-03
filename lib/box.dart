import 'package:json_annotation/json_annotation.dart';

import 'dots_and_boxes_game.dart';
import 'line.dart';

part 'box.g.dart';

@JsonSerializable(explicitToJson: true)
class Box {
  final Coord position;
  Map<Direction, Line> lines = {}; // How many lines are still nobody? If 0, box is closed.
  Who closer = Who.nobody;

  Box(this.position);

  factory Box.fromJson(Map<String, dynamic> json) => _$BoxFromJson(json);

  Map<String, dynamic> toJson() => _$BoxToJson(this);

  @override
  String toString() {
    return 'Box($position,  ${closer.name},\n  {${lines.entries.join(',  ')}},)';
  }

  bool isClosed() {
    return lines.values.where((value) => value.drawer == Who.nobody).isEmpty;
  }
}
