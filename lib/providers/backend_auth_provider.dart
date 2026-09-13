import 'package:flutter/material.dart';
import '../repositories/backend_import_repository.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/auth_dto.dart';
import '../services/api/token_storage.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/cloud_auth_bridge.dart';
enum BackendAuthStatus { unknown, authenticated, unauthenticated }
/// Provider dedicato alla sessione verso il backend NestJS.
/// Separato da AuthProvider (autenticazione locale V1).
///
/// Nel costruttore si registra su CloudAuthBridge come unico punto
/// che collega il login V1 (che l'utente vede e usa) al backend
/// cloud (che l'utente non vede mai direttamente). Due ruoli:
///  1. syncFromV1Login: dopo ogni login/registrazione V1 riuscito su
///     QUESTO dispositivo, allinea la sessione backend in background
///     (login, o registrazione se è la prima volta). Fire-and-forget.
///  2. verifyRemoteCredentials: quando AuthProvider trova un
///     identifier sconosciuto localmente (dispositivo nuovo), prova
///     login diretto sul backend con quelle credenziali.
///
/// Si registra anche su ApiClient.instance.onSessionExpired: quando
/// una richiesta autenticata riceve 401 e il refresh token non
/// riesce a rinnovare la sessione, ApiClient non ha modo di sapere
/// che deve fermare SyncEngine — è compito di questo provider.
class BackendAuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;
  final BackendImportRepository _importRepo;
  BackendAuthProvider({
    AuthApiService? authApi,
    BackendImportRepository? importRepo,
  })  : _authApi = authApi ?? AuthApiService(),
        _importRepo = importRepo ?? BackendImportRepository() {
    CloudAuthBridge.instance.register(syncFromV1Login);
    CloudAuthBridge.instance.registerVerifier(verifyRemoteCredentials);
    CloudAuthBridge.instance.registerLogoutHandler(logout);
    ApiClient.instance.onSessionExpired = _handleSessionExpired;
  }
  BackendAuthStatus _status = BackendAuthStatus.unknown;
  BackendUserProfile? _currentUser;
  String? _lastError;
  bool _loading = false;
  bool _autoImportDone = false;
  bool autoImporting = false;
  ImportSummary? lastAutoImportSummary;
  String? lastAutoImportError;

  // NUOVO (fix provisioning) — cache della Future di restoreSession().
  // La chiamata originale avviene una sola volta all'avvio da
  // main.dart (create: (_) => BackendAuthProvider()..restoreSession(),
  // lazy: false). Con questa cache, AppEntry._checkAuth() può
  // RIATTENDERE la stessa Future una seconda volta — senza scatenare
  // una seconda chiamata di rete — per sapere con CERTEZZA quando il
  // controllo della sessione backend è concluso, prima di decidere se
  // ritentare il provisioning per un utente V1 non ancora sincronizzato.
  Future<void>? _restoreSessionFuture;

  BackendAuthStatus get status => _status;
  BackendUserProfile? get currentUser => _currentUser;
  String? get lastError => _lastError;
  bool get loading => _loading;
  bool get isAuthenticated => _status == BackendAuthStatus.authenticated;
  SyncEngine get syncEngine => SyncEngine.instance;

  // MODIFICATO (fix provisioning) — ora restituisce/cachea la
  // Future interna invece di ricrearla ad ogni chiamata. Il corpo
  // originale del metodo è invariato, spostato in _doRestoreSession().
  Future<void> restoreSession() {
    return _restoreSessionFuture ??= _doRestoreSession();
  }

  Future<void> _doRestoreSession() async {
    _loading = true;
    notifyListeners();
    final hasSession = await _authApi.hasStoredSession();
    if (!hasSession) {
      _status = BackendAuthStatus.unauthenticated;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      _currentUser = await _authApi.fetchCurrentUser();
      _status = BackendAuthStatus.authenticated;
    } catch (_) {
      _status = BackendAuthStatus.unauthenticated;
      _currentUser = null;
    }
    _loading = false;
    notifyListeners();
    if (_status == BackendAuthStatus.authenticated) {
      unawaited(_triggerAutoImport());
      SyncEngine.instance.start();
    }
  }

  /// Chiamato da CloudAuthBridge subito dopo ogni login/registrazione
  /// V1 riuscito su questo dispositivo (identità già nota localmente),
  /// E ORA ANCHE — grazie alla modifica in main.dart — ad ogni
  /// riapertura dell'app quando l'utente risulta già loggato in V1 ma
  /// il backend NON ha una sessione valida salvata (fix del problema
  /// "utente V1 mai comparso nel backend": prima di questa modifica il
  /// meccanismo scattava una volta sola, senza retry).
  /// Effettua login sul backend con le stesse credenziali; se
  /// l'account non esiste ancora lato backend, lo registra
  /// automaticamente. Fire-and-forget rispetto al chiamante: un
  /// fallimento qui non blocca né invalida nulla lato V1.
  Future<void> syncFromV1Login(String identifier, String password) async {
    try {
      await _authApi.login(identifier, password);
    } catch (_) {
      try {
        await _authApi.register(identifier, password);
      } catch (e) {
        debugPrint('[BackendAuthProvider] syncFromV1Login fallito per "$identifier": $e');
        return;
      }
    }
    try {
      _currentUser = await _authApi.fetchCurrentUser();
      _status = BackendAuthStatus.authenticated;
      _autoImportDone = false;
      notifyListeners();
      unawaited(_triggerAutoImport());
      SyncEngine.instance.start();
    } catch (e) {
      debugPrint('[BackendAuthProvider] fetchCurrentUser dopo syncFromV1Login fallito: $e');
    }
  }
  /// Chiamato da AuthProvider.login() quando l'identifier NON è tra
  /// gli account locali di questo dispositivo (primo accesso su un
  /// dispositivo nuovo). Prova login diretto sul backend con le
  /// credenziali fornite. Se valide: autentica, ATTENDE il download
  /// completo dei dati esistenti prima di ritornare true. Ritorna
  /// false per qualunque fallimento, senza distinguerli.
  Future<bool> verifyRemoteCredentials(String identifier, String password) async {
    try {
      await _authApi.login(identifier, password);
    } catch (_) {
      return false;
    }
    try {
      _currentUser = await _authApi.fetchCurrentUser();
      _status = BackendAuthStatus.authenticated;
      _autoImportDone = false;
      notifyListeners();
      await _triggerAutoImport();
      SyncEngine.instance.start();
      return true;
    } catch (e) {
      debugPrint('[BackendAuthProvider] verifyRemoteCredentials fallito: $e');
      return false;
    }
  }
  Future<bool> register(String identifier, String password) =>
      _runAuthFlow(() => _authApi.register(identifier, password));
  Future<bool> login(String identifier, String password) =>
      _runAuthFlow(() => _authApi.login(identifier, password));
  Future<bool> _runAuthFlow(Future<AuthTokens> Function() action) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await action();
      _currentUser = await _authApi.fetchCurrentUser();
      _status = BackendAuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      unawaited(_triggerAutoImport());
      SyncEngine.instance.start();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _status = BackendAuthStatus.unauthenticated;
      _loading = false;
      notifyListeners();
      return false;
    }
  }
  Future<void> _triggerAutoImport() async {
    if (_autoImportDone || autoImporting) return;
    autoImporting = true;
    notifyListeners();
    try {
      lastAutoImportSummary = await _importRepo.importAllFromBackend();
      lastAutoImportError = null;
      _autoImportDone = true;
    } catch (e) {
      lastAutoImportError = e.toString();
    } finally {
      autoImporting = false;
      notifyListeners();
    }
  }
  Future<void> refreshFromBackend() async {
    _autoImportDone = false;
    await _triggerAutoImport();
  }
  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    await _authApi.logout();
    _currentUser = null;
    _status = BackendAuthStatus.unauthenticated;
    _autoImportDone = false;
    lastAutoImportSummary = null;
    lastAutoImportError = null;
    SyncEngine.instance.stop();
    _loading = false;
    notifyListeners();
  }
  /// OPZIONE B. Chiamato da ApiClient quando una richiesta autenticata
  /// riceve 401 e il tentativo di refresh del token NON riesce a
  /// rinnovare la sessione. Invalida SOLO lo stato di autenticazione
  /// backend, mai la sessione locale V1.
  Future<void> _handleSessionExpired() async {
    if (_status == BackendAuthStatus.unauthenticated) return;
    debugPrint(
        '[BackendAuthProvider] Sessione backend scaduta: arresto SyncEngine e invalidazione sessione backend (sessione locale V1 non toccata).');
    SyncEngine.instance.stop();
    await TokenStorage().clear();
    _currentUser = null;
    _status = BackendAuthStatus.unauthenticated;
    _autoImportDone = false;
    lastAutoImportSummary = null;
    lastAutoImportError = null;
    notifyListeners();
  }
}
void unawaited(Future<void> future) {}