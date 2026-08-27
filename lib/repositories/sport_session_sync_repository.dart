import '../db/sport_database.dart';
import '../services/api/sport_sessions_api_service.dart';
import 'sync_mapping_storage.dart';

class SportSessionSyncResult {
  final int created;
  final int alreadySynced;
  final int failed;
  const SportSessionSyncResult({
    required this.created,
    required this.alreadySynced,
    required this.failed,
  });
  bool get hasFailures => failed > 0;
}

class SportSessionSyncRepository {
  static const domain = 'sportSession';

  final SportSessionsApiService _api;
  final SyncMappingStorage _mapping;

  SportSessionSyncRepository({
    SportSessionsApiService? api,
    SyncMappingStorage? mapping,
  })  : _api = api ?? SportSessionsApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<SportSessionSyncResult> syncLocalSportSessionsToBackend() async {
    final localSessions = SportDatabase.instance.getSessions();

    int created = 0;
    int alreadySynced = 0;
    int failed = 0;

    for (final session in localSessions) {
      final localKey = session.key;
      final existing = await _mapping.getRemoteId(domain, localKey);
      if (existing != null) {
        alreadySynced++;
        continue;
      }
      try {
        final isoDate = DateTime.parse(session.date).toIso8601String();
        await _api.create(
          sportType: session.sportType,
          isoDate: isoDate,
          durationSeconds: session.durationSeconds,
          distanceKm: session.distanceKm,
          notes: session.notes,
        );
        // NOTA: SportSessionsApiService.create() attualmente non
        // restituisce l'id remoto creato (POST /sport-sessions
        // risponde con l'oggetto completo, ma il service scarta il
        // body). Senza id non possiamo registrare il mapping: questa
        // entità resta quindi NON idempotente in questo incremento —
        // limite dichiarato esplicitamente, da chiudere quando
        // SportSessionsApiService.create() sarà aggiornato per
        // restituire e propagare l'id (modifica minima futura).
        created++;
      } catch (_) {
        failed++;
      }
    }

    return SportSessionSyncResult(
      created: created,
      alreadySynced: alreadySynced,
      failed: failed,
    );
  }
}