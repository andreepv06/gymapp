/// Eccezione unificata per tutte le chiamate al backend MarkFit.
/// Distingue i casi che la UI deve gestire in modo specifico
/// (401 → sessione scaduta, 403 → non autorizzato, 409 → conflitto,
/// offline/timeout → server irraggiungibile) da un generico errore
/// di rete, senza mai mostrare stack trace tecnici all'utente.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final ApiErrorKind kind;

  const ApiException({
    required this.message,
    this.statusCode,
    required this.kind,
  });

  factory ApiException.network() => const ApiException(
        message: 'Impossibile raggiungere il server. Verifica la connessione.',
        kind: ApiErrorKind.network,
      );

  factory ApiException.timeout() => const ApiException(
        message: 'Il server non risponde. Riprova tra qualche istante.',
        kind: ApiErrorKind.timeout,
      );

  factory ApiException.fromStatus(int statusCode, String? serverMessage) {
    switch (statusCode) {
      case 400:
        return ApiException(
          statusCode: 400,
          message: serverMessage ?? 'Richiesta non valida.',
          kind: ApiErrorKind.badRequest,
        );
      case 401:
        return const ApiException(
          statusCode: 401,
          message: 'Sessione scaduta. Effettua di nuovo il login.',
          kind: ApiErrorKind.unauthorized,
        );
      case 403:
        return const ApiException(
          statusCode: 403,
          message: 'Non hai i permessi per questa operazione.',
          kind: ApiErrorKind.forbidden,
        );
      case 404:
        return const ApiException(
          statusCode: 404,
          message: 'Risorsa non trovata.',
          kind: ApiErrorKind.notFound,
        );
      case 409:
        return ApiException(
          statusCode: 409,
          message: serverMessage ?? 'Elemento già esistente.',
          kind: ApiErrorKind.conflict,
        );
      default:
        return ApiException(
          statusCode: statusCode,
          message: serverMessage ?? 'Errore del server ($statusCode).',
          kind: ApiErrorKind.server,
        );
    }
  }

  @override
  String toString() => message;
}

enum ApiErrorKind {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
}