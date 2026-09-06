import 'api_client.dart';
import 'dto/exercise_dto.dart';

/// Chiamate REST verso /exercises. Solo I/O — nessuna logica di
/// deduplicazione qui (è responsabilità di ExerciseSyncRepository).
class ExercisesApiService {
  final ApiClient _client;
  ExercisesApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<RemoteExercise>> fetchAll() async {
    // ApiClient.get ritorna sempre una Map; per una lista JSON pura
    // il backend risponde con un array top-level, che ApiClient
    // avvolge in {'data': [...]} solo se non è già una Map — qui
    // gestiamo esplicitamente entrambi i casi per sicurezza.
    final json = await _client.get('/exercises');
    final raw = json['data'] ?? json.values.first;
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RemoteExercise.fromJson)
        .toList();
  }

  Future<RemoteExercise> create({
    required String name,
    required String muscleGroup,
    String? notes,
  }) async {
    final json = await _client.post('/exercises', body: {
      'name': name,
      'muscleGroup': muscleGroup,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return RemoteExercise.fromJson(json);
  }

  /// NUOVO — propaga l'eliminazione di un esercizio al backend.
  /// Attenzione: il backend usa onDelete Restrict su Exercise per
  /// WorkoutExercise/SessionSet — se l'esercizio è ancora referenziato
  /// da una scheda o da uno storico remoti, la chiamata fallirà con un
  /// errore del server. Il chiamante deve gestire l'eccezione.
  Future<void> delete(String id) async {
    await _client.delete('/exercises/$id');
  }
}