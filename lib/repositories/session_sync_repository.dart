import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/exercises_api_service.dart';
import '../services/api/sessions_api_service.dart';
import '../services/api/workouts_api_service.dart';

class SessionSyncResult {
  final int sessionsCreated;
  final int setsCreated;
  final int sessionsFailed;
  final int setsFailed;

  const SessionSyncResult({
    required this.sessionsCreated,
    required this.setsCreated,
    required this.sessionsFailed,
    required this.setsFailed,
  });

  bool get hasFailures => sessionsFailed > 0 || setsFailed > 0;
}

/// Sincronizza lo storico allenamenti locale (Hive) verso il
/// backend. Solo lettura da Hive, mai scrittura/cancellazione
/// locale — anche in caso di errore parziale, i dati Hive restano
/// invariati.
///
/// LIMITAZIONI NOTE (documentate esplicitamente):
///  - nessuna deduplicazione: ogni esecuzione ricrea tutte le
///    sessioni nel backend (idempotenza reale prevista Step 12);
///  - il collegamento sessione→scheda remota è best-effort per
///    nome, solo se la scheda è già presente sul backend;
///  - trainingModeId non sincronizzato sulle serie in questo step
///    (previsto Step 10, quando le modalità saranno sincronizzate).
class SessionSyncRepository {
  final SessionsApiService _sessionsApi;
  final ExercisesApiService _exercisesApi;
  final WorkoutsApiService _workoutsApi;

  SessionSyncRepository({
    SessionsApiService? sessionsApi,
    ExercisesApiService? exercisesApi,
    WorkoutsApiService? workoutsApi,
  })  : _sessionsApi = sessionsApi ?? SessionsApiService(),
        _exercisesApi = exercisesApi ?? ExercisesApiService(),
        _workoutsApi = workoutsApi ?? WorkoutsApiService();

  Future<SessionSyncResult> syncLocalHistoryToBackend() async {
    final localSessions = HiveDatabase.instance.getSessions();

    final remoteExercises = await _exercisesApi.fetchAll();
    final exerciseIdByName = {
      for (final e in remoteExercises) e.name.trim().toLowerCase(): e.id,
    };

    final remoteWorkouts = await _workoutsApi.fetchAll();
    final workoutIdByName = {
      for (final w in remoteWorkouts) w.name.trim().toLowerCase(): w.id,
    };

    Future<String> resolveExerciseId(String name, String muscleGroup) async {
      final normalized = name.trim().toLowerCase();
      final existing = exerciseIdByName[normalized];
      if (existing != null) return existing;
      final created = await _exercisesApi.create(
        name: name,
        muscleGroup: muscleGroup,
      );
      exerciseIdByName[normalized] = created.id;
      return created.id;
    }

    int sessionsCreated = 0;
    int setsCreated = 0;
    int sessionsFailed = 0;
    int setsFailed = 0;

    for (final session in localSessions) {
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
          workoutIdByName[session.workoutName.trim().toLowerCase()];

      String remoteSessionId;
      try {
        final remoteSession = await _sessionsApi.create(
          workoutId: matchedWorkoutId,
          workoutName: session.workoutName,
          isoDate: isoDate,
          durationSeconds: session.durationSeconds,
        );
        remoteSessionId = remoteSession.id;
        sessionsCreated++;
      } on ApiException {
        sessionsFailed++;
        continue;
      }

      final localSets = HiveDatabase.instance.getSessionSets(session.key);
      for (final set in localSets) {
        try {
          final exerciseId =
              await resolveExerciseId(set.exerciseName, set.muscleGroup);
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
      setsCreated: setsCreated,
      sessionsFailed: sessionsFailed,
      setsFailed: setsFailed,
    );
  }
}