// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jackaroo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JackarooMarble _$JackarooMarbleFromJson(Map<String, dynamic> json) =>
    JackarooMarble(
      playerIndex: (json['playerIndex'] as num).toInt(),
      marbleIndex: (json['marbleIndex'] as num).toInt(),
      status:
          $enumDecodeNullable(_$JackarooMarbleStatusEnumMap, json['status']) ??
          JackarooMarbleStatus.base,
      position: (json['position'] as num?)?.toInt() ?? -1,
    );

Map<String, dynamic> _$JackarooMarbleToJson(JackarooMarble instance) =>
    <String, dynamic>{
      'playerIndex': instance.playerIndex,
      'marbleIndex': instance.marbleIndex,
      'status': _$JackarooMarbleStatusEnumMap[instance.status]!,
      'position': instance.position,
    };

const _$JackarooMarbleStatusEnumMap = {
  JackarooMarbleStatus.base: 'base',
  JackarooMarbleStatus.track: 'track',
  JackarooMarbleStatus.safe: 'safe',
};

JackarooGameState _$JackarooGameStateFromJson(Map<String, dynamic> json) =>
    JackarooGameState(
      roomId: json['roomId'] as String,
      playerIndices: (json['playerIndices'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      currentPlayerIndex: (json['currentPlayerIndex'] as num?)?.toInt() ?? 0,
      mainTrack: (json['mainTrack'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(int.parse(k), e as String?),
      ),
      safeZones: (json['safeZones'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
          int.parse(k),
          (e as List<dynamic>).map((e) => e as String?).toList(),
        ),
      ),
      marbles: (json['marbles'] as List<dynamic>)
          .map((e) => JackarooMarble.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$JackarooGameStateToJson(JackarooGameState instance) =>
    <String, dynamic>{
      'roomId': instance.roomId,
      'playerIndices': instance.playerIndices,
      'currentPlayerIndex': instance.currentPlayerIndex,
      'mainTrack': instance.mainTrack.map((k, e) => MapEntry(k.toString(), e)),
      'safeZones': instance.safeZones.map((k, e) => MapEntry(k.toString(), e)),
      'marbles': instance.marbles,
    };
