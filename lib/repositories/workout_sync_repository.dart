import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/circuits_api_service.dart';
import '../services/api/exercises_api_service.dart';
import '../services/api/workouts_api_service.dart';
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
  // NUOVO — esercizi che non si sono collegati anche se la scheda
  // è stata creata con successo (visibile separatamente dai
  // fallimenti totali, per diagnosi).
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
/// idempotente. MODIFICATO — ogni collegamento esercizio→scheda è
/// ora avvolto in un try/catch dedicato: prima, un singolo errore
/// (es. conflitto nome esercizio, mappatura stale) interrompeva
/// l'intero ciclo di collegamento per quella scheda, che restava poi
/// "già sincronizzata" per sempre — vuota — senza mai poter
/// recuperare gli esercizi mancanti nei cicli successivi.
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
        // Conflitto (409): l'esercizio esiste già remotamente sotto
        // questo nome, creato tra il fetchAll() iniziale e ora.
        // Ricarichiamo la lista remota una volta e riproviamo,
        // invece di propagare l'eccezione e perdere il collegamento.
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
          // MODIFICATO — try/catch per singolo esercizio: un
          // fallimento qui non deve mai impedire il collegamento
          // degli esercizi successivi della stessa scheda.
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
              continue; // Salta questo circuito, prova i successivi.
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
        // Fallita solo la CREAZIONE della scheda stessa (non un
        // singolo esercizio): qui è corretto marcarla come fallita
        // per intero, dato che non esiste ancora remotamente.
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