import '../db/goal_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/goals_api_service.dart';

class GoalSyncResult {
  final int goalsCreated;
  final int completionsCreated;
  final int goalsFailed;
  final int completionsFailed;

  const GoalSyncResult({
    required this.goalsCreated,
    required this.completionsCreated,
    required this.goalsFailed,
    required this.completionsFailed,
  });

  bool get hasFailures => goalsFailed > 0 || completionsFailed > 0;
}

/// Sincronizza obiettivi e relativi completamenti locali (Hive)
/// verso il backend. Solo lettura da Hive, mai scrittura locale.
///
/// LIMITAZIONE NOTA: nessuna deduplicazione — ogni esecuzione crea
/// nuovi obiettivi sul backend (Step 12).
class GoalSyncRepository {
  final GoalsApiService _api;
  GoalSyncRepository({GoalsApiService? api}) : _api = api ?? GoalsApiService();

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<GoalSyncResult> syncLocalGoalsToBackend() async {
    final localGoals = GoalDatabase.instance.getGoals();

    int goalsCreated = 0;
    int completionsCreated = 0;
    int goalsFailed = 0;
    int completionsFailed = 0;

    for (final goal in localGoals) {
      String remoteGoalId;
      try {
        final remote = await _api.create(
          title: goal.title,
          description: goal.description,
          category: goal.category,
          scheduleType: goal.scheduleType,
          scheduleDaysOfWeek: goal.scheduleDaysOfWeek,
          scheduleStartDate: goal.scheduleStartDate,
          scheduleEndDate: goal.scheduleEndDate,
          scheduleCustomInterval: goal.scheduleCustomInterval,
          deadlineDate: goal.deadlineDate,
          colorIndex: goal.colorIndex,
        );
        remoteGoalId = remote.id;
        goalsCreated++;
      } on ApiException {
        goalsFailed++;
        continue;
      }

      final completions = GoalDatabase.instance.getCompletionsForGoal(goal.key);
      for (final completion in completions) {
        try {
          await _api.setCompletion(
            remoteGoalId,
            completion.date,
            completion.completed,
          );
          completionsCreated++;
        } on ApiException {
          completionsFailed++;
        }
      }
    }

    return GoalSyncResult(
      goalsCreated: goalsCreated,
      completionsCreated: completionsCreated,
      goalsFailed: goalsFailed,
      completionsFailed: completionsFailed,
    );
  }
}