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
/// backend, idempotente su due livelli come per esercizi/modalità:
///  1. mapping locale↔remoto persistito;
///  2. fallback per titolo+categoria contro l'elenco remoto, per
///     coprire il cambio di account V1 locale mantenendo lo stesso
///     account backend (le chiavi Hive non sono uniche tra account
///     V1 diversi — causa già diagnosticata sulle modalità).
class GoalSyncRepository {
  static const domain = 'goal';

  final GoalsApiService _api;
  final SyncMappingStorage _mapping;

  GoalSyncRepository({GoalsApiService? api, SyncMappingStorage? mapping})
      : _api = api ?? GoalsApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  String _signature(String title, String category) =>
      '${title.trim().toLowerCase()}|${category.trim().toLowerCase()}';

  Future<GoalSyncResult> syncLocalGoalsToBackend() async {
    final localGoals = GoalDatabase.instance.getGoals();

    final remoteGoals = await _api.fetchAll();
    final remoteBySignature = {
      for (final g in remoteGoals) _signature(g.title, g.category): g.id,
    };

    int goalsCreated = 0;
    int goalsAlreadySynced = 0;
    int completionsCreated = 0;
    int goalsFailed = 0;
    int completionsFailed = 0;

    for (final goal in localGoals) {
      final localKey = goal.key;
      String remoteGoalId;

      final mapped = await _mapping.getRemoteId(domain, localKey);
      if (mapped != null) {
        remoteGoalId = mapped;
        goalsAlreadySynced++;
      } else {
        final signature = _signature(goal.title, goal.category);
        final existingId = remoteBySignature[signature];
        if (existingId != null) {
          await _mapping.setRemoteId(domain, localKey, existingId);
          remoteGoalId = existingId;
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
            remoteBySignature[signature] = remoteGoalId;
            goalsCreated++;
          } on ApiException {
            goalsFailed++;
            continue;
          }
        }
      }

      final completions = GoalDatabase.instance.getCompletionsForGoal(goal.key);
      for (final completion in completions) {
        try {
          await _api.setCompletion(remoteGoalId, completion.date, completion.completed);
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