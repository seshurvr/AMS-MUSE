import 'package:classroom_attendance/models/attendance_record.dart';
import 'package:classroom_attendance/models/attendance_session.dart';
import 'package:classroom_attendance/models/class_room.dart';
import 'package:classroom_attendance/models/detection.dart';
import 'package:classroom_attendance/models/report.dart';
import 'package:classroom_attendance/models/student.dart';
import 'package:classroom_attendance/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser', () {
    test('parses login/me payload', () {
      final user = AppUser.fromJson({
        'id': 1,
        'username': 'teacher',
        'email': 'teacher@demo.local',
        'role': 'teacher',
        'created_at': '2026-10-02T10:00:00',
      });
      expect(user.id, 1);
      expect(user.isAdmin, isFalse);
      expect(user.toJson()['email'], 'teacher@demo.local');
    });
  });

  group('ClassRoom', () {
    test('parses list payload with student_count', () {
      final c = ClassRoom.fromJson({
        'id': 3,
        'name': '10',
        'section': 'A',
        'subject': 'Mathematics',
        'academic_year': '2026-27',
        'teacher_id': 1,
        'status': 'active',
        'student_count': 20,
        'created_at': '2026-10-02T10:00:00',
        'updated_at': '2026-10-02T10:00:00',
      });
      expect(c.displayName, '10 · A');
      expect(c.isActive, isTrue);
      expect(c.studentCount, 20);
    });

    test('parses detail payload with embedded students', () {
      final c = ClassRoom.fromJson({
        'id': 3,
        'name': '10',
        'section': 'A',
        'subject': 'Mathematics',
        'academic_year': '2026-27',
        'teacher_id': 1,
        'status': 'active',
        'students': [
          {
            'id': 7,
            'student_id': 'STU001',
            'roll_number': '1',
            'name': 'Student One',
            'class_id': 3,
            'status': 'active',
            'created_at': '2026-10-02T10:00:00',
            'updated_at': '2026-10-02T10:00:00',
          }
        ],
        'created_at': '2026-10-02T10:00:00',
        'updated_at': '2026-10-02T10:00:00',
      });
      expect(c.students, hasLength(1));
      expect(c.students.first.name, 'Student One');
    });
  });

  group('Student', () {
    test('round-trips create payload', () {
      final s = Student(
        id: 0,
        studentId: 'STU001',
        rollNumber: '1',
        name: 'Student One',
        classId: 3,
        status: 'active',
      );
      final json = s.toJson();
      expect(json['student_id'], 'STU001');
      expect(json['class_id'], 3);
      expect(json.containsKey('email'), isFalse);
    });

    test('parses CSV import result', () {
      final r = CsvImportResult.fromJson({
        'imported': 18,
        'skipped': 2,
        'errors': [
          {'row': 5, 'message': 'duplicate roll number'}
        ],
      });
      expect(r.imported, 18);
      expect(r.errors.first.row, 5);
    });
  });

  group('AttendanceSession', () {
    test('parses session payload', () {
      final s = AttendanceSession.fromJson({
        'id': 9,
        'class_id': 3,
        'date': '2026-10-02',
        'session_time': '10:30:00',
        'subject': 'Mathematics',
        'notes': null,
        'processing_status': 'processed',
        'total_students': 20,
        'detected_count': 17,
        'present_count': 0,
        'absent_count': 0,
        'excused_count': 0,
        'review_count': 0,
        'created_by': 1,
        'created_at': '2026-10-02T10:00:00',
        'updated_at': '2026-10-02T10:00:00',
      });
      expect(s.shortTime, '10:30');
      expect(s.processingStatus,
          SessionProcessingStatus.processed);
      expect(s.isFinalized, isFalse);
    });
  });

  group('Detection', () {
    test('parses detection payload', () {
      final d = Detection.fromJson({
        'id': 1,
        'detection_number': 2,
        'x': 100.0,
        'y': 80.0,
        'width': 120.0,
        'height': 150.0,
        'confidence': 0.94,
      });
      expect(d.label, 'Person 2');
      expect(d.confidence, 0.94);
    });
  });

  group('AttendanceRecord', () {
    test('parses record with embedded student', () {
      final r = AttendanceRecord.fromJson({
        'id': 4,
        'session_id': 9,
        'status': 'needs_review',
        'detection_id': null,
        'manually_confirmed': false,
        'notes': null,
        'student': {
          'id': 7,
          'student_id': 'STU001',
          'roll_number': '1',
          'name': 'Student One',
        },
        'created_at': '2026-10-02T10:00:00',
        'updated_at': '2026-10-02T10:00:00',
      });
      expect(r.status, AttendanceStatus.needsReview);
      expect(r.source, RecordSource.automatic);
      final json = r.toJson();
      expect(json['status'], 'needs_review');
      expect(json['student_id'], 7);
    });
  });

  group('SessionDetail', () {
    test('parses full detail payload', () {
      final detail = SessionDetail.fromJson({
        'session': {
          'id': 9,
          'class_id': 3,
          'date': '2026-10-02',
          'session_time': '10:30:00',
          'subject': 'Mathematics',
          'processing_status': 'processed',
          'total_students': 20,
          'detected_count': 2,
          'present_count': 0,
          'absent_count': 0,
          'excused_count': 0,
          'review_count': 0,
          'created_by': 1,
          'created_at': '2026-10-02T10:00:00',
          'updated_at': '2026-10-02T10:00:00',
        },
        'detections': [],
        'records': [],
        'image_url': '/api/files/abc.jpg',
        'summary': {
          'total': 20,
          'detected': 2,
          'present': 0,
          'absent': 0,
          'excused': 0,
          'needs_review': 20,
          'attendance_percentage': 0.0,
        },
      });
      expect(detail.imageUrl, '/api/files/abc.jpg');
      expect(detail.summary.needsReview, 20);
    });
  });

  group('ReportSummary', () {
    test('parses report payload and documents the formula', () {
      final summary = ReportSummary.fromJson({
        'students': [
          {
            'student_id': 'STU001',
            'roll_number': '1',
            'name': 'Student One',
            'total_sessions': 10,
            'present': 8,
            'absent': 1,
            'excused': 1,
            'needs_review': 0,
            'attendance_percentage': 80.0,
          }
        ],
        'class_totals': {
          'total_sessions': 10,
          'total_students': 20,
          'avg_attendance_percentage': 82.5,
        },
      });
      final row = summary.students.first;
      // needs_review is never counted as absent.
      expect(row.present + row.absent + row.excused + row.needsReview,
          row.totalSessions);
      expect(summary.totals.avgAttendancePercentage, 82.5);
    });
  });

  group('HistoryItem', () {
    test('parses history payload', () {
      final h = HistoryItem.fromJson({
        'id': 9,
        'date': '2026-10-02',
        'session_time': '10:30:00',
        'class_name': '10',
        'section': 'A',
        'subject': 'Mathematics',
        'total': 20,
        'present': 15,
        'absent': 3,
        'excused': 1,
        'needs_review': 1,
        'status': 'finalized',
      });
      expect(h.present, 15);
      expect(h.needsReview, 1);
    });
  });
}
