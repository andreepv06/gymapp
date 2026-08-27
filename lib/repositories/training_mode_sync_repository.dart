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

class TrainingModeSyncRepository {
  static const domain = 'trainingMode';

  final TrainingModesApiService _api;
  final SyncMappingStorage _mapping;

  TrainingModeSyncRepository({
    TrainingModesApiService? api,
    SyncMappingStorage? mapping,
  })  : _api = api ?? TrainingModesApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<TrainingModeSyncResult> syncLocalModesToBackend() async {
    final localModes = TrainingModeDatabase.instance.getAvailable();

    int created = 0;
    int alreadySynced = 0;
    int failed = 0;
    String? defaultRemoteId;

    for (final mode in localModes) {
      final localKey = mode.key;
      final existing = await _mapping.getRemoteId(domain, localKey);
      if (existing != null) {
        alreadySynced++;
        if (mode.isDefault) defaultRemoteId = existing;
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
        created++;
        if (mode.isDefault) defaultRemoteId = remote.id;
      } on ApiException {
        failed++;
      }
    }

    if (defaultRemoteId != null) {
      try {
        await _api.setDefault(defaultRemoteId);
      } on ApiException {
        // Non bloccante: le modalità sono comunque state
        // sincronizzate correttamente.
      }
    }

    return TrainingModeSyncResult(
      created: created,
      alreadySynced: alreadySynced,
      failed: failed,
    );
  }
}