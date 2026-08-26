import 'api_client.dart';
import 'dto/circuit_dto.dart';

class CircuitsApiService {
  final ApiClient _client;
  CircuitsApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<RemoteCircuit> create({
    required String workoutId,
    required String name,
    required int rounds,
    required int sortOrder,
  }) async {
    final json = await _client.post('/workouts/$workoutId/circuits', body: {
      'name': name,
      'rounds': rounds,
      'sortOrder': sortOrder,
    });
    return RemoteCircuit.fromJson(json);
  }
}