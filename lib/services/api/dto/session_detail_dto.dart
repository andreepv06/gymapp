class RemoteSessionDetail {
  final String id;
  final String workoutName;
  final String date;
  final int? durationSeconds;

  const RemoteSessionDetail({
    required this.id,
    required this.workoutName,
    required this.date,
    this.durationSeconds,
  });

  factory RemoteSessionDetail.fromJson(Map<String, dynamic> json) =>
      RemoteSessionDetail(
        id: json['id'] as String,
        workoutName: json['workoutName'] as String,
        date: json['date'] as String,
        durationSeconds: json['durationSeconds'] as int?,
      );
}

class RemoteSessionSetDetail {
  final String exerciseName;
  final String muscleGroup;
  final int setNumber;
  final double weight;
  final int reps;
  final bool completed;
  final int? restSeconds;
  final String? executionStatus;

  const RemoteSessionSetDetail({
    required this.exerciseName,
    required this.muscleGroup,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.completed,
    this.restSeconds,
    this.executionStatus,
  });

  factory RemoteSessionSetDetail.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] as Map<String, dynamic>?;
    return RemoteSessionSetDetail(
      exerciseName: exercise?['name'] as String? ?? json['exerciseName'] as String? ?? '',
      muscleGroup: exercise?['muscleGroup'] as String? ?? json['muscleGroup'] as String? ?? '',
      setNumber: json['setNumber'] as int,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
      completed: json['completed'] as bool? ?? false,
      restSeconds: json['restSeconds'] as int?,
      executionStatus: json['executionStatus'] as String?,
    );
  }
}