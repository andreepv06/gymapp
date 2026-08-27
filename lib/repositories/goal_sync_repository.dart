import '../db/goal_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/goals_api_service.dart';
import 'sync_mapping_storage.dart';

class GoalSyncResult {
  final int goalsCreated;
  final int goalsAlreadySynced;
  final int completionsCreated;
  final int goalsFailed;
  final int completionsFailed;

  const GoalSyncResult({
    required this.goalsCreated,
    required this.goalsAlreadySynced,
    required this.completionsCreated,
    required this.goalsFailed,
    required this.completionsFailed,
  });

  bool get hasFailures => goalsFailed > 0 || completionsFailed > 0;
}

/// Sincronizza obiettivi e completamenti locali (Hive) verso il
/// backend, in modo idempotente sugli obiettivi (mapping persistito).
/// I completamenti vengono risincronizzati anche per obiettivi già
/// mappati: è sicuro perché PUT /goals/:id/completions/:date è
/// idempotente per costruzione lato backend (upsert sulla data).
class GoalSyncRepository {
  static const domain = 'goal';

  final GoalsApiService _api;
  final SyncMappingStorage _mapping;

  GoalSyncRepository({GoalsApiService? api, SyncMappingStorage? mapping})
      : _api = api ?? GoalsApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<GoalSyncResult> syncLocalGoalsToBackend() async {
    final localGoals = GoalDatabase.instance.getGoals();

    int goalsCreated = 0;
    int goalsAlreadySynced = 0;
    int completionsCreated = 0;
    int goalsFailed = 0;
    int completionsFailed = 0;

    for (final goal in localGoals) {
      final localKey = goal.key;
      String remoteGoalId;

      final existing = await _mapping.getRemoteId(domain, localKey);
      if (existing != null) {
        remoteGoalId = existing;
        goalsAlreadySynced++;
      } else {
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
          await _mapping.setRemoteId(domain, localKey, remoteGoalId);
          goalsCreated++;
        } on ApiException {
          goalsFailed++;
          continue;
        }
      }

      final completions = GoalDatabase.instance.getCompletionsForGoal(goal.key);
      for (final completion in completions) {
        try {
          await _api.setCompletion(
              remoteGoalId, completion.date, completion.completed);
          completionsCreated++;
        } on ApiException {
          completionsFailed++;
        }
      }
    }

    return GoalSyncResult(
      goalsCreated: goalsCreated,
      goalsAlreadySynced: goalsAlreadySynced,
      completionsCreated: completionsCreated,
      goalsFailed: goalsFailed,
      completionsFailed: completionsFailed,
    );
  }
}