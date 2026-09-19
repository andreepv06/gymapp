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

  // NUOVO (fix audit sincronizzazione) — mancava completamente:
  // AuthProvider.updateProfile() scriveva SOLO in locale, nessuna
  // chiamata di rete esisteva in nessun punto del codice. Backend
  // endpoint già esistente e funzionante (PATCH /users/me →
  // UsersService.updateProfile), semplicemente mai chiamato dal
  // frontend. Ogni parametro è opzionale: si invia solo ciò che è
  // effettivamente cambiato (update parziale, coerente con la
  // semantica di UpdateProfileDto lato backend).
  //
  // NOTA — avatarUrl: il backend ha solo un campo stringa libera
  // per l'avatar (nessuna infrastruttura di file storage nello
  // schema attuale). In assenza di modifiche allo schema Prisma
  // (fuori scope per questo fix), vi si scrive direttamente il
  // base64 dell'immagine — funzionale per la sincronizzazione
  // cross-device, ma non ottimale in termini di dimensione payload
  // per immagini grandi. Limite noto e accettato per restare nei
  // vincoli dell'audit ("nessuna modifica allo schema").
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? birthPlace,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (birthDate != null) 'birthDate': birthDate,
      if (birthPlace != null) 'birthPlace': birthPlace,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
    if (body.isEmpty) return;
    await _client.patch('/users/me', body: body);
  }

  Future<bool> hasStoredSession() => _tokens.hasTokens();
}