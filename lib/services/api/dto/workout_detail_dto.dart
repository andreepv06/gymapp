class RemoteWorkoutDetail {
  final String id;
  final String name;
  final String? iconId;
  final int? iconColorIndex;

  const RemoteWorkoutDetail({
    required this.id,
    required this.name,
    this.iconId,
    this.iconColorIndex,
  });

  factory RemoteWorkoutDetail.fromJson(Map<String, dynamic> json) =>
      RemoteWorkoutDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        iconId: json['iconId'] as String?,
        iconColorIndex: json['iconColorIndex'] as int?,
      );
}

class RemoteCircuitDetail {
  final String id;
  final String name;
  final int rounds;
  final int sortOrder;

  const RemoteCircuitDetail({
    required this.id,
    required this.name,
    required this.rounds,
    required this.sortOrder,
  });

  factory RemoteCircuitDetail.fromJson(Map<String, dynamic> json) =>
      RemoteCircuitDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        rounds: json['rounds'] as int? ?? 3,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}

class RemoteWorkoutExerciseDetail {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String? circuitId;
  final int sets;
  final int targetReps;
  final double? targetWeight;
  final int? restSeconds;
  final String? notes;
  final int sortOrder;

  const RemoteWorkoutExerciseDetail({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    this.circuitId,
    required this.sets,
    required this.targetReps,
    this.targetWeight,
    this.restSeconds,
    this.notes,
    required this.sortOrder,
  });

  factory RemoteWorkoutExerciseDetail.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] as Map<String, dynamic>?;
    return RemoteWorkoutExerciseDetail(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: exercise?['name'] as String? ?? '',
      muscleGroup: exercise?['muscleGroup'] as String? ?? '',
      circuitId: json['circuitId'] as String?,
      sets: json['sets'] as int? ?? 3,
      targetReps: json['targetReps'] as int? ?? 8,
      targetWeight: (json['targetWeight'] as num?)?.toDouble(),
      restSeconds: json['restSeconds'] as int?,
      notes: json['notes'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}