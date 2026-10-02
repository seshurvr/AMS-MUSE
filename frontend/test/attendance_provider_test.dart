import 'package:classroom_attendance/core/networking/api_client.dart';
import 'package:classroom_attendance/models/attendance_session.dart';
import 'package:classroom_attendance/models/detection.dart';
import 'package:classroom_attendance/models/student.dart';
import 'package:classroom_attendance/providers/attendance_provider.dart';
import 'package:classroom_attendance/services/attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local review logic: no network involved.
void main() {
  ApiClient fakeApi() => ApiClient(
        tokenProvider: () async => null,
        baseUrlProvider: () => 'http://localhost:8000',
      );

  AttendanceProvider providerWithRecords() {
    final provider =
        AttendanceProvider(AttendanceService(fakeApi()));
    // Simulate a loaded session with 2 detections and a 3-student roster.
    provider.debugSetDetail(
      sessionId: 9,
      classId: 3,
      detections: [
        Detection(
            id: 11,
            detectionNumber: 1,
            x: 10,
            y: 10,
            width: 50,
            height: 60,
            confidence: 0.9),
        Detection(
            id: 12,
            detectionNumber: 2,
            x: 200,
            y: 10,
            width: 50,
            height: 60,
            confidence: 0.8),
      ],
    );
    provider.ensureLocalRecords([
      Student(
          id: 1,
          studentId: 'STU001',
          rollNumber: '1',
          name: 'Asha',
          classId: 3,
          status: 'active'),
      Student(
          id: 2,
          studentId: 'STU002',
          rollNumber: '2',
          name: 'Ravi',
          classId: 3,
          status: 'active'),
      Student(
          id: 3,
          studentId: 'STU003',
          rollNumber: '3',
          name: 'Meera',
          classId: 3,
          status: 'active'),
    ]);
    return provider;
  }

  test('ensureLocalRecords backfills needs_review, never absent', () {
    final p = providerWithRecords();
    expect(p.records, hasLength(3));
    expect(
      p.records.every((r) => r.status == AttendanceStatus.needsReview),
      isTrue,
    );
  });

  test('assignDetection marks present + manual', () {
    final p = providerWithRecords();
    expect(p.assignDetection(detectionId: 11, studentDbId: 1), isTrue);
    final r = p.recordForStudent(1)!;
    expect(r.status, AttendanceStatus.present);
    expect(r.manuallyConfirmed, isTrue);
    expect(r.detectionId, 11);
    expect(p.assignments, {11: 1});
  });

  test('assignDetection blocks duplicates', () {
    final p = providerWithRecords();
    expect(p.assignDetection(detectionId: 11, studentDbId: 1), isTrue);
    // Same student on another detection must be rejected.
    expect(p.assignDetection(detectionId: 12, studentDbId: 1), isFalse);
    expect(p.error, contains('already assigned'));
    // …but can be forced after the teacher resolves the conflict.
    p.assignDetection(detectionId: 11); // unassign
    expect(p.assignDetection(detectionId: 12, studentDbId: 1), isTrue);
  });

  test('unassign returns the student to needs_review', () {
    final p = providerWithRecords();
    p.assignDetection(detectionId: 11, studentDbId: 2);
    p.assignDetection(detectionId: 11); // mark unknown
    final r = p.recordForStudent(2)!;
    expect(r.detectionId, isNull);
    expect(r.status, AttendanceStatus.needsReview);
  });

  test('markStudent sets manual status without a detection', () {
    final p = providerWithRecords();
    p.markStudent(3, AttendanceStatus.excused);
    final r = p.recordForStudent(3)!;
    expect(r.status, AttendanceStatus.excused);
    expect(r.manuallyConfirmed, isTrue);
    expect(r.detectionId, isNull);
  });

  test('localSummary counts correctly', () {
    final p = providerWithRecords();
    p.assignDetection(detectionId: 11, studentDbId: 1);
    p.markStudent(2, AttendanceStatus.absent);
    final s = p.localSummary();
    expect(s.total, 3);
    expect(s.detected, 2);
    expect(s.present, 1);
    expect(s.absent, 1);
    expect(s.needsReview, 1);
  });
}
