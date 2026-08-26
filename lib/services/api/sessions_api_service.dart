import 'api_client.dart';
import 'dto/session_dto.dart';

class SessionsApiService {
  final ApiClient _client;
  SessionsApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<RemoteSession> create({
    String? workoutId,
    required String workoutName,
    required String isoDate,
    int? durationSeconds,
  }) async {
    final json = await _client.post('/sessions', body: {
      if (workoutId != null) 'workoutId': workoutId,
      'workoutName': workoutName,
      'date': isoDate,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });
    return RemoteSession.fromJson(json);
  }

  Future<void> addSet({
    required String sessionId,
    required String exerciseId,
    required int setNumber,
    required double weight,
    required int reps,
    required bool completed,
    int? restSeconds,
    String? executionStatus,
  }) async {
    await _client.post('/sessions/$sessionId/sets', body: {
      'exerciseId': exerciseId,
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'completed': completed,
      if (restSeconds != null) 'restSeconds': restSeconds,
      if (executionStatus != null) 'executionStatus': executionStatus,
    });
  }
}