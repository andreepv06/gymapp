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

  // FIX (Step 1 — bug B confermato dal test di cambio account) —
  // PRIMA, se il timer periodico era già attivo (ereditato da un
  // account precedente mai fermato esplicitamente — es. cambio
  // account tramite "Cambia account" in Impostazioni, che chiama
  // AuthProvider.login() SENZA mai passare da logout()/
  // SyncEngine.stop()), start() era un NO-OP: incrementava solo
  // l'epoch e usciva, senza eseguire alcun tentativo di sync
  // immediato. Il nuovo account doveva quindi aspettare fino a 8
  // secondi il prossimo tick del vecchio timer periodico per vedere
  // anche solo tentato un primo import — spiegando i dati del
  // vecchio profilo ancora visibili subito dopo il cambio account.
  //
  // Ora start() CANCELLA sempre il timer esistente e ne crea uno
  // nuovo, eseguendo SEMPRE un tentativo di sync immediato alla
  // chiamata — indipendentemente da uno stato precedente ereditato
  // da un altro account. L'epoch (già esistente) continua a
  // garantire che eventuali cicli ancora in volo per l'account
  // precedente si interrompano in sicurezza senza scrivere dati
  // nel contesto del nuovo utente.
  void start() {
    _epoch++;
    _timer?.cancel();
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