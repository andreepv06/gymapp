import 'package:flutter/material.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/auth_dto.dart';

enum BackendAuthStatus { unknown, authenticated, unauthenticated }

/// Provider dedicato alla sessione verso il NUOVO backend NestJS.
///
/// Completamente separato da AuthProvider (autenticazione locale V1,
/// Hive/SharedPreferences 'accounts'): questo provider non tocca in
/// alcun modo lo stato o i dati di AuthProvider. È pensato per essere
/// usato in aggiunta, non in sostituzione, finché la migrazione non
/// sarà verificata (Fase 4).
class BackendAuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;

  BackendAuthProvider({AuthApiService? authApi})
      : _authApi = authApi ?? AuthApiService();

  BackendAuthStatus _status = BackendAuthStatus.unknown;
  BackendUserProfile? _currentUser;
  String? _lastError;
  bool _loading = false;

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
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _status = BackendAuthStatus.unauthenticated;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    await _authApi.logout();
    _currentUser = null;
    _status = BackendAuthStatus.unauthenticated;
    _loading = false;
    notifyListeners();
  }
}