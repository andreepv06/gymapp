import 'api_client.dart';
import 'token_storage.dart';
import 'dto/auth_dto.dart';

/// Chiamate REST verso /auth e /users/me del backend MarkFit.
/// Nessuna logica di stato qui: la gestione dello stato applicativo
/// (utente corrente, notifyListeners) è responsabilità esclusiva di
/// BackendAuthProvider — questo service è puro I/O.
class AuthApiService {
  final ApiClient _client;
  final TokenStorage _tokens;

  AuthApiService({ApiClient? client, TokenStorage? tokenStorage})
      : _client = client ?? ApiClient.instance,
        _tokens = tokenStorage ?? TokenStorage();

  Future<AuthTokens> register(String identifier, String password) async {
    final json = await _client.post(
      '/auth/register',
      body: {'identifier': identifier, 'password': password},
      auth: false,
    );
    final tokens = AuthTokens.fromJson(json);
    await _tokens.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens;
  }

  Future<AuthTokens> login(String identifier, String password) async {
    final json = await _client.post(
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
      auth: false,
    );
    final tokens = AuthTokens.fromJson(json);
    await _tokens.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens;
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _client.post(
          '/auth/logout',
          body: {'refreshToken': refreshToken},
          auth: false,
        );
      } catch (_) {
        // Logout lato server è best-effort: anche se fallisce (es.
        // server irraggiungibile), i token locali vengono comunque
        // cancellati dal chiamante — l'utente deve poter sempre
        // "uscire" localmente.
      }
    }
    await _tokens.clear();
  }

  Future<BackendUserProfile> fetchCurrentUser() async {
    final json = await _client.get('/users/me');
    return BackendUserProfile.fromJson(json);
  }

  Future<bool> hasStoredSession() => _tokens.hasTokens();
}