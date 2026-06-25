import 'package:hive/hive.dart';
import 'sport_models.dart';

class HiveSportSessionAdapter extends TypeAdapter<HiveSportSession> {
  @override
  final int typeId = 9;

  @override
  HiveSportSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return HiveSportSession(
      sportType: fields[0] as String,
      date: fields[1] as String,
      durationSeconds: fields[2] as int,
      distanceKm: fields[3] as double?,
      notes: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSportSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.sportType)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.distanceKm)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSportSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}