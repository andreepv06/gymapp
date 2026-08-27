import '../db/hive_database.dart';
import '../models/hive_models.dart';
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

// La V1 codifica l'appartenenza di un WorkoutExercise a un circuito
// dentro il campo `notes`, con un prefisso "__circuit_<key>" (nessun
// campo dedicato in HiveWorkoutExercise — confermato dai campi reali
// del modello: workoutKey, exerciseKey, exerciseName, muscleGroup,
// sets, targetReps, targetWeight, restSeconds, notes, sortOrder,
// trainingModeKey). Helper isolato: se la convenzione reale del
// prefisso risultasse diversa, questa è l'unica funzione da correggere.
const _circuitNotesPrefix = '__circuit_';

int? _circuitKeyFromNotes(String? notes) {
  if (notes == null || !notes.startsWith(_circuitNotesPrefix)) return null;
  final raw = notes.substring(_circuitNotesPrefix.length);
  // Il prefisso può essere seguito da separatori/altro testo:
  // estraiamo solo la sequenza numerica iniziale.
  final match = RegExp(r'^\d+').firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

/// Sincronizza le schede locali (Hive) verso il backend: scheda,
/// esercizi liberi, circuiti e relativi membri. Solo lettura da
/// Hive, mai scrittura locale.
///
/// LIMITAZIONE NOTA: nessuna deduplicazione strutturale — ogni
/// esecuzione crea NUOVE schede/circuiti nel backend, anche se già
/// sincronizzati in precedenza (risolto strutturalmente allo Step 12).
/// Gli ESERCIZI restano deduplicati per nome.
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
    int circuitExercisesLinked = 0;
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

        // ── Circuiti e relativi membri ──
        final localCircuits = HiveDatabase.instance.getCircuits(workout.key);
        for (final circuit in localCircuits) {
          final remoteCircuit = await _circuitsApi.create(
            workoutId: remoteWorkout.id,
            name: circuit.name,
            rounds: circuit.rounds,
            sortOrder: circuit.sortOrder,
          );
          circuitsCreated++;

          final membersForCircuit = allLocalExercises.where((e) =>
              e.isInCircuit && _circuitKeyFromNotes(e.notes) == circuit.key);

          for (final we in membersForCircuit) {
            final exerciseId =
                await resolveExerciseId(we.exerciseName, we.muscleGroup);
            await _workoutsApi.addExercise(
              workoutId: remoteWorkout.id,
              exerciseId: exerciseId,
              circuitId: remoteCircuit.id,
              sets: we.sets,
              targetReps: we.targetReps,
              targetWeight: we.targetWeight,
              restSeconds: we.restSeconds,
              sortOrder: we.sortOrder,
            );
            circuitExercisesLinked++;
          }
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