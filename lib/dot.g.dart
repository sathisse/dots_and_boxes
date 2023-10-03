// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Dot _$DotFromJson(Map<String, dynamic> json) => Dot(
      _$recordConvert(
        json['position'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
    );

Map<String, dynamic> _$DotToJson(Dot instance) => <String, dynamic>{
      'position': {
        r'$1': instance.position.$1,
        r'$2': instance.position.$2,
      },
    };

$Rec _$recordConvert<$Rec>(
  Object? value,
  $Rec Function(Map) convert,
) =>
    convert(value as Map<String, dynamic>);
