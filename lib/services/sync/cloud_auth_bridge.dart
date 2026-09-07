import 'package:flutter/foundation.dart';

class CloudAuthBridge {
  CloudAuthBridge._internal();
  static final CloudAuthBridge instance = CloudAuthBridge._internal();

  Future<void> Function(String identifier, String password)? _handler;
  Future<bool> Function(String identifier, String password)? _verifyHandler;
  Future<void> Function()? _logoutHandler;

  void register(Future<void> Function(String identifier, String password) handler) {
    _handler = handler;
    debugPrint('[CLOUD_BRIDGE] handler registrato');
  }

  void unregister() {
    _handler = null;
    debugPrint('[CLOUD_BRIDGE] handler deregistrato');
  }

  void registerVerifier(
      Future<bool> Function(String identifier, String password) handler) {
    _verifyHandler = handler;
    debugPrint('[CLOUD_BRIDGE] verifier registrato');
  }

  void unregisterVerifier() {
    _verifyHandler = null;
    debugPrint('[CLOUD_BRIDGE] verifier deregistrato');
  }

  // NUOVO
  void registerLogoutHandler(Future<void> Function() handler) {
    _logoutHandler = handler;
    debugPrint('[CLOUD_BRIDGE] logout handler registrato');
  }

  void unregisterLogoutHandler() {
    _logoutHandler = null;
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

  // NUOVO — chiamato da AuthProvider.logout(): chiude anche la
  // sessione backend (token + SyncEngine). Senza questo, un logout
  // V1 lasciava il token backend ancora valido in storage, riusato
  // per errore al prossimo avvio (restoreSession) con un'identità
  // non corrispondente al nuovo account V1 — causa della
  // cross-contaminazione osservata sul dispositivo di test.
  Future<void> notifyLogout() async {
    final handler = _logoutHandler;
    if (handler == null) return;
    try {
      await handler();
      debugPrint('[CLOUD_BRIDGE] notifyLogout completato');
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] notifyLogout ERRORE: $e');
    }
  }
}