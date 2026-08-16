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
  @HiveField(2)
  String? iconId; // ID icona predefinita (es. 'chest', 'legs')
  @HiveField(3)
  int? iconColorIndex; // indice colore (0-9)
  @HiveField(4)
  String? customImagePath; // path immagine custom (base64 o path)

  HiveWorkout({
    required this.name,
    required this.createdAt,
    this.iconId,
    this.iconColorIndex,
    this.customImagePath,
  });

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
  // ── FASE 1 Sistema Modalità di Allenamento ──────────────────
  // Riferimento (chiave Hive di TrainingMode) alla modalità
  // assegnata a QUESTA associazione esercizio↔scheda. Nullable e
  // additivo: i record esistenti restano validi con valore null
  // (letti come "modalità legacy", derivata da sets/targetReps
  // nelle fasi successive). La modalità è una proprietà
  // dell'associazione esercizio↔scheda, non dell'esercizio globale:
  // lo stesso esercizio può avere modalità diverse in schede
  // diverse.
  @HiveField(10)
  int? trainingModeKey;

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
    this.trainingModeKey,
  });

  dynamic get id => key;
  int get exerciseId => exerciseKey;
  int get workoutId => workoutKey;

  bool get isInCircuit =>
      notes != null && notes!.startsWith('__circuit_');

  String? get circuitId {
    if (!isInCircuit) return null;
    return notes!.replaceFirst('__circuit_', '');
  }
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
  // ── FASE 1 Sistema Modalità di Allenamento ──────────────────
  // Riferimento (chiave Hive di TrainingMode) alla modalità
  // utilizzata al momento dell'esecuzione di questa sessione, per
  // questo esercizio. Nullable e additivo: i record esistenti
  // restano validi con valore null (sessioni "legacy", precedenti
  // all'introduzione del sistema modalità).
  @HiveField(9)
  int? trainingModeKey;
  // Stato di esecuzione rispetto alla modalità: 'standard' |
  // 'partial' | 'custom'. Calcolato e persistito dalle fasi
  // successive al termine della sessione; nullable per
  // retrocompatibilità con i record esistenti.
  @HiveField(10)
  String? executionStatus;

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
    this.trainingModeKey,
    this.executionStatus,
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

@HiveType(typeId: 6)
class HiveCircuit extends HiveObject {
  @HiveField(0)
  late int workoutKey;
  @HiveField(1)
  late String name;
  @HiveField(2)
  late int rounds;
  @HiveField(3)
  late int sortOrder;

  HiveCircuit({
    required this.workoutKey,
    required this.name,
    this.rounds = 3,
    this.sortOrder = 0,
  });
}