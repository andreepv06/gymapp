import '../../repositories/sync_mapping_storage.dart';
import '../api/exercises_api_service.dart';
import '../api/workouts_api_service.dart';
import '../api/goals_api_service.dart';
import '../api/training_modes_api_service.dart';
import '../api/sessions_api_service.dart';

/// Propaga al backend le eliminazioni effettuate localmente,
/// risolvendo l'id remoto tramite lo stesso SyncMappingStorage già
/// usato dagli upload. Best-effort e silenzioso: l'eliminazione
/// locale (Hive) è già avvenuta e non deve mai essere bloccata o
/// annullata da un fallimento di rete — se la chiamata al backend
/// fallisce, il dato resta orfano lì fino al prossimo ciclo utile
/// (limite accettato, coerente con "nessun dato perso localmente").
///
/// AGGIORNATO (audit sincronizzazione) — aggiunto
/// propagateSessionDelete: prima d'ora, eliminare una sessione dallo
/// Storico (HistoryScreen) non propagava mai il DELETE al backend,
/// causando la sua "resurrezione" su un secondo dispositivo al
/// successivo download (BackendImportRepository la ritrovava ancora
/// presente remotamente e la reimportava). Segue esattamente lo
/// stesso pattern dei 4 metodi già esistenti in questa classe.
///
/// LIMITE ANCORA APERTO: sport-session non coperta in questo blocco
/// (SportProvider.deleteSession lo dichiara già esplicitamente nel
/// proprio commento) — serve sport_sessions_api_service.dart, non
/// disponibile in questa sessione di lavoro.
class DeletePropagator {
  static const _exerciseDomain = 'exercise';
  static const _workoutDomain = 'workout';
  static const _goalDomain = 'goal';
  static const _trainingModeDomain = 'trainingMode';
  static const _sessionDomain = 'session';

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

  // NUOVO — vedi commento di classe.
  static Future<void> propagateSessionDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_sessionDomain, localKey);
      if (remoteId == null) return;
      await SessionsApiService().delete(remoteId);
      await _mapping.removeMapping(_sessionDomain, localKey);
    } catch (_) {}
  }
}