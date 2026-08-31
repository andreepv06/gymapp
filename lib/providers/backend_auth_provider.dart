import 'package:flutter/material.dart';
import '../repositories/backend_import_repository.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/auth_dto.dart';

enum BackendAuthStatus { unknown, authenticated, unauthenticated }

/// Provider dedicato alla sessione verso il backend NestJS.
/// Separato da AuthProvider (autenticazione locale V1).
///
/// FIX: import automatico dei dati dal backend ad ogni:
///  - avvio dell'app con una sessione backend già valida
///    (restoreSession, chiamato eagerly da main.dart);
///  - login/registrazione riusciti.
/// Nessun passaggio manuale richiesto per vedere su un nuovo
/// dispositivo i dati già sincronizzati da un altro. L'import resta
/// comunque additivo e non distruttivo (BackendImportRepository):
/// nessun dato Hive esistente viene mai sovrascritto o eliminato.
class BackendAuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;
  final BackendImportRepository _importRepo;

  BackendAuthProvider({
    AuthApiService? authApi,
    BackendImportRepository? importRepo,
  })  : _authApi = authApi ?? AuthApiService(),
        _importRepo = importRepo ?? BackendImportRepository();

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
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _status = BackendAuthStatus.unauthenticated;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Import automatico, silenzioso, guardato contro esecuzioni
  /// concorrenti/ripetute nella stessa sessione app.
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

  /// Forza un nuovo import anche se già eseguito in questa sessione
  /// (es. pulsante "Aggiorna ora" nella UI, dopo che un altro
  /// dispositivo ha sincronizzato nuovi dati).
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
    _loading = false;
    notifyListeners();
  }
}

void unawaited(Future<void> future) {}