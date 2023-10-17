import 'package:json_annotation/json_annotation.dart';

import 'dots_and_boxes_game.dart';

part 'line.g.dart';

@JsonSerializable(explicitToJson: true)
class Line {
  final Coord start;
  final Coord end;
  Who drawer = Who.nobody;

  Line(this.start, this.end, {this.drawer = Who.nobody});

  factory Line.fromJson(Map<String, dynamic> json) => _$LineFromJson(json);

  Map<String, dynamic> toJson() => _$LineToJson(this);

  @override
  String toString() {
    return 'Line($start to $end, ${drawer.name})';
  }

  // Only include the coordinates (in either order) to determine equality:
  @override
  bool operator ==(Object other) {
    return other is Line &&
        ((start == other.start && end == other.end) || (start == other.end && end == other.start));
  }

  // Only include the coordinates (in either order) to determine equality:
  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
