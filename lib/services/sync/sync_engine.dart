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
class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine();

  // MODIFICATO — da 20s a 8s: rende il pull automatico (dati creati
  // su un altro dispositivo) visibile molto più rapidamente, senza
  // scendere a un polling così aggressivo da sovraccaricare il piano
  // free di Render.
  static const _interval = Duration(seconds: 8);
  Timer? _timer;
  bool _running = false;
  SyncPhase phase = SyncPhase.idle;
  DateTime? lastSuccessAt;
  String? lastError;
  int consecutiveFailures = 0;

  // NUOVO — callback impostato una sola volta da un widget con
  // accesso ai Provider (vedi main.dart). Viene invocato dopo ogni
  // ciclo completato con successo, così i Provider possono
  // ricaricarsi dai box Hive appena aggiornati dall'import, senza
  // che l'utente debba chiudere e riaprire l'app.
  VoidCallback? onSynced;

  bool get isActive => _timer != null;

  void start() {
    if (_timer != null) return;
    SyncTrigger.instance.register(runOnce);
    unawaited(runOnce());
    _timer = Timer.periodic(_interval, (_) => runOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    SyncTrigger.instance.unregister();
    phase = SyncPhase.idle;
    notifyListeners();
  }

  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    try {
      phase = SyncPhase.uploading;
      notifyListeners();
      await _uploadAll();
      phase = SyncPhase.downloading;
      notifyListeners();
      await BackendImportRepository().importAllFromBackend();
      lastSuccessAt = DateTime.now();
      lastError = null;
      consecutiveFailures = 0;
      phase = SyncPhase.idle;
      // NUOVO — notifica i Provider di ricaricarsi ora che l'import
      // ha scritto eventuali dati nuovi nei box Hive.
      onSynced?.call();
    } catch (e) {
      lastError = e.toString();
      consecutiveFailures++;
      phase = SyncPhase.error;
      debugPrint('[SyncEngine] ciclo fallito: $e');
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _uploadAll() async {
    await ExerciseSyncRepository().syncLocalLibraryToBackend();
    await WorkoutSyncRepository().syncLocalWorkoutsToBackend();
    await SessionSyncRepository().syncLocalHistoryToBackend();
    await TrainingModeSyncRepository().syncLocalModesToBackend();
    await GoalSyncRepository().syncLocalGoalsToBackend();
    await SportSessionSyncRepository().syncLocalSportSessionsToBackend();
  }
}

void unawaited(Future<void> future) {}