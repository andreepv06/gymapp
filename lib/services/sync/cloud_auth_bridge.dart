import 'package:flutter/foundation.dart';

/// Ponte fra l'autenticazione locale V1 (AuthProvider) e il backend
/// cloud (BackendAuthProvider). Serve a rendere invisibile all'utente
/// l'esistenza di un secondo sistema di autenticazione: un SOLO
/// login/registrazione (schermata V1); questo bridge tiene allineata
/// l'identità sul backend in background.
///
/// Due canali distinti:
///  - syncIdentity/register: notifica "fire-and-forget" dopo un
///    login/registrazione V1 riuscito, per fare login (o
///    registrazione, se è la prima volta) sul backend in background.
///    Non blocca né può far fallire il login V1 locale.
///  - verifyRemoteAccount/registerVerifier — NUOVO: verifica che
///    AuthProvider ATTENDE, usata quando l'utente prova un login V1
///    su un dispositivo che non conosce ancora quell'account
///    localmente (tipicamente un secondo dispositivo). Se il backend
///    riconosce le credenziali, il login V1 può procedere e i dati
///    vengono scaricati subito, prima di mostrare la Home.
class CloudAuthBridge {
  CloudAuthBridge._internal();
  static final CloudAuthBridge instance = CloudAuthBridge._internal();

  Future<void> Function(String identifier, String password)? _handler;
  Future<bool> Function(String identifier, String password)? _verifyHandler;

  void register(Future<void> Function(String identifier, String password) handler) {
    _handler = handler;
    debugPrint('[CLOUD_BRIDGE] handler registrato');
  }

  void unregister() {
    _handler = null;
    debugPrint('[CLOUD_BRIDGE] handler deregistrato');
  }

  /// NUOVO
  void registerVerifier(
      Future<bool> Function(String identifier, String password) handler) {
    _verifyHandler = handler;
    debugPrint('[CLOUD_BRIDGE] verifier registrato');
  }

  /// NUOVO
  void unregisterVerifier() {
    _verifyHandler = null;
    debugPrint('[CLOUD_BRIDGE] verifier deregistrato');
  }

  Future<void> syncIdentity(String identifier, String password) async {
    final handler = _handler;
    if (handler == null) {
      debugPrint('[CLOUD_BRIDGE] syncIdentity($identifier) SALTATO — nessun handler registrato');
      return;
    }
    debugPrint('[CLOUD_BRIDGE] syncIdentity($identifier) avviato');
    try {
      await handler(identifier, password);
      debugPrint('[CLOUD_BRIDGE] syncIdentity($identifier) completato');
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] syncIdentity($identifier) ERRORE: $e');
    }
  }

  /// NUOVO — usato da AuthProvider.login() quando l'account non
  /// esiste ancora localmente su questo dispositivo: verifica se
  /// esiste già sul backend con queste credenziali (registrato da un
  /// altro dispositivo). Ritorna false anche in caso di errore di
  /// rete — mai un'eccezione propagata al chiamante.
  Future<bool> verifyRemoteAccount(String identifier, String password) async {
    final handler = _verifyHandler;
    if (handler == null) {
      debugPrint('[CLOUD_BRIDGE] verifyRemoteAccount($identifier) SALTATO — nessun verifier registrato');
      return false;
    }
    try {
      final ok = await handler(identifier, password);
      debugPrint('[CLOUD_BRIDGE] verifyRemoteAccount($identifier) = $ok');
      return ok;
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] verifyRemoteAccount($identifier) ERRORE: $e');
      return false;
    }
  }
}