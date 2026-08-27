import '../db/sport_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/sport_sessions_api_service.dart';

class SportSessionSyncResult {
  final int created;
  final int failed;
  const SportSessionSyncResult({required this.created, required this.failed});
  bool get hasFailures => failed > 0;
}

/// Sincronizza le sessioni sportive locali (Hive: corsa, ciclismo,
/// ecc.) verso il backend. Solo lettura da Hive, mai scrittura locale.
///
/// LIMITAZIONE NOTA: nessuna deduplicazione — ogni esecuzione crea
/// nuove sessioni sul backend (Step 12).
class SportSessionSyncRepository {
  final SportSessionsApiService _api;
  SportSessionSyncRepository({SportSessionsApiService? api})
      : _api = api ?? SportSessionsApiService();

  Future<SportSessionSyncResult> syncLocalSportSessionsToBackend() async {
    final localSessions = SportDatabase.instance.getSessions();

    int created = 0;
    int failed = 0;

    for (final session in localSessions) {
      try {
        final isoDate = DateTime.parse(session.date).toIso8601String();
        await _api.create(
          sportType: session.sportType,
          isoDate: isoDate,
          durationSeconds: session.durationSeconds,
          distanceKm: session.distanceKm,
          notes: session.notes,
        );
        created++;
      } catch (_) {
        // Copre sia ApiException sia un eventuale errore di parsing
        // data (es. formato non ISO): entrambi contano come
        // fallimento di quella singola sessione, senza bloccare le
        // altre.
        failed++;
      }
    }

    return SportSessionSyncResult(created: created, failed: failed);
  }
}