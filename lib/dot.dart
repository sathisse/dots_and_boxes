import 'package:json_annotation/json_annotation.dart';

import 'dots_and_boxes_game.dart';

part 'dot.g.dart';

@JsonSerializable(explicitToJson: true)
class Dot {
  final Coord position;

  Dot(this.position);

  factory Dot.fromJson(Map<String, dynamic> json) => _$DotFromJson(json);

  Map<String, dynamic> toJson() => _$DotToJson(this);

  @override
  String toString() {
    return 'Dot($position)';
  }
}
