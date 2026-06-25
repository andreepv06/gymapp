import 'package:hive/hive.dart';
import 'goal_models.dart';

// Adapter scritti a mano (stesso pattern di hive_models.g.dart),
// non richiedono build_runner. typeId 7 e 8: i precedenti (0-6)
// sono già usati dal sistema Fitness in hive_models.g.dart.

class HiveGoalAdapter extends TypeAdapter<HiveGoal> {
  @override
  final int typeId = 7;

  @override
  HiveGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return HiveGoal(
      title: fields[0] as String,
      description: fields[1] as String?,
      category: fields[2] as String,
      createdAt: fields[3] as String,
      scheduleType: fields[4] as String,
      scheduleDaysOfWeek: (fields[5] as List?)?.cast<int>(),
      scheduleStartDate: fields[6] as String?,
      scheduleEndDate: fields[7] as String?,
      scheduleCustomInterval: fields[8] as int?,
      status: fields[9] as String,
      currentStreak: fields[10] as int,
      bestStreak: fields[11] as int,
      deadlineDate: fields[12] as String?,
      colorIndex: fields[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HiveGoal obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.scheduleType)
      ..writeByte(5)
      ..write(obj.scheduleDaysOfWeek)
      ..writeByte(6)
      ..write(obj.scheduleStartDate)
      ..writeByte(7)
      ..write(obj.scheduleEndDate)
      ..writeByte(8)
      ..write(obj.scheduleCustomInterval)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.currentStreak)
      ..writeByte(11)
      ..write(obj.bestStreak)
      ..writeByte(12)
      ..write(obj.deadlineDate)
      ..writeByte(13)
      ..write(obj.colorIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveGoalCompletionAdapter extends TypeAdapter<HiveGoalCompletion> {
  @override
  final int typeId = 8;

  @override
  HiveGoalCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return HiveGoalCompletion(
      goalKey: fields[0] as int,
      date: fields[1] as String,
      completed: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveGoalCompletion obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.goalKey)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.completed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveGoalCompletionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}