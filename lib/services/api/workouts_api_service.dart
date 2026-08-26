import 'api_client.dart';
import 'dto/workout_dto.dart';

class WorkoutsApiService {
  final ApiClient _client;
  WorkoutsApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<RemoteWorkout>> fetchAll() async {
    final json = await _client.get('/workouts');
    final raw = json['data'] ?? json.values.first;
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RemoteWorkout.fromJson)
        .toList();
  }

  Future<RemoteWorkout> create({
    required String name,
    String? iconId,
    int? iconColorIndex,
  }) async {
    final json = await _client.post('/workouts', body: {
      'name': name,
      if (iconId != null) 'iconId': iconId,
      if (iconColorIndex != null) 'iconColorIndex': iconColorIndex,
    });
    return RemoteWorkout.fromJson(json);
  }

  Future<void> addExercise({
    required String workoutId,
    required String exerciseId,
    String? circuitId,
    int sets = 3,
    int targetReps = 8,
    double? targetWeight,
    int? restSeconds,
    int sortOrder = 0,
  }) async {
    await _client.post('/workouts/$workoutId/exercises', body: {
      'exerciseId': exerciseId,
      if (circuitId != null) 'circuitId': circuitId,
      'sets': sets,
      'targetReps': targetReps,
      if (targetWeight != null) 'targetWeight': targetWeight,
      if (restSeconds != null) 'restSeconds': restSeconds,
      'sortOrder': sortOrder,
    });
  }
}