import 'api_client.dart';
import 'dto/admin_user_dto.dart';

class AdminApiService {
  final ApiClient _client;
  AdminApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<AdminUserSummary>> fetchUsers() async {
    final json = await _client.get('/admin/users');
    final raw = json['data'] ?? json.values.first;
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminUserSummary.fromJson)
        .toList();
  }
}