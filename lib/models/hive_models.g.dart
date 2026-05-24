// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveExerciseAdapter extends TypeAdapter<HiveExercise> {
  @override
  final int typeId = 0;

  @override
  HiveExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveExercise(
      name: fields[0] as String,
      muscleGroup: fields[1] as String,
      notes: fields[2] as String?,
      isCustom: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveExercise obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.muscleGroup)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveWorkoutAdapter extends TypeAdapter<HiveWorkout> {
  @override
  final int typeId = 1;

  @override
  HiveWorkout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveWorkout(
      name: fields[0] as String,
      createdAt: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveWorkout obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveWorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveWorkoutExerciseAdapter extends TypeAdapter<HiveWorkoutExercise> {
  @override
  final int typeId = 2;

  @override
  HiveWorkoutExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveWorkoutExercise(
      workoutKey: fields[0] as int,
      exerciseKey: fields[1] as int,
      exerciseName: fields[2] as String,
      muscleGroup: fields[3] as String,
      sets: fields[4] as int,
      targetReps: fields[5] as int,
      targetWeight: fields[6] as double?,
      restSeconds: fields[7] as int?,
      notes: fields[8] as String?,
      sortOrder: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HiveWorkoutExercise obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.workoutKey)
      ..writeByte(1)
      ..write(obj.exerciseKey)
      ..writeByte(2)
      ..write(obj.exerciseName)
      ..writeByte(3)
      ..write(obj.muscleGroup)
      ..writeByte(4)
      ..write(obj.sets)
      ..writeByte(5)
      ..write(obj.targetReps)
      ..writeByte(6)
      ..write(obj.targetWeight)
      ..writeByte(7)
      ..write(obj.restSeconds)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveWorkoutExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveSessionAdapter extends TypeAdapter<HiveSession> {
  @override
  final int typeId = 3;

  @override
  HiveSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveSession(
      workoutKey: fields[0] as int,
      workoutName: fields[1] as String,
      date: fields[2] as String,
      durationSeconds: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSession obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.workoutKey)
      ..writeByte(1)
      ..write(obj.workoutName)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.durationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveSessionSetAdapter extends TypeAdapter<HiveSessionSet> {
  @override
  final int typeId = 4;

  @override
  HiveSessionSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveSessionSet(
      sessionKey: fields[0] as int,
      exerciseKey: fields[1] as int,
      exerciseName: fields[2] as String,
      muscleGroup: fields[3] as String,
      setNumber: fields[4] as int,
      weight: fields[5] as double,
      reps: fields[6] as int,
      completed: fields[7] as bool,
      restSeconds: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSessionSet obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.sessionKey)
      ..writeByte(1)
      ..write(obj.exerciseKey)
      ..writeByte(2)
      ..write(obj.exerciseName)
      ..writeByte(3)
      ..write(obj.muscleGroup)
      ..writeByte(4)
      ..write(obj.setNumber)
      ..writeByte(5)
      ..write(obj.weight)
      ..writeByte(6)
      ..write(obj.reps)
      ..writeByte(7)
      ..write(obj.completed)
      ..writeByte(8)
      ..write(obj.restSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSessionSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveExerciseNoteAdapter extends TypeAdapter<HiveExerciseNote> {
  @override
  final int typeId = 5;

  @override
  HiveExerciseNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveExerciseNote(
      exerciseKey: fields[0] as int,
      note: fields[1] as String,
      updatedAt: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveExerciseNote obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.exerciseKey)
      ..writeByte(1)
      ..write(obj.note)
      ..writeByte(2)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveExerciseNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
