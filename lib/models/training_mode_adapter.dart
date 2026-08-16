import 'package:hive/hive.dart';
import 'training_mode.dart';

// Adapter scritti a mano (stesso pattern di goal_models_adapter.dart
// e sport_models_adapter.dart), non richiedono build_runner.
// typeId 10 e 11: i precedenti (0-9) sono già usati dal sistema
// Fitness (0-6), Goals (7-8) e Sport (9).

class TrainingModeSetAdapter extends TypeAdapter<TrainingModeSet> {
  @override
  final int typeId = 11;

  @override
  TrainingModeSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return TrainingModeSet(
      order: fields[0] as int,
      fixedReps: fields[1] as int?,
      minReps: fields[2] as int?,
      maxReps: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TrainingModeSet obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.order)
      ..writeByte(1)
      ..write(obj.fixedReps)
      ..writeByte(2)
      ..write(obj.minReps)
      ..writeByte(3)
      ..write(obj.maxReps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingModeSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingModeAdapter extends TypeAdapter<TrainingMode> {
  @override
  final int typeId = 10;

  @override
  TrainingMode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return TrainingMode(
      name: fields[0] as String,
      category: fields[1] as String,
      createdAt: fields[2] as String,
      updatedAt: fields[3] as String?,
      isDeleted: fields[4] as bool? ?? false,
      isDefault: fields[5] as bool? ?? false,
      origin: fields[6] as String? ?? 'custom',
      parentModeKey: fields[7] as int?,
      sets: (fields[8] as List?)?.cast<TrainingModeSet>() ??
          const <TrainingModeSet>[],
    );
  }

  @override
  void write(BinaryWriter writer, TrainingMode obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.isDeleted)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.origin)
      ..writeByte(7)
      ..write(obj.parentModeKey)
      ..writeByte(8)
      ..write(obj.sets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}