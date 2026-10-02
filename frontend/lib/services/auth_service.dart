import '../core/networking/api_client.dart';
import '../models/user.dart';
import 'storage_service.dart';

/// Authentication: login, logout, current user, password change.
class AuthService {
  AuthService(this._api, this._storage);

  final ApiClient _api;
  final StorageService _storage;

  Future<AppUser> login(String username, String password) async {
    final json = await _api.post('/api/auth/login', body: {
      'username': username.trim(),
      'password': password,
    }) as Map<String, dynamic>;
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    await _storage.saveSession(json['access_token'] as String, user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Best effort: the token is stateless, clearing it locally is enough.
    }
    await _storage.clearSession();
  }

  Future<AppUser> me() async {
    final json = await _api.get('/api/auth/me') as Map<String, dynamic>;
    return AppUser.fromJson(json);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.put('/api/auth/password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
