import 'package:hive/hive.dart';

/// Sistema Goals & Habits — completamente indipendente dal
/// sistema Fitness. Nessuna classe qui referenzia HiveWorkout,
/// HiveSession o altri modelli del modulo allenamenti.
class HiveGoal extends HiveObject {
  String title;
  String? description;
  String category;
  String createdAt; // ISO8601

  /// 'daily' | 'specificDays' | 'weekend' | 'weekdays' |
  /// 'dateRange' | 'customInterval'
  String scheduleType;

  /// Usato solo se scheduleType == 'specificDays'.
  /// 1 = lunedì ... 7 = domenica.
  List<int>? scheduleDaysOfWeek;

  /// Usati per 'dateRange' (intervallo) e come ancora per
  /// 'customInterval' (ogni N giorni a partire da questa data).
  String? scheduleStartDate; // yyyy-MM-dd
  String? scheduleEndDate; // yyyy-MM-dd
  int? scheduleCustomInterval; // N giorni

  /// 'active' | 'completed' | 'paused'
  String status;

  int currentStreak;
  int bestStreak;

  /// Per obiettivi con scadenza ("Maratona tra 3 mesi").
  String? deadlineDate; // yyyy-MM-dd

  int colorIndex;

  HiveGoal({
    required this.title,
    this.description,
    required this.category,
    required this.createdAt,
    required this.scheduleType,
    this.scheduleDaysOfWeek,
    this.scheduleStartDate,
    this.scheduleEndDate,
    this.scheduleCustomInterval,
    this.status = 'active',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.deadlineDate,
    this.colorIndex = 0,
  });
}

/// Una "spunta" di completamento per un goal in una data specifica.
class HiveGoalCompletion extends HiveObject {
  int goalKey;
  String date; // yyyy-MM-dd
  bool completed;

  HiveGoalCompletion({
    required this.goalKey,
    required this.date,
    required this.completed,
  });
}