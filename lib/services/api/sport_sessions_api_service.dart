import 'api_client.dart';

class SportSessionsApiService {
  final ApiClient _client;
  SportSessionsApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<void> create({
    required String sportType,
    required String isoDate,
    required int durationSeconds,
    double? distanceKm,
    String? notes,
  }) async {
    await _client.post('/sport-sessions', body: {
      'sportType': sportType,
      'date': isoDate,
      'durationSeconds': durationSeconds,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }
}