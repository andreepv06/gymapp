class RemoteTrainingModeSet {
  final int order;
  final int? fixedReps;
  final int? minReps;
  final int? maxReps;

  const RemoteTrainingModeSet({
    required this.order,
    this.fixedReps,
    this.minReps,
    this.maxReps,
  });

  Map<String, dynamic> toJson() => {
        'order': order,
        if (fixedReps != null) 'fixedReps': fixedReps,
        if (minReps != null) 'minReps': minReps,
        if (maxReps != null) 'maxReps': maxReps,
      };
}

class RemoteTrainingMode {
  final String id;
  final String name;

  const RemoteTrainingMode({required this.id, required this.name});

  factory RemoteTrainingMode.fromJson(Map<String, dynamic> json) =>
      RemoteTrainingMode(id: json['id'] as String, name: json['name'] as String);
}