import 'package:flutter/foundation.dart';
import '../api/dto/auth_dto.dart';

class CloudAuthBridge {
  CloudAuthBridge._internal();
  static final CloudAuthBridge instance = CloudAuthBridge._internal();

  Future<void> Function(String identifier, String password)? _handler;
  Future<bool> Function(String identifier, String password)? _verifyHandler;
  Future<void> Function()? _logoutHandler;
  Future<void> Function(Map<String, String?> fields)? _profileUpdateHandler;
  Future<void> Function(BackendUserProfile profile)? _profileDownloadedHandler;
  Future<Map<String, String?>> Function()? _localProfileProvider;

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
  }

  void registerLogoutHandler(Future<void> Function() handler) {
    _logoutHandler = handler;
    debugPrint('[CLOUD_BRIDGE] logout handler registrato');
  }

  void unregisterLogoutHandler() {
    _logoutHandler = null;
  }

  void registerProfileUpdateHandler(
      Future<void> Function(Map<String, String?> fields) handler) {
    _profileUpdateHandler = handler;
    debugPrint('[CLOUD_BRIDGE] profile update handler registrato');
  }

  void unregisterProfileUpdateHandler() {
    _profileUpdateHandler = null;
  }

  Future<void> notifyProfileUpdated(Map<String, String?> fields) async {
    final handler = _profileUpdateHandler;
    if (handler == null) {
      debugPrint('[CLOUD_BRIDGE] notifyProfileUpdated SALTATO — nessun handler registrato');
      return;
    }
    try {
      await handler(fields);
      debugPrint('[CLOUD_BRIDGE] notifyProfileUpdated completato');
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] notifyProfileUpdated ERRORE: $e');
    }
  }

  void registerProfileDownloadedHandler(
      Future<void> Function(BackendUserProfile profile) handler) {
    _profileDownloadedHandler = handler;
    debugPrint('[CLOUD_BRIDGE] profile downloaded handler registrato');
  }

  void unregisterProfileDownloadedHandler() {
    _profileDownloadedHandler = null;
  }

  Future<void> notifyProfileDownloaded(BackendUserProfile profile) async {
    final handler = _profileDownloadedHandler;
    if (handler == null) return;
    try {
      await handler(profile);
      debugPrint('[CLOUD_BRIDGE] notifyProfileDownloaded completato');
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] notifyProfileDownloaded ERRORE: $e');
    }
  }

  // RIPRISTINATO — snapshot del profilo locale, usato dal backfill
  // in BackendAuthProvider._backfillLocalProfileIfNeeded().
  void registerLocalProfileProvider(
      Future<Map<String, String?>> Function() provider) {
    _localProfileProvider = provider;
  }

  void unregisterLocalProfileProvider() {
    _localProfileProvider = null;
  }

  Future<Map<String, String?>> getLocalProfile() async {
    final provider = _localProfileProvider;
    if (provider == null) return {};
    try {
      return await provider();
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] getLocalProfile ERRORE: $e');
      return {};
    }
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

  // Canale multi-listener: ogni Provider si registra per ricaricare
  // i propri dati dopo un cambio account (switchUser chiude/riapre
  // tutti i box Hive, ma i Provider mantengono liste in memoria).
  final List<void Function()> _accountSwitchedListeners = [];

  void addAccountSwitchedListener(void Function() listener) {
    _accountSwitchedListeners.add(listener);
  }

  void notifyAccountSwitched() {
    debugPrint('[CLOUD_BRIDGE] notifyAccountSwitched: '
        '${_accountSwitchedListeners.length} listener da avvisare');
    for (final listener in List<void Function()>.from(_accountSwitchedListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[CLOUD_BRIDGE] accountSwitched listener ERRORE: $e');
      }
    }
  }
}