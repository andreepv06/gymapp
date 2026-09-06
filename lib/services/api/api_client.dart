import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'token_storage.dart';

/// Client HTTP condiviso verso il backend NestJS MarkFit.
///
/// Timeout esteso a 60s (invece dei 15s iniziali): il piano free di
/// Render "addormenta" il servizio dopo inattività e può impiegare
/// fino a ~50s per risvegliarsi alla prima richiesta — un timeout
/// più corto interpretava il cold start come un errore di rete.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  // MODIFICATO — il default deve puntare al backend reale in
  // produzione (Render), non a localhost. Prima di questa modifica
  // ogni dispositivo che non avesse MAI aperto manualmente
  // "Sincronizzazione cloud" e impostato l'URL a mano parlava con
  // localhost:3000, che su un dispositivo diverso dal PC di sviluppo
  // non esiste mai (ERR_CONNECTION_REFUSED) — causa reale del
  // fallimento di login/registrazione/sync su un secondo dispositivo.
  static const _defaultBaseUrl = 'https://gymapp-i09h.onrender.com/api';
  static const _requestTimeout = Duration(seconds: 60);

  String _baseUrl = _defaultBaseUrl;
  final TokenStorage _tokens = TokenStorage();

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) =>
      _send('GET', path, auth: auth);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      _send('POST', path, body: body, auth: auth);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      _send('PUT', path, body: body, auth: auth);

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) =>
      _send('DELETE', path, auth: auth);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool auth,
    bool isRetry = false,
  }) async {
    http.Response response;
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (auth) {
        final token = await _tokens.getAccessToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
      final uri = _uri(path);
      final encodedBody = body != null ? jsonEncode(body) : null;
      response = await _dispatch(method, uri, headers, encodedBody)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (e) {
      debugPrint('[ApiClient] network error: $e');
      throw ApiException.network();
    }

    if (response.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, body: body, auth: auth, isRetry: true);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    String? serverMessage;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        serverMessage = decoded['message'] is List
            ? (decoded['message'] as List).join(', ')
            : decoded['message'].toString();
      }
    } catch (_) {}

    throw ApiException.fromStatus(response.statusCode, serverMessage);
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: body);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: body);
      case 'PUT':
        return http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        throw ApiException.network();
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _tokens.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        await _tokens.clear();
        return false;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      await _tokens.save(
        accessToken: decoded['accessToken'] as String,
        refreshToken: decoded['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}