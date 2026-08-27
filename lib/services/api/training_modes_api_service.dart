import 'api_client.dart';
import 'dto/training_mode_dto.dart';

class TrainingModesApiService {
  final ApiClient _client;
  TrainingModesApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<RemoteTrainingMode> create({
    required String name,
    required String category,
    required List<RemoteTrainingModeSet> sets,
  }) async {
    final json = await _client.post('/training-modes', body: {
      'name': name,
      'category': category,
      'sets': sets.map((s) => s.toJson()).toList(),
    });
    return RemoteTrainingMode.fromJson(json);
  }

  Future<void> setDefault(String id) async {
    await _client.post('/training-modes/$id/set-default');
  }
}