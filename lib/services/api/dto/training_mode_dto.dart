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
  final String category;

  const RemoteTrainingMode({
    required this.id,
    required this.name,
    required this.category,
  });

  factory RemoteTrainingMode.fromJson(Map<String, dynamic> json) =>
      RemoteTrainingMode(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? '',
      );
}