import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/exercises_api_service.dart';
import '../services/api/sessions_api_service.dart';
import 'sync_mapping_storage.dart';

class SessionSyncResult {
  final int sessionsCreated;
  final int sessionsAlreadySynced;
  final int setsCreated;
  final int sessionsFailed;
  final int setsFailed;

  const SessionSyncResult({
    required this.sessionsCreated,
    required this.sessionsAlreadySynced,
    required this.setsCreated,
    required this.sessionsFailed,
    required this.setsFailed,
  });

  bool get hasFailures => sessionsFailed > 0 || setsFailed > 0;
}

/// Sincronizza lo storico allenamenti locale (Hive) verso il
/// backend, in modo idempotente: sessioni già sincronizzate vengono
/// saltate. Collegamento sessione→scheda remota tramite mapping
/// persistito (session.workoutKey → workout remoto), più affidabile
/// del matching per nome usato nella prima versione. Esercizi delle
/// serie risolti tramite mapping (set.exerciseKey). Solo lettura da
/// Hive, mai scrittura/cancellazione locale.
class SessionSyncRepository {
  static const _sessionDomain = 'session';
  static const _workoutDomain = 'workout';
  static const _exerciseDomain = 'exercise';

  final SessionsApiService _sessionsApi;
  final ExercisesApiService _exercisesApi;
  final SyncMappingStorage _mapping;

  SessionSyncRepository({
    SessionsApiService? sessionsApi,
    ExercisesApiService? exercisesApi,
    SyncMappingStorage? mapping,
  })  : _sessionsApi = sessionsApi ?? SessionsApiService(),
        _exercisesApi = exercisesApi ?? ExercisesApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<SessionSyncResult> syncLocalHistoryToBackend() async {
    final localSessions = HiveDatabase.instance.getSessions();

    final remoteExercises = await _exercisesApi.fetchAll();
    final exerciseIdByName = {
      for (final e in remoteExercises) e.name.trim().toLowerCase(): e.id,
    };

    Future<String> resolveExerciseId(
        int exerciseKey, String name, String muscleGroup) async {
      final mapped = await _mapping.getRemoteId(_exerciseDomain, exerciseKey);
      if (mapped != null) return mapped;
      final normalized = name.trim().toLowerCase();
      final existing = exerciseIdByName[normalized];
      if (existing != null) {
        await _mapping.setRemoteId(_exerciseDomain, exerciseKey, existing);
        return existing;
      }
      final created =
          await _exercisesApi.create(name: name, muscleGroup: muscleGroup);
      exerciseIdByName[normalized] = created.id;
      await _mapping.setRemoteId(_exerciseDomain, exerciseKey, created.id);
      return created.id;
    }

    int sessionsCreated = 0;
    int sessionsAlreadySynced = 0;
    int setsCreated = 0;
    int sessionsFailed = 0;
    int setsFailed = 0;

    for (final session in localSessions) {
      final sessionLocalKey = session.key;
      final alreadyId =
          await _mapping.getRemoteId(_sessionDomain, sessionLocalKey);
      if (alreadyId != null) {
        sessionsAlreadySynced++;
        continue;
      }

      String? isoDate;
      try {
        isoDate = DateTime.parse(session.date).toIso8601String();
      } catch (_) {
        isoDate = null;
      }
      if (isoDate == null) {
        sessionsFailed++;
        continue;
      }

      final matchedWorkoutId =
          await _mapping.getRemoteId(_workoutDomain, session.workoutKey);

      String remoteSessionId;
      try {
        final remoteSession = await _sessionsApi.create(
          workoutId: matchedWorkoutId,
          workoutName: session.workoutName,
          isoDate: isoDate,
          durationSeconds: session.durationSeconds,
        );
        remoteSessionId = remoteSession.id;
        await _mapping.setRemoteId(
            _sessionDomain, sessionLocalKey, remoteSessionId);
        sessionsCreated++;
      } on ApiException {
        sessionsFailed++;
        continue;
      }

      final localSets = HiveDatabase.instance.getSessionSets(session.key);
      for (final set in localSets) {
        try {
          final exerciseId = await resolveExerciseId(
              set.exerciseKey, set.exerciseName, set.muscleGroup);
          await _sessionsApi.addSet(
            sessionId: remoteSessionId,
            exerciseId: exerciseId,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            completed: set.completed,
            restSeconds: set.restSeconds,
            executionStatus: set.executionStatus,
          );
          setsCreated++;
        } on ApiException {
          setsFailed++;
        }
      }
    }

    return SessionSyncResult(
      sessionsCreated: sessionsCreated,
      sessionsAlreadySynced: sessionsAlreadySynced,
      setsCreated: setsCreated,
      sessionsFailed: sessionsFailed,
      setsFailed: setsFailed,
    );
  }
}