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
/// annullata da un fallimento di rete.
///
/// AGGIORNATO (fix resurrezione schede eliminate) — il dominio
/// "workout" ora usa un meccanismo di TOMBSTONE (vedi
/// SyncMappingStorage): prima d'ora, se la chiamata DELETE fire-and-
/// forget non faceva in tempo a completarsi (app chiusa subito dopo,
/// rete assente, cold start Render), la scheda restava viva sul
/// backend e veniva reimportata al successivo download — "resuscitando"
/// nonostante l'utente l'avesse già eliminata. Ora:
///   1. tombstoneWorkout() registra SUBITO (scrittura locale rapida,
///      awaited) l'id remoto come "in eliminazione";
///   2. BackendImportRepository ignora sempre gli id tombstoned;
///   3. retryPendingWorkoutDeletes() ritenta il vero DELETE remoto
///      ad ogni ciclo di sync, finché non riesce.
///
/// LIMITE ANCORA APERTO: lo stesso identico bug (nessun retry per i
/// DELETE falliti) è strutturalmente presente anche per goal/
/// exercise/trainingMode, ma non è stato segnalato per quei domini —
/// non toccati in questo fix per restare nello scope richiesto.
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

  // ── WORKOUT — con tombstone contro la resurrezione ────────────

  /// NUOVO — chiamato AWAITED da WorkoutProvider PRIMA di cancellare
  /// la scheda da Hive. Una singola scrittura locale (SharedPreferences)
  /// è praticamente istantanea rispetto alla chiamata di rete DELETE
  /// vera e propria (sempre fire-and-forget, può impiegare secondi con
  /// Render in cold start): il tombstone ha quindi la certezza quasi
  /// assoluta di essere scritto su disco prima che l'utente possa
  /// chiudere l'app.
  static Future<void> tombstoneWorkout(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_workoutDomain, localKey);
      if (remoteId == null) return;
      await _mapping.addTombstone(_workoutDomain, remoteId);
    } catch (_) {}
  }

  static Future<void> propagateWorkoutDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_workoutDomain, localKey);
      if (remoteId == null) return;
      await WorkoutsApiService().delete(remoteId);
      // NUOVO — mancava: senza questa riga la mappatura locale→remoto
      // restava orfana per sempre (la chiave locale non esiste più).
      await _mapping.removeMapping(_workoutDomain, localKey);
      // Cancellazione remota confermata: il tombstone ha esaurito il
      // suo scopo protettivo, può essere rimosso.
      await _mapping.removeTombstone(_workoutDomain, remoteId);
    } catch (_) {
      // Fallimento di rete: il tombstone (già scritto PRIMA da
      // tombstoneWorkout) resta attivo e continua a proteggere da
      // resurrezioni. Il vero DELETE remoto verrà ritentato
      // automaticamente da retryPendingWorkoutDeletes().
    }
  }

  /// NUOVO — ritenta le cancellazioni remote non ancora confermate.
  /// Chiamato ad ogni ciclo di sync (da WorkoutSyncRepository), sullo
  /// stesso identico principio già usato per gli upload: un
  /// fallimento temporaneo non è definitivo, viene ritentato
  /// automaticamente ai cicli successivi finché non riesce. Nessun
  /// Future.delayed: il "retry" è semplicemente il normale ciclo
  /// periodico di SyncEngine, già esistente.
  static Future<void> retryPendingWorkoutDeletes() async {
    final tombstones = await _mapping.getTombstones(_workoutDomain);
    for (final remoteId in tombstones) {
      try {
        await WorkoutsApiService().delete(remoteId);
        await _mapping.removeTombstone(_workoutDomain, remoteId);
      } catch (_) {
        // Ancora non riuscito: resta tombstoned, ritentato al
        // prossimo ciclo.
      }
    }
  }

    // NUOVO (fix bug confermato: "Elimina sessioni" mai sincronizzato)
  // — stesso identico pattern tombstone già usato per le schede.
  static const _sessionDomain2 = 'session'; // stesso dominio già usato altrove

  static Future<void> tombstoneSession(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_sessionDomain, localKey);
      if (remoteId == null) return;
      await _mapping.addTombstone(_sessionDomain, remoteId);
    } catch (_) {}
  }

  static Future<void> retryPendingSessionDeletes() async {
    final tombstones = await _mapping.getTombstones(_sessionDomain);
    for (final remoteId in tombstones) {
      try {
        await SessionsApiService().delete(remoteId);
        await _mapping.removeTombstone(_sessionDomain, remoteId);
      } catch (_) {}
    }
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

  static Future<void> propagateSessionDelete(int localKey) async {
    try {
      final remoteId = await _mapping.getRemoteId(_sessionDomain, localKey);
      if (remoteId == null) return;
      await SessionsApiService().delete(remoteId);
      await _mapping.removeMapping(_sessionDomain, localKey);
      await _mapping.removeTombstone(_sessionDomain, remoteId);
    } catch (_) {}
  }
}