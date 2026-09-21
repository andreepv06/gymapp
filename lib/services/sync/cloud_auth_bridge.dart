import 'package:flutter/foundation.dart';
import '../api/dto/auth_dto.dart';

class CloudAuthBridge {
  CloudAuthBridge._internal();
  static final CloudAuthBridge instance = CloudAuthBridge._internal();

  Future<void> Function(String identifier, String password)? _handler;
  Future<bool> Function(String identifier, String password)? _verifyHandler;
  Future<void> Function()? _logoutHandler;
  // NUOVO — vedi registerProfileUpdateHandler/registerProfileDownloadedHandler
  Future<void> Function(Map<String, String?> fields)? _profileUpdateHandler;
  Future<void> Function(BackendUserProfile profile)? _profileDownloadedHandler;

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

  // NUOVO (fix audit sincronizzazione) — canale AuthProvider →
  // BackendAuthProvider: "il profilo locale è appena cambiato,
  // propagalo al backend". Stesso pattern register/notify già usato
  // per login/logout, applicato al dominio profilo. `fields` contiene
  // solo le chiavi effettivamente modificate in quella chiamata
  // (update parziale).
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

  // NUOVO (fix audit sincronizzazione) — canale inverso:
  // BackendAuthProvider → AuthProvider: "ho appena scaricato il
  // profilo dal backend (login, restore, o import iniziale su un
  // nuovo dispositivo), applicalo all'account locale corrente".
  // Prima d'ora questo canale non esisteva affatto: anche un profilo
  // correttamente presente sul backend non veniva mai copiato
  // nell'account locale, quindi la foto/i dati profilo non
  // comparivano mai su un secondo dispositivo.
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

  // NUOVO (fix backfill profilo) — canale AuthProvider → chiunque
  // debba conoscere lo stato attuale del profilo locale, usato da
  // BackendAuthProvider per il backfill automatico: se il backend
  // non ha ancora un campo che il dispositivo locale ha invece già
  // popolato (es. un avatar impostato prima che l'upload esistesse),
  // questo canale permette di recuperarlo e inviarlo.
  Future<Map<String, String?>> Function()? _localProfileProvider;

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
      debugPrint('[CLOUD_BRIDGE] syncIdentity($identifier) ERRORE:$e');
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
      debugPrint('[CLOUD_BRIDGE] verifyRemoteAccount($identifier) =$ok');
      return ok;
    } catch (e) {
      debugPrint('[CLOUD_BRIDGE] verifyRemoteAccount($identifier) ERRORE:$e');
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
}