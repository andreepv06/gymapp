class RemoteTrainingModeSetDetail {
  final int order;
  final int? fixedReps;
  final int? minReps;
  final int? maxReps;

  const RemoteTrainingModeSetDetail({
    required this.order,
    this.fixedReps,
    this.minReps,
    this.maxReps,
  });

  factory RemoteTrainingModeSetDetail.fromJson(Map<String, dynamic> json) =>
      RemoteTrainingModeSetDetail(
        order: json['order'] as int,
        fixedReps: json['fixedReps'] as int?,
        minReps: json['minReps'] as int?,
        maxReps: json['maxReps'] as int?,
      );
}

class RemoteTrainingModeDetail {
  final String id;
  final String name;
  final String category;
  final bool isDefault;
  final List<RemoteTrainingModeSetDetail> sets;

  const RemoteTrainingModeDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.isDefault,
    required this.sets,
  });

  factory RemoteTrainingModeDetail.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List? ?? [];
    return RemoteTrainingModeDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      sets: rawSets
          .whereType<Map<String, dynamic>>()
          .map(RemoteTrainingModeSetDetail.fromJson)
          .toList(),
    );
  }
}