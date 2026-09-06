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

/// Motore di sincronizzazione: ciclo periodico ogni 20s (rete di
/// sicurezza) + ciclo immediato quando SyncTrigger.requestSync()
/// viene chiamato da un Provider dopo una mutazione locale (create/
/// update/delete), con debounce di 3s. Upload sempre prima del
/// download, stesso ordine già validato manualmente.
class SyncEngine extends ChangeNotifier {
  // NUOVO — singleton, così può essere avviato/fermato da
  // BackendAuthProvider senza bisogno di un BuildContext.
  static final SyncEngine instance = SyncEngine();

  static const _interval = Duration(seconds: 20);
  Timer? _timer;
  bool _running = false;
  SyncPhase phase = SyncPhase.idle;
  DateTime? lastSuccessAt;
  String? lastError;
  int consecutiveFailures = 0;

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