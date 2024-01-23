// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Line _$LineFromJson(Map<String, dynamic> json) => Line(
      _$recordConvert(
        json['start'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
      _$recordConvert(
        json['end'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
      drawer: $enumDecodeNullable(_$WhoEnumMap, json['drawer']) ?? Who.nobody,
    );

Map<String, dynamic> _$LineToJson(Line instance) => <String, dynamic>{
      'start': {
        r'$1': instance.start.$1,
        r'$2': instance.start.$2,
      },
      'end': {
        r'$1': instance.end.$1,
        r'$2': instance.end.$2,
      },
      'drawer': _$WhoEnumMap[instance.drawer]!,
    };

$Rec _$recordConvert<$Rec>(
  Object? value,
  $Rec Function(Map) convert,
) =>
    convert(value as Map<String, dynamic>);

const _$WhoEnumMap = {
  Who.nobody: 'nobody',
  Who.p1: 'p1',
  Who.p2: 'p2',
  Who.p3: 'p3',
  Who.p4: 'p4',
  Who.p5: 'p5',
};
