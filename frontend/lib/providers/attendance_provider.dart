import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/networking/api_exception.dart';
import '../core/utils/file_download.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../models/detection.dart';
import '../models/student.dart';
import '../services/attendance_service.dart';

/// State for the take-attendance wizard and the review screen.
///
/// The teacher's working copy of the records lives here; nothing is sent
/// to the server until [saveRecords] / [finalize] is called. Assignment of
/// two detections to the same student is blocked with [duplicateOf].
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._service);

  final AttendanceService _service;

  SessionDetail? _detail;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _notice;
  int? _selectedDetectionId;

  SessionDetail? get detail => _detail;
  Uint8List? get imageBytes => _imageBytes;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  String? get notice => _notice;
  int? get selectedDetectionId => _selectedDetectionId;

  List<AttendanceRecord> get records => _detail?.records ?? [];
  List<Detection> get detections => _detail?.detections ?? [];

  /// detectionId -> studentDbId for detections currently assigned.
  Map<int, int> get assignments {
    final map = <int, int>{};
    for (final r in records) {
      if (r.detectionId != null) map[r.detectionId!] = r.studentDbId;
    }
    return map;
  }

  /// If [studentDbId] is already assigned to a *different* detection,
  /// returns that detection's number so the UI can warn the teacher.
  int? duplicateOf(int studentDbId, int forDetectionId) {
    for (final r in records) {
      if (r.studentDbId == studentDbId &&
          r.detectionId != null &&
          r.detectionId != forDetectionId) {
        final det = detections
            .where((d) => d.id == r.detectionId)
            .map((d) => d.detectionNumber)
            .firstOrNull;
        return det;
      }
    }
    return null;
  }

  AttendanceRecord? recordForStudent(int studentDbId) =>
      records.where((r) => r.studentDbId == studentDbId).firstOrNull;

  AttendanceRecord? recordForDetection(int detectionId) =>
      records.where((r) => r.detectionId == detectionId).firstOrNull;

  void selectDetection(int? detectionId) {
    _selectedDetectionId = detectionId;
    notifyListeners();
  }

  void clear() {
    _detail = null;
    _imageBytes = null;
    _error = null;
    _notice = null;
    _selectedDetectionId = null;
    notifyListeners();
  }

  Future<AttendanceSession?> createSession({
    required int classId,
    required DateTime date,
    required String sessionTime,
    required String subject,
    String? notes,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _service.createSession(
        classId: classId,
        date: date,
        sessionTime: sessionTime,
        subject: subject,
        notes: notes,
      );
      await loadSession(session.id);
      return session;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not create the attendance session.';
    }
    _loading = false;
    notifyListeners();
    return null;
  }

  Future<ImageQuality?> uploadImage(
      int sessionId, Uint8List bytes, String filename) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final quality = await _service.uploadImage(sessionId, bytes, filename);
      if (quality.warnings.isNotEmpty) {
        _notice =
            'Image quality may reduce recognition accuracy: ${quality.warnings.join(' ')}';
      }
      await loadSession(sessionId);
      return quality;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Image upload failed.';
    }
    _loading = false;
    notifyListeners();
    return null;
  }

  Future<bool> processSession(int sessionId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.processSession(sessionId);
      await loadSession(sessionId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Recognition processing failed.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loadSession(int sessionId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _detail = await _service.getSession(sessionId);
      _imageBytes = null;
      if (_detail!.imageUrl != null) {
        try {
          _imageBytes =
              await _service.sessionImageBytes(_detail!.imageUrl!);
        } catch (_) {
          // The review UI still works (boxes listed) without the photo.
          _notice = 'Could not load the classroom photo.';
        }
      }
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the session.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  /// Assign [studentDbId] (or nobody) to a detection, marking the record
  /// manual. Returns false when the student is already assigned to a
  /// different detection (the teacher must resolve the conflict first,
  /// unless [force] is true).
  bool assignDetection({
    required int detectionId,
    int? studentDbId,
    bool force = false,
  }) {
    if (_detail == null) return false;
    if (studentDbId != null && !force) {
      final dup = duplicateOf(studentDbId, detectionId);
      if (dup != null) {
        final name = recordForStudent(studentDbId)?.studentName ?? 'Student';
        _error =
            '$name is already assigned to Person $dup. Unassign it there first, or pick another student.';
        notifyListeners();
        return false;
      }
    }
    // Unassign whoever currently holds this detection.
    final current = recordForDetection(detectionId);
    if (current != null) {
      current.detectionId = null;
      current.status = AttendanceStatus.needsReview;
      current.manuallyConfirmed = true;
    }
    if (studentDbId != null) {
      final record = recordForStudent(studentDbId);
      if (record == null) return false;
      record.detectionId = detectionId;
      record.status = AttendanceStatus.present;
      record.manuallyConfirmed = true;
    }
    _error = null;
    notifyListeners();
    return true;
  }

  /// Build local working records for every active roster student that does
  /// not have one yet. Students the camera missed start as `needs_review` —
  /// they are never silently marked absent.
  void ensureLocalRecords(List<Student> roster) {
    final detail = _detail;
    if (detail == null) return;
    final existing = {for (final r in detail.records) r.studentDbId};
    var changed = false;
    for (final s in roster.where((s) => s.isActive)) {
      if (!existing.contains(s.id)) {
        detail.records.add(AttendanceRecord(
          id: 0,
          sessionId: detail.session.id,
          studentDbId: s.id,
          studentCode: s.studentId,
          rollNumber: s.rollNumber,
          studentName: s.name,
          status: AttendanceStatus.needsReview,
          manuallyConfirmed: false,
        ));
        changed = true;
      }
    }
    if (changed) {
      detail.records.sort((a, b) {
        final c = a.rollNumber.compareTo(b.rollNumber);
        return c != 0 ? c : a.studentName.compareTo(b.studentName);
      });
      notifyListeners();
    }
  }

  /// Manually mark a student present/absent/excused (no detection involved).
  void markStudent(int studentDbId, AttendanceStatus status) {
    final record = recordForStudent(studentDbId);
    if (record == null) return;
    record.status = status;
    record.manuallyConfirmed = true;
    notifyListeners();
  }

  SessionSummary localSummary() {
    var present = 0, absent = 0, excused = 0, needsReview = 0;
    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
        case AttendanceStatus.needsReview:
          needsReview++;
          break;
      }
    }
    final total = records.length;
    final counted = present + absent + excused;
    final pct =
        counted == 0 ? 0.0 : (present / counted * 10000).round() / 100;
    return SessionSummary(
      total: total,
      detected: detections.length,
      present: present,
      absent: absent,
      excused: excused,
      needsReview: needsReview,
      attendancePercentage: pct,
    );
  }

  Future<bool> saveRecords() async {
    if (_detail == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.saveRecords(_detail!.session.id, records);
      _notice = 'Review progress saved.';
      _saving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not save records.';
    }
    _saving = false;
    notifyListeners();
    return false;
  }

  Future<bool> finalize() async {
    if (_detail == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.finalizeSession(_detail!.session.id, records);
      await loadSession(_detail!.session.id);
      _notice = 'Attendance saved successfully.';
      _saving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not finalize attendance.';
    }
    _saving = false;
    notifyListeners();
    return false;
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      await _service.deleteSession(sessionId);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> export(int sessionId, String format) async {
    try {
      final bytes = await _service.exportSession(sessionId, format);
      final where = await saveDownloadedFile(
          bytes, 'attendance-session-$sessionId.$format');
      _notice = 'Export saved to $where.';
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Export failed.';
    }
    notifyListeners();
  }

  void clearNotice() {
    _notice = null;
    _error = null;
    notifyListeners();
  }

  /// Test-only: seed a minimal session detail without hitting the network.
  @visibleForTesting
  void debugSetDetail({
    required int sessionId,
    required int classId,
    required List<Detection> detections,
  }) {
    _detail = SessionDetail(
      session: AttendanceSession(
        id: sessionId,
        classId: classId,
        date: DateTime(2026, 10, 2),
        sessionTime: '10:30:00',
        subject: 'Mathematics',
        processingStatus: SessionProcessingStatus.processed,
        totalStudents: 0,
        detectedCount: detections.length,
        presentCount: 0,
        absentCount: 0,
        excusedCount: 0,
        reviewCount: 0,
        createdBy: 1,
      ),
      detections: detections,
      records: [],
      summary: SessionSummary(
        total: 0,
        detected: detections.length,
        present: 0,
        absent: 0,
        excused: 0,
        needsReview: 0,
        attendancePercentage: 0,
      ),
    );
    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
