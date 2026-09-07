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
/// MODIFICATO — introdotto un contatore di "epoca" (_epoch). Prima,
/// stop() cancellava solo il Timer futuro ma NON interrompeva un
/// runOnce() già in esecuzione: quel ciclo orfano continuava a girare
/// in background con HiveDatabase/TokenStorage (singleton, letti
/// "live") ormai puntati al NUOVO account appena switchato — causa
/// osservata di raffiche di 401/400 durante switch rapidi di account
/// (logout → registrazione immediata sullo stesso dispositivo).
/// Ora ogni runOnce() cattura l'epoca corrente all'avvio e la
/// ricontrolla dopo ogni fase; se stop()/start() hanno incrementato
/// l'epoca nel frattempo, il ciclo si interrompe SENZA proseguire con
/// altre chiamate di rete, invece di continuare "alla cieca".
class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine();

  static const _interval = Duration(seconds: 8);
  Timer? _timer;
  bool _running = false;
  int _epoch = 0; // NUOVO
  SyncPhase phase = SyncPhase.idle;
  DateTime? lastSuccessAt;
  String? lastError;
  int consecutiveFailures = 0;

  VoidCallback? onSynced;

  bool get isActive => _timer != null;

  void start() {
    _epoch++; // NUOVO — invalida qualunque ciclo precedente ancora in volo
    if (_timer != null) return;
    SyncTrigger.instance.register(runOnce);
    unawaited(runOnce());
    _timer = Timer.periodic(_interval, (_) => runOnce());
  }

  void stop() {
    _epoch++; // NUOVO — invalida il ciclo corrente, se ce n'è uno in corso
    _timer?.cancel();
    _timer = null;
    SyncTrigger.instance.unregister();
    phase = SyncPhase.idle;
    notifyListeners();
  }

  Future<void> runOnce() async {
    if (_running) return;
    final myEpoch = _epoch; // NUOVO — "firma" di questo ciclo
    _running = true;
    try {
      phase = SyncPhase.uploading;
      notifyListeners();
      await _uploadAll(myEpoch); // NUOVO — passa l'epoca
      if (myEpoch != _epoch) return; // NUOVO — superato: interrompi
      phase = SyncPhase.downloading;
      notifyListeners();
      await BackendImportRepository().importAllFromBackend();
      if (myEpoch != _epoch) return; // NUOVO
      lastSuccessAt = DateTime.now();
      lastError = null;
      consecutiveFailures = 0;
      phase = SyncPhase.idle;
      onSynced?.call();
    } catch (e) {
      if (myEpoch != _epoch) return; // NUOVO — errore di un ciclo ormai morto: ignora
      lastError = e.toString();
      consecutiveFailures++;
      phase = SyncPhase.error;
      debugPrint('[SyncEngine] ciclo fallito: $e');
    } finally {
      if (myEpoch == _epoch) _running = false; // NUOVO — solo il ciclo "vivo" resetta il flag
      notifyListeners();
    }
  }

  // MODIFICATO — controlla l'epoca tra ogni sotto-fase, per fermarsi
  // il prima possibile invece di completare comunque tutte le 6
  // categorie anche se nel frattempo l'account è cambiato.
  Future<void> _uploadAll(int myEpoch) async {
    await ExerciseSyncRepository().syncLocalLibraryToBackend();
    if (myEpoch != _epoch) return;
    await WorkoutSyncRepository().syncLocalWorkoutsToBackend();
    if (myEpoch != _epoch) return;
    await SessionSyncRepository().syncLocalHistoryToBackend();
    if (myEpoch != _epoch) return;
    await TrainingModeSyncRepository().syncLocalModesToBackend();
    if (myEpoch != _epoch) return;
    await GoalSyncRepository().syncLocalGoalsToBackend();
    if (myEpoch != _epoch) return;
    await SportSessionSyncRepository().syncLocalSportSessionsToBackend();
  }
}

void unawaited(Future<void> future) {}