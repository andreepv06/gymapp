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
    // NUOVO (fix audit sincronizzazione) — canale AuthProvider →
    // questo provider per la propagazione delle modifiche al profilo.
    CloudAuthBridge.instance.registerProfileUpdateHandler(_handleProfileUpdate);
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

  Future<void>? _restoreSessionFuture;

  BackendAuthStatus get status => _status;
  BackendUserProfile? get currentUser => _currentUser;
  String? get lastError => _lastError;
  bool get loading => _loading;
  bool get isAuthenticated => _status == BackendAuthStatus.authenticated;
  SyncEngine get syncEngine => SyncEngine.instance;

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
      // NUOVO (fix audit sincronizzazione) — applica subito il
      // profilo scaricato all'account locale, prima ancora che parta
      // il resto dell'import. Fire-and-forget: non deve mai bloccare
      // l'avvio dell'app (coerente col fix di lentezza già applicato
      // a questo stesso flusso in un turno precedente).
      unawaited(CloudAuthBridge.instance.notifyProfileDownloaded(_currentUser!));
      unawaited(_backfillLocalProfileIfNeeded(_currentUser!));
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
      // NUOVO — vedi commento in _doRestoreSession.
      unawaited(CloudAuthBridge.instance.notifyProfileDownloaded(_currentUser!));
      unawaited(_backfillLocalProfileIfNeeded(_currentUser!));
      unawaited(_triggerAutoImport());
      SyncEngine.instance.start();
    } catch (e) {
      debugPrint('[BackendAuthProvider] fetchCurrentUser dopo syncFromV1Login fallito: $e');
    }
  }

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
      // NUOVO — questo è IL caso critico per l'audit: primo login
      // su un secondo dispositivo. Il profilo scaricato qui viene
      // applicato PRIMA di await _triggerAutoImport(), quindi è già
      // presente in locale nel momento in cui AuthProvider considera
      // il login riuscito e monta la UI.
      await CloudAuthBridge.instance.notifyProfileDownloaded(_currentUser!);
      unawaited(_backfillLocalProfileIfNeeded(_currentUser!));
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
      // NUOVO — vedi commento in _doRestoreSession.
      unawaited(CloudAuthBridge.instance.notifyProfileDownloaded(_currentUser!));
      unawaited(_backfillLocalProfileIfNeeded(_currentUser!));
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

  // NUOVO (fix audit sincronizzazione) — riceve dal canale
  // AuthProvider → questo provider le modifiche al profilo fatte
  // localmente, e le propaga al backend tramite AuthApiService.
  // Guardia: se non c'è una sessione backend attiva, non fa nulla
  // (coerente con l'offline-first — il profilo resta comunque
  // salvato localmente da AuthProvider, la propagazione avverrà al
  // prossimo login/sync). Fallimento silenzioso: un errore di rete
  // qui non deve mai bloccare l'utente, stesso principio già usato
  // per syncFromV1Login.
  Future<void> _handleProfileUpdate(Map<String, String?> fields) async {
    if (_status != BackendAuthStatus.authenticated) return;
    try {
      await _authApi.updateProfile(
        displayName: fields['displayName'],
        firstName: fields['firstName'],
        lastName: fields['lastName'],
        birthDate: fields['birthDate'],
        birthPlace: fields['birthPlace'],
        phone: fields['phone'],
        bio: fields['bio'],
        avatarUrl: fields['avatarBase64'],
      );
    } catch (e) {
      debugPrint('[BackendAuthProvider] _handleProfileUpdate fallito: $e');
    }
  }

  // NUOVO (fix backfill profilo) — dopo aver scaricato il profilo
  // dal backend, confronta con lo snapshot locale: se il backend ha
  // un campo vuoto/nullo che invece il dispositivo corrente ha già
  // valorizzato localmente (tipicamente l'avatar, se era stato
  // impostato prima che l'upload esistesse), lo invia. Non
  // sovrascrive mai un valore già presente sul backend: aggiunge
  // solo ciò che manca.
  Future<void> _backfillLocalProfileIfNeeded(BackendUserProfile remote) async {
    try {
      final local = await CloudAuthBridge.instance.getLocalProfile();
      if (local.isEmpty) return;

      final diff = <String, String?>{};
      void maybeAdd(String key, String? remoteValue) {
        final localValue = local[key];
        if (localValue != null &&
            localValue.isNotEmpty &&
            (remoteValue == null || remoteValue.isEmpty)) {
          diff[key] = localValue;
        }
      }

      maybeAdd('displayName', remote.displayName);
      maybeAdd('firstName', remote.firstName);
      maybeAdd('lastName', remote.lastName);
      maybeAdd('bio', remote.bio);
      maybeAdd('avatarBase64', remote.avatarUrl);

      if (diff.isEmpty) return;

      await _authApi.updateProfile(
        displayName: diff['displayName'],
        firstName: diff['firstName'],
        lastName: diff['lastName'],
        bio: diff['bio'],
        avatarUrl: diff['avatarBase64'],
      );
      debugPrint('[BackendAuthProvider] Backfill profilo eseguito: ${diff.keys}');
    } catch (e) {
      debugPrint('[BackendAuthProvider] Backfill profilo fallito: $e');
    }
  }

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