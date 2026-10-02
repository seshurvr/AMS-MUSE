import '../core/networking/api_client.dart';
import '../models/report.dart';
import '../models/user.dart';

/// Admin-only: user management and audit logs.
class AdminService {
  AdminService(this._api);

  final ApiClient _api;

  Future<List<AppUser>> listUsers() async {
    final json = await _api.get('/api/admin/users') as List<dynamic>;
    return json.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final json = await _api.post('/api/admin/users', body: {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
    return AppUser.fromJson(json);
  }

  Future<List<AuditLogEntry>> auditLogs({int limit = 100}) async {
    final json = await _api.get('/api/admin/audit-logs',
        query: {'limit': '$limit'}) as List<dynamic>;
    return json
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
