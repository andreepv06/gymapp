class RemoteGoalDetail {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String scheduleType;
  final List<int> scheduleDaysOfWeek;
  final String? scheduleStartDate;
  final String? scheduleEndDate;
  final int? scheduleCustomInterval;
  final String? deadlineDate;
  final int colorIndex;

  const RemoteGoalDetail({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.scheduleType,
    required this.scheduleDaysOfWeek,
    this.scheduleStartDate,
    this.scheduleEndDate,
    this.scheduleCustomInterval,
    this.deadlineDate,
    required this.colorIndex,
  });

  factory RemoteGoalDetail.fromJson(Map<String, dynamic> json) {
    final rawDays = json['scheduleDaysOfWeek'] as List? ?? [];
    return RemoteGoalDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      scheduleType: json['scheduleType'] as String,
      scheduleDaysOfWeek: rawDays.whereType<num>().map((e) => e.toInt()).toList(),
      scheduleStartDate: json['scheduleStartDate'] as String?,
      scheduleEndDate: json['scheduleEndDate'] as String?,
      scheduleCustomInterval: json['scheduleCustomInterval'] as int?,
      deadlineDate: json['deadlineDate'] as String?,
      colorIndex: json['colorIndex'] as int? ?? 0,
    );
  }
}

class RemoteGoalCompletionDetail {
  final String date;
  final bool completed;

  const RemoteGoalCompletionDetail({required this.date, required this.completed});

  factory RemoteGoalCompletionDetail.fromJson(Map<String, dynamic> json) =>
      RemoteGoalCompletionDetail(
        date: json['date'] as String,
        completed: json['completed'] as bool? ?? false,
      );
}