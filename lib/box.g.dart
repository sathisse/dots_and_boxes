// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Box _$BoxFromJson(Map<String, dynamic> json) => Box(
      _$recordConvert(
        json['position'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
    )
      ..lines = (json['lines'] as Map<String, dynamic>).map(
        (k, e) => MapEntry($enumDecode(_$DirectionEnumMap, k),
            Line.fromJson(e as Map<String, dynamic>)),
      )
      ..closer = $enumDecode(_$WhoEnumMap, json['closer']);

Map<String, dynamic> _$BoxToJson(Box instance) => <String, dynamic>{
      'position': {
        r'$1': instance.position.$1,
        r'$2': instance.position.$2,
      },
      'lines': instance.lines
          .map((k, e) => MapEntry(_$DirectionEnumMap[k]!, e.toJson())),
      'closer': _$WhoEnumMap[instance.closer]!,
    };

$Rec _$recordConvert<$Rec>(
  Object? value,
  $Rec Function(Map) convert,
) =>
    convert(value as Map<String, dynamic>);

const _$DirectionEnumMap = {
  Direction.n: 'n',
  Direction.e: 'e',
  Direction.s: 's',
  Direction.w: 'w',
};

const _$WhoEnumMap = {
  Who.nobody: 'nobody',
  Who.p1: 'p1',
  Who.p2: 'p2',
  Who.p3: 'p3',
  Who.p4: 'p4',
  Who.p5: 'p5',
};
