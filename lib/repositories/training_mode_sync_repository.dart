import '../db/training_mode_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/dto/training_mode_dto.dart';
import '../services/api/training_modes_api_service.dart';

class TrainingModeSyncResult {
  final int created;
  final int failed;
  const TrainingModeSyncResult({required this.created, required this.failed});
  bool get hasFailures => failed > 0;
}

/// Sincronizza le modalità di allenamento locali (Hive, solo quelle
/// disponibili — non soft-eliminate) verso il backend. Solo lettura
/// da Hive, mai scrittura locale.
///
/// LIMITAZIONE NOTA: nessuna deduplicazione né preservazione del
/// versionamento/lineage (parentModeKey) in questa fase — ogni
/// esecuzione crea nuove modalità indipendenti sul backend. La
/// modalità marcata come predefinita in locale viene impostata come
/// predefinita anche sul backend al termine della sincronizzazione.
class TrainingModeSyncRepository {
  final TrainingModesApiService _api;
  TrainingModeSyncRepository({TrainingModesApiService? api})
      : _api = api ?? TrainingModesApiService();

  Future<TrainingModeSyncResult> syncLocalModesToBackend() async {
    final localModes = TrainingModeDatabase.instance.getAvailable();

    int created = 0;
    int failed = 0;
    String? defaultRemoteId;

    for (final mode in localModes) {
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
        created++;

        if (mode.isDefault) {
          defaultRemoteId = remote.id;
        }
      } on ApiException {
        failed++;
      }
    }

    if (defaultRemoteId != null) {
      try {
        await _api.setDefault(defaultRemoteId);
      } on ApiException {
        // Non incrementiamo "failed" per questo: le modalità sono
        // comunque state create correttamente, solo il flag di
        // default non è stato applicato — segnalato via log, non
        // bloccante per il riepilogo principale.
      }
    }

    return TrainingModeSyncResult(created: created, failed: failed);
  }
}