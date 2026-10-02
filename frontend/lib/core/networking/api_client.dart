import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Central HTTP client for the FastAPI backend.
///
/// - Injects `Authorization: Bearer <token>` on every request.
/// - Maps HTTP errors to [ApiException]; 401 becomes [AuthExpiredException]
///   and fires [onUnauthorized] so the app can log the user out.
/// - Supports relative base URLs (`/api`) for Flutter web served behind the
///   nginx `/api` reverse proxy, and absolute URLs for Android.
class ApiClient {
  ApiClient({
    required this.tokenProvider,
    required this.baseUrlProvider,
  });

  final Future<String?> Function() tokenProvider;
  final String Function() baseUrlProvider;

  FutureOr<void> Function()? onUnauthorized;

  /// Builds the full request URI for an API [path].
  ///
  /// [path] normally starts with `/api/...`. When the base URL itself is a
  /// path prefix (Flutter web behind the nginx `/api` proxy), a [path] that
  /// already starts with that prefix (e.g. image URLs returned by the API)
  /// is used as-is instead of being doubled.
  Uri uriFor(String path, [Map<String, String>? query]) {
    final base = baseUrlProvider().trim().replaceAll(RegExp(r'/+$'), '');
    if (base.startsWith('/')) {
      final full =
          (path == base || path.startsWith('$base/')) ? path : '$base$path';
      return Uri.base.resolve(full).replace(queryParameters: query);
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _messageOf(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
          return first.toString();
        }
      }
    } catch (_) {
      // fall through to the generic message
    }
    return 'Request failed (HTTP ${response.statusCode}).';
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 401) {
      final exception = AuthExpiredException(_messageOf(response));
      onUnauthorized?.call();
      throw exception;
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _messageOf(response));
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await http.get(
      uriFor(path, query),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await http.post(
      uriFor(path),
      headers: await _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await http.put(
      uriFor(path),
      headers: await _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      uriFor(path),
      headers: await _headers(),
    );
    return _decode(response);
  }

  /// Multipart image upload (classroom photo, student registration photo).
  Future<Map<String, dynamic>> uploadMultipart({
    required String path,
    required String field,
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', uriFor(path));
    request.headers.addAll(await _headers());
    request.files.add(
      http.MultipartFile.fromBytes(field, bytes, filename: filename),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    return (decoded as Map).cast<String, dynamic>();
  }

  /// Authenticated binary download (protected images, CSV/XLSX exports).
  Future<Uint8List> downloadBytes(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await http.get(
      uriFor(path, query),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      final exception = AuthExpiredException(_messageOf(response));
      onUnauthorized?.call();
      throw exception;
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _messageOf(response));
    }
    return response.bodyBytes;
  }
}
