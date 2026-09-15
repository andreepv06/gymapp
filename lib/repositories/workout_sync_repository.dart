import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/circuits_api_service.dart';
import '../services/api/exercises_api_service.dart';
import '../services/api/workouts_api_service.dart';
import '../services/sync/delete_propagator.dart';
import 'sync_mapping_storage.dart';

const _circuitNotesPrefix = '__circuit_';

int? _circuitKeyFromNotes(String? notes) {
  if (notes == null || !notes.startsWith(_circuitNotesPrefix)) return null;
  final raw = notes.substring(_circuitNotesPrefix.length);
  final match = RegExp(r'^\d+').firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

class WorkoutSyncResult {
  final int workoutsCreated;
  final int workoutsAlreadySynced;
  final int freeExercisesLinked;
  final int circuitsCreated;
  final int circuitExercisesLinked;
  final List<String> failedWorkoutNames;
  final int exerciseLinkFailures;
  const WorkoutSyncResult({
    required this.workoutsCreated,
    required this.workoutsAlreadySynced,
    required this.freeExercisesLinked,
    required this.circuitsCreated,
    required this.circuitExercisesLinked,
    required this.failedWorkoutNames,
    this.exerciseLinkFailures = 0,
  });
  bool get hasFailures => failedWorkoutNames.isNotEmpty;
}

/// Sincronizza le schede locali (Hive) verso il backend, in modo
/// idempotente.
///
/// AGGIORNATO (fix resurrezione schede eliminate) — ogni ciclo
/// ritenta prima le cancellazioni remote ancora pendenti
/// (retryPendingWorkoutDeletes), sullo stesso principio già usato
/// per gli upload: un DELETE fallito una volta non è definitivo,
/// viene ritentato automaticamente qui ad ogni ciclo.
class WorkoutSyncRepository {
  static const _workoutDomain = 'workout';
  static const _circuitDomain = 'circuit';
  static const _exerciseDomain = 'exercise';

  final WorkoutsApiService _workoutsApi;
  final CircuitsApiService _circuitsApi;
  final ExercisesApiService _exercisesApi;
  final SyncMappingStorage _mapping;

  WorkoutSyncRepository({
    WorkoutsApiService? workoutsApi,
    CircuitsApiService? circuitsApi,
    ExercisesApiService? exercisesApi,
    SyncMappingStorage? mapping,
  })  : _workoutsApi = workoutsApi ?? WorkoutsApiService(),
        _circuitsApi = circuitsApi ?? CircuitsApiService(),
        _exercisesApi = exercisesApi ?? ExercisesApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<WorkoutSyncResult> syncLocalWorkoutsToBackend() async {
    // NUOVO — ritenta eventuali cancellazioni remote non ancora
    // confermate PRIMA di procedere con l'upload delle schede
    // attuali (ordine ininfluente per la correttezza, ma coerente
    // con "cancellazioni prima di tutto" come principio generale).
    await DeletePropagator.retryPendingWorkoutDeletes();

    final localWorkouts = HiveDatabase.instance.getWorkouts();
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
      try {
        final created =
            await _exercisesApi.create(name: name, muscleGroup: muscleGroup);
        exerciseIdByName[normalized] = created.id;
        await _mapping.setRemoteId(_exerciseDomain, exerciseKey, created.id);
        return created.id;
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.conflict) {
          final refreshed = await _exercisesApi.fetchAll();
          final match = refreshed
              .where((r) => r.name.trim().toLowerCase() == normalized);
          if (match.isNotEmpty) {
            exerciseIdByName[normalized] = match.first.id;
            await _mapping.setRemoteId(
                _exerciseDomain, exerciseKey, match.first.id);
            return match.first.id;
          }
        }
        rethrow;
      }
    }

    int workoutsCreated = 0;
    int workoutsAlreadySynced = 0;
    int freeExercisesLinked = 0;
    int circuitsCreated = 0;
    int circuitExercisesLinked = 0;
    int exerciseLinkFailures = 0;
    final failed = <String>[];

    for (final workout in localWorkouts) {
      final workoutLocalKey = workout.key;
      final alreadyWorkoutId =
          await _mapping.getRemoteId(_workoutDomain, workoutLocalKey);
      if (alreadyWorkoutId != null) {
        workoutsAlreadySynced++;
        continue;
      }
      try {
        final remoteWorkout = await _workoutsApi.create(
          name: workout.name,
          iconId: workout.iconId,
          iconColorIndex: workout.iconColorIndex,
        );
        await _mapping.setRemoteId(
            _workoutDomain, workoutLocalKey, remoteWorkout.id);
        workoutsCreated++;

        final allLocalExercises =
            HiveDatabase.instance.getWorkoutExercises(workout.key);

        for (final we in allLocalExercises.where((e) => !e.isInCircuit)) {
          try {
            final exerciseId = await resolveExerciseId(
                we.exerciseKey, we.exerciseName, we.muscleGroup);
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
          } on ApiException {
            exerciseLinkFailures++;
          }
        }

        final localCircuits = HiveDatabase.instance.getCircuits(workout.key);
        for (final circuit in localCircuits) {
          final circuitLocalKey = circuit.key;
          var remoteCircuitId =
              await _mapping.getRemoteId(_circuitDomain, circuitLocalKey);
          if (remoteCircuitId == null) {
            try {
              final remoteCircuit = await _circuitsApi.create(
                workoutId: remoteWorkout.id,
                name: circuit.name,
                rounds: circuit.rounds,
                sortOrder: circuit.sortOrder,
              );
              remoteCircuitId = remoteCircuit.id;
              await _mapping.setRemoteId(
                  _circuitDomain, circuitLocalKey, remoteCircuitId);
              circuitsCreated++;
            } on ApiException {
              continue;
            }
          }

          final membersForCircuit = allLocalExercises.where((e) =>
              e.isInCircuit && _circuitKeyFromNotes(e.notes) == circuit.key);
          for (final we in membersForCircuit) {
            try {
              final exerciseId = await resolveExerciseId(
                  we.exerciseKey, we.exerciseName, we.muscleGroup);
              await _workoutsApi.addExercise(
                workoutId: remoteWorkout.id,
                exerciseId: exerciseId,
                circuitId: remoteCircuitId,
                sets: we.sets,
                targetReps: we.targetReps,
                targetWeight: we.targetWeight,
                restSeconds: we.restSeconds,
                sortOrder: we.sortOrder,
              );
              circuitExercisesLinked++;
            } on ApiException {
              exerciseLinkFailures++;
            }
          }
        }
      } on ApiException {
        failed.add(workout.name);
      }
    }

    return WorkoutSyncResult(
      workoutsCreated: workoutsCreated,
      workoutsAlreadySynced: workoutsAlreadySynced,
      freeExercisesLinked: freeExercisesLinked,
      circuitsCreated: circuitsCreated,
      circuitExercisesLinked: circuitExercisesLinked,
      failedWorkoutNames: failed,
      exerciseLinkFailures: exerciseLinkFailures,
    );
  }
}