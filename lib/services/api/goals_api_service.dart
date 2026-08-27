import 'api_client.dart';
import 'dto/goal_dto.dart';

class GoalsApiService {
  final ApiClient _client;
  GoalsApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<RemoteGoal> create({
    required String title,
    String? description,
    required String category,
    required String scheduleType,
    List<int>? scheduleDaysOfWeek,
    String? scheduleStartDate,
    String? scheduleEndDate,
    int? scheduleCustomInterval,
    String? deadlineDate,
    int colorIndex = 0,
  }) async {
    final json = await _client.post('/goals', body: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'category': category,
      'scheduleType': scheduleType,
      if (scheduleDaysOfWeek != null && scheduleDaysOfWeek.isNotEmpty)
        'scheduleDaysOfWeek': scheduleDaysOfWeek,
      if (scheduleStartDate != null) 'scheduleStartDate': scheduleStartDate,
      if (scheduleEndDate != null) 'scheduleEndDate': scheduleEndDate,
      if (scheduleCustomInterval != null)
        'scheduleCustomInterval': scheduleCustomInterval,
      if (deadlineDate != null) 'deadlineDate': deadlineDate,
      'colorIndex': colorIndex,
    });
    return RemoteGoal.fromJson(json);
  }

  Future<void> setCompletion(String goalId, String date, bool completed) async {
    await _client.put('/goals/$goalId/completions/$date', body: {
      'completed': completed,
    });
  }
}