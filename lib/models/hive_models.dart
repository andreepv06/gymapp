import 'package:hive/hive.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class HiveExercise extends HiveObject {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String muscleGroup;
  @HiveField(2)
  String? notes;
  @HiveField(3)
  late bool isCustom;

  HiveExercise({
    required this.name,
    required this.muscleGroup,
    this.notes,
    this.isCustom = false,
  });

  dynamic get id => key;
}

@HiveType(typeId: 1)
class HiveWorkout extends HiveObject {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String createdAt;

  HiveWorkout({required this.name, required this.createdAt});

  dynamic get id => key;
}

@HiveType(typeId: 2)
class HiveWorkoutExercise extends HiveObject {
  @HiveField(0)
  late int workoutKey;
  @HiveField(1)
  late int exerciseKey;
  @HiveField(2)
  late String exerciseName;
  @HiveField(3)
  late String muscleGroup;
  @HiveField(4)
  late int sets;
  @HiveField(5)
  late int targetReps;
  @HiveField(6)
  double? targetWeight;
  @HiveField(7)
  int? restSeconds;
  @HiveField(8)
  String? notes;
  @HiveField(9)
  late int sortOrder;

  HiveWorkoutExercise({
    required this.workoutKey,
    required this.exerciseKey,
    required this.exerciseName,
    required this.muscleGroup,
    this.sets = 3,
    this.targetReps = 8,
    this.targetWeight,
    this.restSeconds,
    this.notes,
    this.sortOrder = 0,
  });

  dynamic get id => key;
  int get exerciseId => exerciseKey;
  int get workoutId => workoutKey;
}

@HiveType(typeId: 3)
class HiveSession extends HiveObject {
  @HiveField(0)
  late int workoutKey;
  @HiveField(1)
  late String workoutName;
  @HiveField(2)
  late String date;
  @HiveField(3)
  int? durationSeconds;

  HiveSession({
    required this.workoutKey,
    required this.workoutName,
    required this.date,
    this.durationSeconds,
  });

  dynamic get id => key;
  String get workout_name => workoutName;
}

@HiveType(typeId: 4)
class HiveSessionSet extends HiveObject {
  @HiveField(0)
  late int sessionKey;
  @HiveField(1)
  late int exerciseKey;
  @HiveField(2)
  late String exerciseName;
  @HiveField(3)
  late String muscleGroup;
  @HiveField(4)
  late int setNumber;
  @HiveField(5)
  late double weight;
  @HiveField(6)
  late int reps;
  @HiveField(7)
  late bool completed;
  @HiveField(8)
  int? restSeconds;

  HiveSessionSet({
    required this.sessionKey,
    required this.exerciseKey,
    required this.exerciseName,
    required this.muscleGroup,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.completed,
    this.restSeconds,
  });
}

@HiveType(typeId: 5)
class HiveExerciseNote extends HiveObject {
  @HiveField(0)
  late int exerciseKey;
  @HiveField(1)
  late String note;
  @HiveField(2)
  late String updatedAt;

  HiveExerciseNote({
    required this.exerciseKey,
    required this.note,
    required this.updatedAt,
  });
}