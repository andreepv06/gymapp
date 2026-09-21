import 'package:flutter/foundation.dart';
import '../db/hive_database.dart';
import '../services/api/api_exception.dart';
import '../services/api/exercises_api_service.dart';
import 'sync_mapping_storage.dart';

class ExerciseSyncResult {
  final int created;
  final int alreadySynced;
  final List<String> failedNames;

  const ExerciseSyncResult({
    required this.created,
    required this.alreadySynced,
    required this.failedNames,
  });

  bool get hasFailures => failedNames.isNotEmpty;
  int get total => created + alreadySynced + failedNames.length;
}

/// AGGIORNATO (fix root cause blocco sync) — il catch per singolo
/// esercizio ora è generico (non più solo ApiException): qualunque
/// errore isolato su un esercizio (parsing, dato corrotto lato
/// backend) resta contenuto a QUEL solo esercizio, invece di
/// propagarsi e interrompere il ciclo — che a sua volta, prima del
/// fix in SyncEngine, bloccava l'intera sincronizzazione di tutti
/// gli altri domini (schede, storico, obiettivi).
class ExerciseSyncRepository {
  static const domain = 'exercise';

  final ExercisesApiService _api;
  final SyncMappingStorage _mapping;

  ExerciseSyncRepository({
    ExercisesApiService? api,
    SyncMappingStorage? mapping,
  })  : _api = api ?? ExercisesApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<ExerciseSyncResult> syncLocalLibraryToBackend() async {
    final localExercises = HiveDatabase.instance.getExercises();

    final remote = await _api.fetchAll();
    final remoteNames = remote.map((e) => e.name.trim().toLowerCase()).toSet();

    int created = 0;
    int alreadySynced = 0;
    final failed = <String>[];

    for (final exercise in localExercises) {
      final localKey = exercise.key;
      final alreadyMapped = await _mapping.getRemoteId(domain, localKey);
      if (alreadyMapped != null) {
        alreadySynced++;
        continue;
      }

      final normalizedName = exercise.name.trim().toLowerCase();
      if (remoteNames.contains(normalizedName)) {
        alreadySynced++;
        continue;
      }

      try {
        final createdExercise = await _api.create(
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          notes: exercise.notes,
        );
        await _mapping.setRemoteId(domain, localKey, createdExercise.id);
        created++;
        remoteNames.add(normalizedName);
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.conflict) {
          alreadySynced++;
          remoteNames.add(normalizedName);
        } else {
          failed.add(exercise.name);
        }
      } catch (e) {
        // NUOVO — cattura generica: qualsiasi altro errore isolato
        // su questo esercizio non deve mai propagarsi e bloccare
        // il resto del ciclo.
        debugPrint('[ExerciseSyncRepository] Esercizio "${exercise.name}" '
            'fallito con errore non-API: $e');
        failed.add(exercise.name);
      }
    }

    return ExerciseSyncResult(
      created: created,
      alreadySynced: alreadySynced,
      failedNames: failed,
    );
  }
}