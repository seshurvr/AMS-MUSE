import 'attendance_session.dart';

/// One student's attendance mark inside a session.
/// [source] tracks whether the mark came from automatic recognition
/// or a manual teacher decision (never silently overwritten).
enum RecordSource { automatic, manual }

/// Editable attendance record (teacher's working copy on the review screen).
class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentDbId,
    required this.studentCode,
    required this.rollNumber,
    required this.studentName,
    required this.status,
    required this.manuallyConfirmed,
    this.detectionId,
    this.notes,
  });

  final int id;
  final int sessionId;
  final int studentDbId;
  final String studentCode;
  final String rollNumber;
  final String studentName;
  AttendanceStatus status;
  bool manuallyConfirmed;
  int? detectionId;
  String? notes;

  RecordSource get source =>
      manuallyConfirmed ? RecordSource.manual : RecordSource.automatic;

  AttendanceRecord copy() => AttendanceRecord(
        id: id,
        sessionId: sessionId,
        studentDbId: studentDbId,
        studentCode: studentCode,
        rollNumber: rollNumber,
        studentName: studentName,
        status: status,
        manuallyConfirmed: manuallyConfirmed,
        detectionId: detectionId,
        notes: notes,
      );

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return AttendanceRecord(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      studentDbId: student['id'] as int,
      studentCode: (student['student_id'] ?? '') as String,
      rollNumber: (student['roll_number'] ?? '') as String,
      studentName: (student['name'] ?? '') as String,
      status: attendanceStatusFrom((json['status'] ?? '') as String),
      manuallyConfirmed: (json['manually_confirmed'] ?? false) as bool,
      detectionId: json['detection_id'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentDbId,
        'status': attendanceStatusTo(status),
        if (detectionId != null) 'detection_id': detectionId,
        'manually_confirmed': manuallyConfirmed,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}
