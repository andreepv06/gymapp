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
/// RISCRITTO (audit sincronizzazione cross-device) — causa radice
/// del sintomo "scheda presente sul secondo dispositivo ma senza
/// esercizi": PRIMA, una volta che una scheda risultava "già
/// sincronizzata" (mapping locale→remoto presente), l'INTERO blocco
/// di collegamento esercizi/circuiti veniva saltato per sempre, anche
/// se il collegamento era fallito al primo tentativo (es. timeout
/// durante cold start di Render). Il fallimento veniva solo contato
/// in exerciseLinkFailures, mai più ritentato.
///
/// ORA: ogni singolo collegamento esercizio↔scheda ha il proprio
/// tracking indipendente in SyncMappingStorage (dominio
/// 'workoutExerciseLink', chiave = HiveWorkoutExercise.key locale).
/// Il ciclo verifica e ritenta i collegamenti mancanti ad OGNI
/// esecuzione, indipendentemente dallo stato "scheda già
/// sincronizzata" — stesso principio di retry incrementale già usato
/// con successo per DeletePropagator/tombstone.
class WorkoutSyncRepository {
  static const _workoutDomain = 'workout';
  static const _circuitDomain = 'circuit';
  static const _exerciseDomain = 'exercise';
  // NUOVO — dominio dedicato al tracking del singolo collegamento.
  // WorkoutsApiService.addExercise() non restituisce un id del link
  // creato: usiamo la sola PRESENZA della mappatura come flag di
  // successo (valore = id remoto della scheda, utile in debug).
  static const _workoutExerciseDomain = 'workoutExerciseLink';

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
      String remoteWorkoutId;

      final alreadyWorkoutId =
          await _mapping.getRemoteId(_workoutDomain, workoutLocalKey);
      if (alreadyWorkoutId != null) {
        remoteWorkoutId = alreadyWorkoutId;
        workoutsAlreadySynced++;
      } else {
        try {
          final remoteWorkout = await _workoutsApi.create(
            name: workout.name,
            iconId: workout.iconId,
            iconColorIndex: workout.iconColorIndex,
          );
          remoteWorkoutId = remoteWorkout.id;
          await _mapping.setRemoteId(
              _workoutDomain, workoutLocalKey, remoteWorkoutId);
          workoutsCreated++;
        } on ApiException {
          // Fallita la creazione della scheda stessa: senza un id
          // remoto non si può procedere al collegamento esercizi per
          // questa scheda in questo ciclo — verrà ritentata al
          // prossimo (stesso comportamento di prima).
          failed.add(workout.name);
          continue;
        }
      }

      // FIX — indipendentemente da "scheda appena creata" o "scheda
      // già sincronizzata", verifica e collega ogni singolo esercizio
      // libero non ancora confermato sul backend.
      final allLocalExercises =
          HiveDatabase.instance.getWorkoutExercises(workout.key);

      for (final we in allLocalExercises.where((e) => !e.isInCircuit)) {
        final linkKey = we.key;
        final alreadyLinked =
            await _mapping.getRemoteId(_workoutExerciseDomain, linkKey);
        if (alreadyLinked != null) continue;
        try {
          final exerciseId = await resolveExerciseId(
              we.exerciseKey, we.exerciseName, we.muscleGroup);
          await _workoutsApi.addExercise(
            workoutId: remoteWorkoutId,
            exerciseId: exerciseId,
            sets: we.sets,
            targetReps: we.targetReps,
            targetWeight: we.targetWeight,
            restSeconds: we.restSeconds,
            sortOrder: we.sortOrder,
          );
          await _mapping.setRemoteId(
              _workoutExerciseDomain, linkKey, remoteWorkoutId);
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
              workoutId: remoteWorkoutId,
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
          final linkKey = we.key;
          final alreadyLinked =
              await _mapping.getRemoteId(_workoutExerciseDomain, linkKey);
          if (alreadyLinked != null) continue;
          try {
            final exerciseId = await resolveExerciseId(
                we.exerciseKey, we.exerciseName, we.muscleGroup);
            await _workoutsApi.addExercise(
              workoutId: remoteWorkoutId,
              exerciseId: exerciseId,
              circuitId: remoteCircuitId,
              sets: we.sets,
              targetReps: we.targetReps,
              targetWeight: we.targetWeight,
              restSeconds: we.restSeconds,
              sortOrder: we.sortOrder,
            );
            await _mapping.setRemoteId(
                _workoutExerciseDomain, linkKey, remoteWorkoutId);
            circuitExercisesLinked++;
          } on ApiException {
            exerciseLinkFailures++;
          }
        }
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