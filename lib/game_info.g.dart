// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GameInfo _$GameInfoFromJson(Map<String, dynamic> json) => GameInfo(
      gameId: json['gameId'] as String,
      numDots: json['numDots'] as int,
      numPlayers: json['numPlayers'] as int,
    )
      ..numJoined = json['numJoined'] as int
      ..status = $enumDecode(_$GameStatusEnumMap, json['status']);

Map<String, dynamic> _$GameInfoToJson(GameInfo instance) => <String, dynamic>{
      'gameId': instance.gameId,
      'numDots': instance.numDots,
      'numPlayers': instance.numPlayers,
      'numJoined': instance.numJoined,
      'status': _$GameStatusEnumMap[instance.status]!,
    };

const _$GameStatusEnumMap = {
  GameStatus.waiting: 'waiting',
  GameStatus.playing: 'playing',
  GameStatus.idle: 'idle',
};
