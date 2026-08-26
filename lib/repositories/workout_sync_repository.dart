import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/circuits_api_service.dart';
import '../services/api/exercises_api_service.dart';
import '../services/api/workouts_api_service.dart';

class WorkoutSyncResult {
  final int workoutsCreated;
  final int freeExercisesLinked;
  final int circuitsCreated;
  final int circuitExercisesLinked;
  final List<String> failedWorkoutNames;

  const WorkoutSyncResult({
    required this.workoutsCreated,
    required this.freeExercisesLinked,
    required this.circuitsCreated,
    required this.circuitExercisesLinked,
    required this.failedWorkoutNames,
  });

  bool get hasFailures => failedWorkoutNames.isNotEmpty;
}

/// Sincronizza le schede locali (Hive) verso il backend: scheda,
/// esercizi liberi e circuiti (come contenitori). Solo lettura da
/// Hive, mai scrittura locale.
///
/// LIMITAZIONE NOTA #1 (documentata esplicitamente):
/// nessuna deduplicazione strutturale — ogni esecuzione crea NUOVE
/// schede/circuiti nel backend, anche se già sincronizzati in
/// precedenza (risolto strutturalmente allo Step 12).
///
/// LIMITAZIONE NOTA #2 — TEMPORANEA (da rimuovere appena
/// disponibile il campo reale su HiveWorkoutExercise che collega
/// un esercizio al proprio circuito): i circuiti vengono creati
/// come contenitori vuoti sul backend; i singoli esercizi al loro
/// interno NON vengono ancora collegati (circuitExercisesLinked
/// resta sempre 0). Gli esercizi liberi (non in circuito) sono
/// invece già sincronizzati correttamente.
class WorkoutSyncRepository {
  final WorkoutsApiService _workoutsApi;
  final CircuitsApiService _circuitsApi;
  final ExercisesApiService _exercisesApi;

  WorkoutSyncRepository({
    WorkoutsApiService? workoutsApi,
    CircuitsApiService? circuitsApi,
    ExercisesApiService? exercisesApi,
  })  : _workoutsApi = workoutsApi ?? WorkoutsApiService(),
        _circuitsApi = circuitsApi ?? CircuitsApiService(),
        _exercisesApi = exercisesApi ?? ExercisesApiService();

  Future<WorkoutSyncResult> syncLocalWorkoutsToBackend() async {
    final localWorkouts = HiveDatabase.instance.getWorkouts();

    final remoteExercises = await _exercisesApi.fetchAll();
    final exerciseIdByName = {
      for (final e in remoteExercises) e.name.trim().toLowerCase(): e.id,
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

    int workoutsCreated = 0;
    int freeExercisesLinked = 0;
    int circuitsCreated = 0;
    const circuitExercisesLinked = 0; // TODO: vedi nota classe sopra
    final failed = <String>[];

    for (final workout in localWorkouts) {
      try {
        final remoteWorkout = await _workoutsApi.create(
          name: workout.name,
          iconId: workout.iconId,
          iconColorIndex: workout.iconColorIndex,
        );
        workoutsCreated++;

        final allLocalExercises =
            HiveDatabase.instance.getWorkoutExercises(workout.key);

        // ── Esercizi liberi (non in circuito) ──
        for (final we in allLocalExercises.where((e) => !e.isInCircuit)) {
          final exerciseId =
              await resolveExerciseId(we.exerciseName, we.muscleGroup);
          await _workoutsApi.addExercise(
            workoutId: remoteWorkout.id,
            exerciseId: exerciseId,
            sets: we.sets,
            targetReps: we.targetReps,
            targetWeight: we.targetWeight,
            restSeconds: we.restSeconds,
            sortOrder: we.sortOrder,
          );
          freeExercisesLinked++;
        }

        // ── Circuiti (solo contenitori, per ora) ──
        final localCircuits = HiveDatabase.instance.getCircuits(workout.key);
        for (final circuit in localCircuits) {
          await _circuitsApi.create(
            workoutId: remoteWorkout.id,
            name: circuit.name,
            rounds: circuit.rounds,
            sortOrder: circuit.sortOrder,
          );
          circuitsCreated++;
          // Collegamento membri-circuito NON ancora implementato:
          // manca il campo reale su HiveWorkoutExercise che indica
          // l'appartenenza a QUALE circuito (isInCircuit dice solo
          // "sì/no", non "quale"). Da completare non appena
          // disponibile il nome esatto del campo.
        }
      } on ApiException {
        failed.add(workout.name);
      }
    }

    return WorkoutSyncResult(
      workoutsCreated: workoutsCreated,
      freeExercisesLinked: freeExercisesLinked,
      circuitsCreated: circuitsCreated,
      circuitExercisesLinked: circuitExercisesLinked,
      failedWorkoutNames: failed,
    );
  }
}