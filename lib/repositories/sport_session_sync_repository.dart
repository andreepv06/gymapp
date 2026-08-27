import '../db/sport_database.dart';
import '../services/api/api_exception.dart';
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

/// Sincronizza le sessioni sportive locali (Hive) verso il backend,
/// idempotente tramite mapping persistito. Solo lettura da Hive,
/// mai scrittura locale.
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
        final remote = await _api.create(
          sportType: session.sportType,
          isoDate: isoDate,
          durationSeconds: session.durationSeconds,
          distanceKm: session.distanceKm,
          notes: session.notes,
        );
        await _mapping.setRemoteId(domain, localKey, remote.id);
        created++;
      } on ApiException {
        failed++;
      } catch (_) {
        // Copre errori di parsing data non ISO: conta come
        // fallimento di quella singola sessione, senza bloccare le altre.
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