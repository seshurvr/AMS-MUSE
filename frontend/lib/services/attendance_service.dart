import 'dart:typed_data';

import '../core/networking/api_client.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../models/detection.dart';

/// Attendance sessions: create, upload photo, process, review, finalize.
class AttendanceService {
  AttendanceService(this._api);

  final ApiClient _api;

  Future<AttendanceSession> createSession({
    required int classId,
    required DateTime date,
    required String sessionTime, // "HH:MM"
    required String subject,
    String? notes,
  }) async {
    final json = await _api.post('/api/attendance/sessions', body: {
      'class_id': classId,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'session_time': sessionTime.length == 5 ? '$sessionTime:00' : sessionTime,
      'subject': subject.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }) as Map<String, dynamic>;
    return AttendanceSession.fromJson(json);
  }

  Future<ImageQuality> uploadImage(
      int sessionId, Uint8List bytes, String filename) async {
    final json = await _api.uploadMultipart(
      path: '/api/attendance/sessions/$sessionId/image',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
    return ImageQuality.fromJson(json['quality'] as Map<String, dynamic>);
  }

  Future<List<Detection>> processSession(int sessionId) async {
    final json = await _api.post('/api/attendance/sessions/$sessionId/process')
        as Map<String, dynamic>;
    return (json['detections'] as List<dynamic>)
        .map((e) => Detection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionDetail> getSession(int sessionId) async {
    final json =
        await _api.get('/api/attendance/sessions/$sessionId')
            as Map<String, dynamic>;
    return SessionDetail.fromJson(json);
  }

  Future<Uint8List> sessionImageBytes(String imageUrl) =>
      _api.downloadBytes(imageUrl);

  Future<void> saveRecords(
      int sessionId, List<AttendanceRecord> records) async {
    await _api.put('/api/attendance/sessions/$sessionId/records', body: {
      'records': records.map((r) => r.toJson()).toList(),
    });
  }

  Future<Map<String, dynamic>> finalizeSession(
      int sessionId, List<AttendanceRecord> records) async {
    final json = await _api.post(
      '/api/attendance/sessions/$sessionId/finalize',
      body: {
        'records': records.map((r) => r.toJson()).toList(),
      },
    ) as Map<String, dynamic>;
    return json;
  }

  Future<void> deleteSession(int sessionId) =>
      _api.delete('/api/attendance/sessions/$sessionId');

  Future<List<HistoryItem>> history({
    int? classId,
    DateTime? from,
    DateTime? to,
    String? subject,
  }) async {
    String? fmt(DateTime? d) => d == null
        ? null
        : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final query = <String, String>{
      if (classId != null) 'class_id': '$classId',
      if (fmt(from) != null) 'from': fmt(from)!,
      if (fmt(to) != null) 'to': fmt(to)!,
      if (subject != null && subject.trim().isNotEmpty)
        'subject': subject.trim(),
    };
    final json =
        await _api.get('/api/attendance/history', query: query) as List<dynamic>;
    return json
        .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Download the attendance export for a session (`csv` or `xlsx`).
  Future<Uint8List> exportSession(int sessionId, String format) =>
      _api.downloadBytes('/api/export/attendance', query: {
        'session_id': '$sessionId',
        'format': format,
      });
}
