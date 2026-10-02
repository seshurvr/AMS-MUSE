import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/networking/api_client.dart';
import '../core/networking/api_exception.dart';
import '../models/student.dart';

/// Student CRUD + CSV import/export for a class.
class StudentService {
  StudentService(this._api);

  final ApiClient _api;

  Future<List<Student>> listForClass(int classId) async {
    final json =
        await _api.get('/api/classes/$classId/students') as List<dynamic>;
    return json.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Student> create(Student student) async {
    final json = await _api.post('/api/students', body: student.toJson())
        as Map<String, dynamic>;
    return Student.fromJson(json);
  }

  Future<Student> update(int id, Map<String, dynamic> patch) async {
    final json =
        await _api.put('/api/students/$id', body: patch) as Map<String, dynamic>;
    return Student.fromJson(json);
  }

  Future<void> archive(int id) => _api.delete('/api/students/$id');

  /// Bulk import students from a CSV file.
  /// Returns per-row import results (imported / skipped / errors).
  Future<CsvImportResult> importCsv(
      int classId, Uint8List bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      _api.uriFor('/api/classes/$classId/students/import'),
    );
    final token = await _api.tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      String message = 'CSV import failed (HTTP ${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {}
      throw ApiException(response.statusCode, message);
    }
    return CsvImportResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uint8List> exportCsv(int classId) => _api.downloadBytes(
      '/api/classes/$classId/students/export',
      query: {'format': 'csv'});

  /// Student photo registration (Milestone 2 backend endpoint).
  /// Uploads one photo; the server validates exactly one face is present.
  Future<Map<String, dynamic>> uploadPhoto(
      int studentId, Uint8List bytes, String filename) {
    return _api.uploadMultipart(
      path: '/api/students/$studentId/photos',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
  }

  Future<List<Map<String, dynamic>>> listPhotos(int studentId) async {
    final json =
        await _api.get('/api/students/$studentId/photos') as List<dynamic>;
    return json.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> deletePhoto(int studentId, int photoId) =>
      _api.delete('/api/students/$studentId/photos/$photoId');
}
