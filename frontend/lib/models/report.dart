/// Per-student row of the attendance report.
class ReportStudentRow {
  ReportStudentRow({
    required this.studentId,
    required this.rollNumber,
    required this.name,
    required this.totalSessions,
    required this.present,
    required this.absent,
    required this.excused,
    required this.needsReview,
    required this.attendancePercentage,
  });

  final String studentId;
  final String rollNumber;
  final String name;
  final int totalSessions;
  final int present;
  final int absent;
  final int excused;
  final int needsReview;
  final double attendancePercentage;

  factory ReportStudentRow.fromJson(Map<String, dynamic> json) =>
      ReportStudentRow(
        studentId: (json['student_id'] ?? '') as String,
        rollNumber: (json['roll_number'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        totalSessions: (json['total_sessions'] ?? 0) as int,
        present: (json['present'] ?? 0) as int,
        absent: (json['absent'] ?? 0) as int,
        excused: (json['excused'] ?? 0) as int,
        needsReview: (json['needs_review'] ?? 0) as int,
        attendancePercentage:
            ((json['attendance_percentage'] ?? 0) as num).toDouble(),
      );
}

class ReportSummary {
  ReportSummary({required this.students, required this.totals});

  final List<ReportStudentRow> students;
  final ReportTotals totals;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
        students: (json['students'] as List<dynamic>)
            .map((e) => ReportStudentRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: ReportTotals.fromJson(
            json['class_totals'] as Map<String, dynamic>),
      );
}

class ReportTotals {
  ReportTotals({
    required this.totalSessions,
    required this.totalStudents,
    required this.avgAttendancePercentage,
  });

  final int totalSessions;
  final int totalStudents;
  final double avgAttendancePercentage;

  factory ReportTotals.fromJson(Map<String, dynamic> json) => ReportTotals(
        totalSessions: (json['total_sessions'] ?? 0) as int,
        totalStudents: (json['total_students'] ?? 0) as int,
        avgAttendancePercentage:
            ((json['avg_attendance_percentage'] ?? 0) as num).toDouble(),
      );
}

/// Audit log entry (admin only).
class AuditLogEntry {
  AuditLogEntry({
    required this.id,
    required this.action,
    required this.timestamp,
    this.userId,
    this.username,
    this.recordType,
    this.recordId,
  });

  final int id;
  final String action;
  final DateTime timestamp;
  final int? userId;
  final String? username;
  final String? recordType;
  final int? recordId;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as int,
        action: (json['action'] ?? '') as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        userId: json['user_id'] as int?,
        username: json['username'] as String?,
        recordType: json['record_type'] as String?,
        recordId: json['record_id'] as int?,
      );
}
