import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../repositories/exercise_sync_repository.dart';
import '../../repositories/workout_sync_repository.dart';
import '../../repositories/session_sync_repository.dart';
import '../../repositories/training_mode_sync_repository.dart';
import '../../repositories/goal_sync_repository.dart';
import '../../repositories/sport_session_sync_repository.dart';
import '../../repositories/backend_import_repository.dart';
import 'sync_trigger.dart';

enum SyncPhase { idle, uploading, downloading, error }

/// Motore di sincronizzazione: ciclo periodico (rete di sicurezza) +
/// ciclo immediato quando SyncTrigger.requestSync() viene chiamato da
/// un Provider dopo una mutazione locale, con debounce di 3s. Upload
/// sempre prima del download.
///
/// AGGIORNATO (fix root cause blocco sync cross-device) — PRIMA,
/// _uploadAll() chiamava le 6 repository in sequenza SENZA alcun
/// isolamento tra loro: un'eccezione non gestita lanciata da UNA
/// SOLA repository (es. un dato corrotto lato backend che fa
/// fallire ExerciseSyncRepository) interrompeva l'intero
/// _uploadAll(), e di conseguenza l'intero ciclo runOnce() falliva
/// PRIMA ANCORA di arrivare al download — bloccando la
/// sincronizzazione di TUTTI i domini successivi (schede, storico,
/// modalità, obiettivi), ad OGNI ciclo, in modo deterministico e
/// permanente finché il dato corrotto non veniva rimosso. Questo
/// spiegava perché un nuovo obiettivo creato su un dispositivo non
/// arrivava mai su un altro anche aspettando: il ciclo di sync non
/// falliva "a volte", falliva SEMPRE nello stesso punto.
///
/// Ora ogni repository è isolata: un fallimento in una non impedisce
/// alle altre di essere tentate, né impedisce alla fase di download
/// di essere comunque eseguita in questo stesso ciclo.
class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine();

  static const _interval = Duration(seconds: 8);
  Timer? _timer;
  bool _running = false;
  int _epoch = 0;
  SyncPhase phase = SyncPhase.idle;
  DateTime? lastSuccessAt;
  String? lastError;
  int consecutiveFailures = 0;

  VoidCallback? onSynced;

  bool get isActive => _timer != null;

  void start() {
    _epoch++;
    if (_timer != null) return;
    SyncTrigger.instance.register(runOnce);
    unawaited(runOnce());
    _timer = Timer.periodic(_interval, (_) => runOnce());
  }

  void stop() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    SyncTrigger.instance.unregister();
    phase = SyncPhase.idle;
    notifyListeners();
  }

  Future<void> runOnce() async {
    if (_running) return;
    final myEpoch = _epoch;
    _running = true;
    try {
      phase = SyncPhase.uploading;
      notifyListeners();
      await _uploadAll(myEpoch);
      if (myEpoch != _epoch) return;
      phase = SyncPhase.downloading;
      notifyListeners();
      await BackendImportRepository()
          .importAllFromBackend(shouldAbort: () => myEpoch != _epoch);
      if (myEpoch != _epoch) return;
      lastSuccessAt = DateTime.now();
      lastError = null;
      consecutiveFailures = 0;
      phase = SyncPhase.idle;
      onSynced?.call();
    } catch (e) {
      if (myEpoch != _epoch) return;
      lastError = e.toString();
      consecutiveFailures++;
      phase = SyncPhase.error;
      debugPrint('[SyncEngine] ciclo fallito: $e');
    } finally {
      if (myEpoch == _epoch) _running = false;
      notifyListeners();
    }
  }

  // MODIFICATO (fix root cause) — ogni chiamata è ora avvolta in un
  // try/catch dedicato tramite _safeUpload: il fallimento di UNA
  // repository viene loggato e contenuto, senza impedire il
  // tentativo delle successive né bloccare la fase di download che
  // segue in runOnce().
  Future<void> _uploadAll(int myEpoch) async {
    await _safeUpload('esercizi', () =>
        ExerciseSyncRepository().syncLocalLibraryToBackend());
    if (myEpoch != _epoch) return;
    await _safeUpload('schede', () =>
        WorkoutSyncRepository().syncLocalWorkoutsToBackend());
    if (myEpoch != _epoch) return;
    await _safeUpload('storico', () =>
        SessionSyncRepository().syncLocalHistoryToBackend());
    if (myEpoch != _epoch) return;
    await _safeUpload('modalità', () =>
        TrainingModeSyncRepository().syncLocalModesToBackend());
    if (myEpoch != _epoch) return;
    await _safeUpload('obiettivi', () =>
        GoalSyncRepository().syncLocalGoalsToBackend());
    if (myEpoch != _epoch) return;
    await _safeUpload('sessioni sportive', () =>
        SportSessionSyncRepository().syncLocalSportSessionsToBackend());
  }

  Future<void> _safeUpload(
      String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint(
          '[SyncEngine] Upload "$label" fallito, gli altri domini non sono impattati: $e');
    }
  }
}

void unawaited(Future<void> future) {}