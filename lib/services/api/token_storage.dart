import 'package:shared_preferences/shared_preferences.dart';

/// Persistenza locale dei token JWT del backend MarkFit.
/// Completamente separata dal sistema di autenticazione locale V1
/// (AuthProvider/SharedPreferences 'accounts'): usa chiavi dedicate,
/// nessuna sovrapposizione o rischio di collisione con i dati V1.
class TokenStorage {
  static const _kAccessKey = 'backend_access_token';
  static const _kRefreshKey = 'backend_refresh_token';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessKey, accessToken);
    await prefs.setString(_kRefreshKey, refreshToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessKey);
    await prefs.remove(_kRefreshKey);
  }

  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }
}