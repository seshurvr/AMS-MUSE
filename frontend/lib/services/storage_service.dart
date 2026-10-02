import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/user.dart';

/// Persists the auth session and app settings on-device.
class StorageService {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kBaseUrl = 'api_base_url';

  SharedPreferences? _prefs;
  String? _token;
  AppUser? _user;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _token = _prefs!.getString(_kToken);
    final userJson = _prefs!.getString(_kUser);
    if (userJson != null) {
      try {
        _user = AppUser.fromJson(
            jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
  }

  Future<String?> getToken() async {
    await init();
    return _token;
  }

  AppUser? get cachedUser => _user;

  Future<void> saveSession(String token, AppUser user) async {
    await init();
    _token = token;
    _user = user;
    await _prefs!.setString(_kToken, token);
    await _prefs!.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    await init();
    _token = null;
    _user = null;
    await _prefs!.remove(_kToken);
    await _prefs!.remove(_kUser);
  }

  String baseUrl() {
    final override = _prefs?.getString(_kBaseUrl);
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return AppConfig.apiBaseUrl;
  }

  Future<void> setBaseUrlOverride(String? value) async {
    await init();
    if (value == null || value.trim().isEmpty) {
      await _prefs!.remove(_kBaseUrl);
    } else {
      await _prefs!.setString(_kBaseUrl, value.trim());
    }
  }
}
