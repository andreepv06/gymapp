import 'package:flutter/foundation.dart';
import '../db/training_mode_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/training_mode_dto.dart';
import '../services/api/training_modes_api_service.dart';
import 'sync_mapping_storage.dart';

class TrainingModeSyncResult {
  final int created;
  final int alreadySynced;
  final int failed;
  const TrainingModeSyncResult({
    required this.created,
    required this.alreadySynced,
    required this.failed,
  });
  bool get hasFailures => failed > 0;
}

/// AGGIORNATO (fix root cause blocco sync) — cattura generica per
/// singola modalità: stesso principio delle altre repository.
class TrainingModeSyncRepository {
  static const domain = 'trainingMode';

  final TrainingModesApiService _api;
  final SyncMappingStorage _mapping;

  TrainingModeSyncRepository({
    TrainingModesApiService? api,
    SyncMappingStorage? mapping,
  })  : _api = api ?? TrainingModesApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  String _signature(String name, String category) =>
      '${name.trim().toLowerCase()}|${category.trim().toLowerCase()}';

  Future<TrainingModeSyncResult> syncLocalModesToBackend() async {
    final localModes = TrainingModeDatabase.instance.getAvailable();

    final remoteModes = await _api.fetchAll();
    final remoteBySignature = {
      for (final m in remoteModes) _signature(m.name, m.category): m.id,
    };

    int created = 0;
    int alreadySynced = 0;
    int failed = 0;
    String? defaultRemoteId;

    for (final mode in localModes) {
      final localKey = mode.key;

      final mapped = await _mapping.getRemoteId(domain, localKey);
      if (mapped != null) {
        alreadySynced++;
        if (mode.isDefault) defaultRemoteId = mapped;
        continue;
      }

      final signature = _signature(mode.name, mode.category);
      final existingRemoteId = remoteBySignature[signature];
      if (existingRemoteId != null) {
        await _mapping.setRemoteId(domain, localKey, existingRemoteId);
        alreadySynced++;
        if (mode.isDefault) defaultRemoteId = existingRemoteId;
        continue;
      }

      try {
        final remoteSets = mode.orderedSets
            .map((s) => RemoteTrainingModeSet(
                  order: s.order,
                  fixedReps: s.fixedReps,
                  minReps: s.minReps,
                  maxReps: s.maxReps,
                ))
            .toList();

        final remote = await _api.create(
          name: mode.name,
          category: mode.category,
          sets: remoteSets,
        );
        await _mapping.setRemoteId(domain, localKey, remote.id);
        remoteBySignature[signature] = remote.id;
        created++;
        if (mode.isDefault) defaultRemoteId = remote.id;
      } on ApiException {
        failed++;
      } catch (e) {
        // NUOVO — cattura generica: una modalità problematica non
        // blocca le successive.
        debugPrint('[TrainingModeSyncRepository] Modalità "${mode.name}" '
            'fallita con errore non-API: $e');
        failed++;
      }
    }

    if (defaultRemoteId != null) {
      try {
        await _api.setDefault(defaultRemoteId);
      } catch (_) {
        // Non bloccante, nessun impatto sul resto del ciclo.
      }
    }

    return TrainingModeSyncResult(
      created: created,
      alreadySynced: alreadySynced,
      failed: failed,
    );
  }
}