import 'package:flutter/material.dart';
import '../repositories/backend_import_repository.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/auth_dto.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/cloud_auth_bridge.dart';

enum BackendAuthStatus { unknown, authenticated, unauthenticated }

/// Provider dedicato alla sessione verso il backend NestJS.
/// Separato da AuthProvider (autenticazione locale V1).
///
/// NUOVO — nel costruttore si registra su CloudAuthBridge come unico
/// punto che collega il login V1 (che l'utente vede e usa) al backend
/// cloud (che l'utente non vede mai direttamente). Due ruoli:
///  1. syncFromV1Login: dopo ogni login/registrazione V1 riuscito su
///     QUESTO dispositivo, allinea la sessione backend in background
///     (login, o registrazione se è la prima volta). Fire-and-forget.
///  2. verifyRemoteCredentials: quando AuthProvider trova un
///     identifier sconosciuto localmente (dispositivo nuovo), prova
///     login diretto sul backend con quelle credenziali. Se il
///     backend le riconosce, autentica, scarica subito tutti i dati
///     dell'utente (schede, esercizi, storico, obiettivi) e fa
///     partire SyncEngine — TUTTO PRIMA che AuthProvider consideri il
///     login riuscito, così l'utente vede i propri dati appena entra.
class BackendAuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;
  final BackendImportRepository _importRepo;

  BackendAuthProvider({
    AuthApiService? authApi,
    BackendImportRepository? importRepo,
  })  : _authApi = authApi ?? AuthApiService(),
        _importRepo = importRepo ?? BackendImportRepository() {
    // NUOVO — collegamento con l'unico login che l'utente usa (V1).
    CloudAuthBridge.instance.register(syncFromV1Login);
    CloudAuthBridge.instance.registerVerifier(verifyRemoteCredentials);
  }

  BackendAuthStatus _status = BackendAuthStatus.unknown;
  BackendUserProfile? _currentUser;
  String? _lastError;
  bool _loading = false;

  bool _autoImportDone = false;
  bool autoImporting = false;
  ImportSummary? lastAutoImportSummary;
  String? lastAutoImportError;

  BackendAuthStatus get status => _status;
  BackendUserProfile? get currentUser => _currentUser;
  String? get lastError => _lastError;
  bool get loading => _loading;
  bool get isAuthenticated => _status == BackendAuthStatus.authenticated;

  // Usato da cloud_sync_screen.dart (strumento di debug/admin) per
  // mostrare lo stato live del motore di sincronizzazione.
  SyncEngine get syncEngine => SyncEngine.instance;

  Future<void> restoreSession() async {
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

  /// NUOVO — chiamato da CloudAuthBridge subito dopo ogni
  /// login/registrazione V1 riuscito su questo dispositivo (identità
  /// già nota localmente). Effettua login sul backend con le stesse
  /// credenziali; se l'account non esiste ancora lato backend, lo
  /// registra automaticamente. Fire-and-forget rispetto al login V1:
  /// un fallimento qui non blocca né invalida il login locale.
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

  /// NUOVO — chiamato da AuthProvider.login() quando l'identifier NON
  /// è tra gli account locali di questo dispositivo (primo accesso su
  /// un dispositivo nuovo). Prova login diretto sul backend con le
  /// credenziali fornite. Se valide: autentica, ATTENDE il download
  /// completo dei dati esistenti (schede, esercizi, storico,
  /// obiettivi) prima di ritornare true, così quando AuthProvider
  /// mostra la Home i dati sono già lì. Ritorna false per qualunque
  /// fallimento (credenziali errate, account inesistente, rete),
  /// senza distinguerli — AuthProvider mostra un messaggio generico.
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
}

void unawaited(Future<void> future) {}