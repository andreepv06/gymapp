import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'token_storage.dart';

/// Client HTTP condiviso verso il backend NestJS MarkFit.
///
/// Base URL configurabile: in sviluppo locale punta di default a
/// http://localhost:3000/api (backend avviato con `npm run start:dev`).
/// Sovrascrivibile a runtime (vedi CloudSyncScreen) per test contro
/// un backend distribuito, senza dover ricompilare l'app — utile in
/// vista della Fase 4 (deploy) quando l'URL cambierà da locale a
/// pubblico.
///
/// Gestisce automaticamente:
///  - header Authorization con l'access token salvato;
///  - un singolo tentativo di refresh trasparente su 401 (il
///    chiamante non deve gestirlo, a meno che il refresh stesso
///    fallisca, nel qual caso propaga comunque un 401 — la UI deve
///    reindirizzare al login);
///  - mappatura di ogni errore HTTP/di rete in ApiException.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  static const _defaultBaseUrl = 'http://localhost:3000/api';
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
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (e) {
      debugPrint('[ApiClient] network error: $e');
      throw ApiException.network();
    }

    // Refresh trasparente: un solo tentativo per evitare loop.
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
          .timeout(const Duration(seconds: 15));
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