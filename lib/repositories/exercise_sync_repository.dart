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
        // Esiste già sul backend (creato prima dell'introduzione del
        // mapping, o da un'altra sorgente): non lo ricreiamo. Non
        // avendone l'id qui non possiamo registrare il mapping —
        // verrà ririlevato per nome anche nei prossimi giri: sicuro
        // (nessun duplicato), non perfettamente ottimizzato solo in
        // questo caso limite.
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
      }
    }

    return ExerciseSyncResult(
      created: created,
      alreadySynced: alreadySynced,
      failedNames: failed,
    );
  }
}