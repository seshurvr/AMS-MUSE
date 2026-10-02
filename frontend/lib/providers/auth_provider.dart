import 'package:flutter/foundation.dart';

import '../core/networking/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

/// Holds the login session. On 401 anywhere in the app, [ApiClient]
/// calls [handleUnauthorized], which drops back to the login screen.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._storage);

  final AuthService _authService;
  final StorageService _storage;

  AuthStatus _status = AuthStatus.initializing;
  AppUser? _user;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
      } else {
        // Prefer the cached user for instant paint, then verify the token.
        _user = _storage.cachedUser;
        _status = AuthStatus.authenticated;
        try {
          _user = await _authService.me();
        } on AuthExpiredException {
          await _storage.clearSession();
          _user = null;
          _status = AuthStatus.unauthenticated;
        }
      }
    } catch (_) {
      // Offline / server down: stay on the cached session if we have one,
      // so the login screen can offer "retry".
      if (_user == null) _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.login(username, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Could not reach the server. Check the server URL and '
          'your network connection.';
      notifyListeners();
      return false;
    }
  }

  Future<void> handleUnauthorized() async {
    if (_status != AuthStatus.authenticated) return;
    await _storage.clearSession();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
