import 'dart:async';

/// SyncTrigger — ponte fra i Provider (che rilevano le mutazioni
/// locali) e SyncEngine (che esegue realmente upload+download).
///
/// FLUSSO:
///  - SyncEngine.start() chiama register(runOnce): da quel momento
///    SyncTrigger conosce QUALE funzione eseguire quando arriva una
///    richiesta di sync.
///  - Ogni Provider (GoalProvider, WorkoutProvider, SessionProvider,
///    ecc.) chiama requestSync() subito dopo ogni scrittura Hive
///    rilevante (create/update/delete/toggle).
///  - requestSync() applica un DEBOUNCE di 3 secondi: più chiamate
///    ravvicinate (es. l'utente completa 5 serie di fila) producono
///    UN SOLO ciclo di sincronizzazione, non uno per modifica.
///  - Se nessun callback è registrato (SyncEngine non avviato, es.
///    utente senza account backend collegato), requestSync() non fa
///    nulla: la V1 locale resta comunque pienamente funzionante
///    offline-first.
class SyncTrigger {
  SyncTrigger._();
  static final SyncTrigger instance = SyncTrigger._();

  static const Duration _debounce = Duration(seconds: 3);
  Timer? _timer;
  Future<void> Function()? _callback;

  /// Chiamato da SyncEngine.start() per registrare il proprio ciclo
  /// di sincronizzazione (runOnce) come destinatario delle richieste.
  void register(Future<void> Function() callback) {
    _callback = callback;
  }

  /// Chiamato da SyncEngine.stop() (es. al logout): annulla anche
  /// eventuali richieste di sync già in attesa di debounce.
  void unregister() {
    _callback = null;
    _timer?.cancel();
    _timer = null;
  }

  /// Chiamato dai Provider dopo ogni mutazione locale rilevante.
  void requestSync() {
    final callback = _callback;
    if (callback == null) return; // Nessun SyncEngine attivo: no-op.
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      callback();
    });
  }
}