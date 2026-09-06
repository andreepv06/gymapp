import '../../repositories/sync_mapping_storage.dart';
import '../api/exercises_api_service.dart';
import '../api/workouts_api_service.dart';
import '../api/goals_api_service.dart';
import '../api/training_modes_api_service.dart';

/// Propaga al backend le eliminazioni effettuate localmente,
/// risolvendo l'id remoto tramite lo stesso SyncMappingStorage già
/// usato dagli upload. Best-effort e silenzioso: l'eliminazione
/// locale (Hive) è già avvenuta e non deve mai essere bloccata o
/// annullata da un fallimento di rete — se la chiamata al backend
/// fallisce, il dato resta orfano lì fino al prossimo ciclo utile
/// (limite accettato, coerente con "nessun dato perso localmente").
///
/// LIMITE DICHIARATO: copre solo i domini con endpoint DELETE reale
/// più frequentemente eliminati (esercizi, schede, obiettivi,
/// modalità — soft-delete). Sessioni/sport-session non propagate in
/// questo blocco (nessuna azione di eliminazione diretta osservata
/// nei Provider reali forniti, a parte casi limite come
/// abandonSession, non prioritari).
class DeletePropagator {
  static const _exerciseDomain = 'exercise';
  static const _workoutDomain = 'workout';
  static const _goalDomain = 'goal';
  static const _trainingModeDomain = 'trainingMode';

  static final _mapping = SyncMappingStorage();

  static Future<void> propagateExerciseDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_exerciseDomain, localKey);
      if (remoteId == null) return;
      await ExercisesApiService().delete(remoteId);
    } catch (_) {}
  }

  static Future<void> propagateWorkoutDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_workoutDomain, localKey);
      if (remoteId == null) return;
      await WorkoutsApiService().delete(remoteId);
    } catch (_) {}
  }

  static Future<void> propagateGoalDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_goalDomain, localKey);
      if (remoteId == null) return;
      await GoalsApiService().delete(remoteId);
    } catch (_) {}
  }

  static Future<void> propagateTrainingModeDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_trainingModeDomain, localKey);
      if (remoteId == null) return;
      await TrainingModesApiService().softDelete(remoteId);
    } catch (_) {}
  }
}