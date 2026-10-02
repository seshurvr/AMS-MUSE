import 'detection.dart';
import 'attendance_record.dart';

/// Attendance statuses. `needsReview` is the default for students who were
/// not detected — it must never be silently treated as absent.
enum AttendanceStatus { present, absent, excused, needsReview }

AttendanceStatus attendanceStatusFrom(String raw) {
  switch (raw) {
    case 'present':
      return AttendanceStatus.present;
    case 'absent':
      return AttendanceStatus.absent;
    case 'excused':
      return AttendanceStatus.excused;
    default:
      return AttendanceStatus.needsReview;
  }
}

String attendanceStatusTo(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
      return 'present';
    case AttendanceStatus.absent:
      return 'absent';
    case AttendanceStatus.excused:
      return 'excused';
    case AttendanceStatus.needsReview:
      return 'needs_review';
  }
}

/// Processing lifecycle of a session's classroom photo.
enum SessionProcessingStatus {
  uploaded,
  processing,
  processed,
  failed,
  finalized,
}

SessionProcessingStatus sessionStatusFrom(String raw) {
  switch (raw) {
    case 'processing':
      return SessionProcessingStatus.processing;
    case 'processed':
      return SessionProcessingStatus.processed;
    case 'failed':
      return SessionProcessingStatus.failed;
    case 'finalized':
      return SessionProcessingStatus.finalized;
    default:
      return SessionProcessingStatus.uploaded;
  }
}

/// One attendance session (a class + date + time + photo).
class AttendanceSession {
  AttendanceSession({
    required this.id,
    required this.classId,
    required this.date,
    required this.sessionTime,
    required this.subject,
    required this.processingStatus,
    required this.totalStudents,
    required this.detectedCount,
    required this.presentCount,
    required this.absentCount,
    required this.excusedCount,
    required this.reviewCount,
    required this.createdBy,
    this.notes,
    this.imageWidth,
    this.imageHeight,
    this.processingError,
  });

  final int id;
  final int classId;
  final DateTime date;
  final String sessionTime; // "HH:MM:SS" as returned by the API
  final String subject;
  final SessionProcessingStatus processingStatus;
  final int totalStudents;
  final int detectedCount;
  final int presentCount;
  final int absentCount;
  final int excusedCount;
  final int reviewCount;
  final int createdBy;
  final String? notes;
  final int? imageWidth;
  final int? imageHeight;
  final String? processingError;

  bool get isFinalized =>
      processingStatus == SessionProcessingStatus.finalized;

  String get shortTime =>
      sessionTime.length >= 5 ? sessionTime.substring(0, 5) : sessionTime;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      AttendanceSession(
        id: json['id'] as int,
        classId: json['class_id'] as int,
        date: DateTime.parse(json['date'] as String),
        sessionTime: (json['session_time'] ?? '') as String,
        subject: json['subject'] as String,
        processingStatus:
            sessionStatusFrom((json['processing_status'] ?? '') as String),
        totalStudents: (json['total_students'] ?? 0) as int,
        detectedCount: (json['detected_count'] ?? 0) as int,
        presentCount: (json['present_count'] ?? 0) as int,
        absentCount: (json['absent_count'] ?? 0) as int,
        excusedCount: (json['excused_count'] ?? 0) as int,
        reviewCount: (json['review_count'] ?? 0) as int,
        createdBy: (json['created_by'] ?? 0) as int,
        notes: json['notes'] as String?,
        imageWidth: json['image_width'] as int?,
        imageHeight: json['image_height'] as int?,
        processingError: json['processing_error'] as String?,
      );
}

/// Full session payload for the review screen.
class SessionDetail {
  SessionDetail({
    required this.session,
    required this.detections,
    required this.records,
    required this.summary,
    this.imageUrl,
  });

  final AttendanceSession session;
  final List<Detection> detections;
  final List<AttendanceRecord> records;
  final SessionSummary summary;
  final String? imageUrl;

  factory SessionDetail.fromJson(Map<String, dynamic> json) => SessionDetail(
        session: AttendanceSession.fromJson(
            json['session'] as Map<String, dynamic>),
        detections: (json['detections'] as List<dynamic>)
            .map((e) => Detection.fromJson(e as Map<String, dynamic>))
            .toList(),
        records: (json['records'] as List<dynamic>)
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary:
            SessionSummary.fromJson(json['summary'] as Map<String, dynamic>),
        imageUrl: json['image_url'] as String?,
      );
}

class SessionSummary {
  SessionSummary({
    required this.total,
    required this.detected,
    required this.present,
    required this.absent,
    required this.excused,
    required this.needsReview,
    required this.attendancePercentage,
  });

  final int total;
  final int detected;
  final int present;
  final int absent;
  final int excused;
  final int needsReview;
  final double attendancePercentage;

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        total: (json['total'] ?? 0) as int,
        detected: (json['detected'] ?? 0) as int,
        present: (json['present'] ?? 0) as int,
        absent: (json['absent'] ?? 0) as int,
        excused: (json['excused'] ?? 0) as int,
        needsReview: (json['needs_review'] ?? 0) as int,
        attendancePercentage:
            ((json['attendance_percentage'] ?? 0) as num).toDouble(),
      );
}

/// One row of the session-history list.
class HistoryItem {
  HistoryItem({
    required this.id,
    required this.date,
    required this.sessionTime,
    required this.className,
    required this.section,
    required this.subject,
    required this.total,
    required this.present,
    required this.absent,
    required this.excused,
    required this.needsReview,
    required this.status,
  });

  final int id;
  final DateTime date;
  final String sessionTime;
  final String className;
  final String section;
  final String subject;
  final int total;
  final int present;
  final int absent;
  final int excused;
  final int needsReview;
  final String status;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as int,
        date: DateTime.parse(json['date'] as String),
        sessionTime: (json['session_time'] ?? '') as String,
        className: json['class_name'] as String,
        section: json['section'] as String,
        subject: json['subject'] as String,
        total: (json['total'] ?? 0) as int,
        present: (json['present'] ?? 0) as int,
        absent: (json['absent'] ?? 0) as int,
        excused: (json['excused'] ?? 0) as int,
        needsReview: (json['needs_review'] ?? 0) as int,
        status: (json['status'] ?? '') as String,
      );
}

/// Image-quality analysis returned with an upload.
class ImageQuality {
  ImageQuality({
    required this.width,
    required this.height,
    required this.brightness,
    required this.blurScore,
    required this.warnings,
  });

  final int width;
  final int height;
  final double brightness;
  final double blurScore;
  final List<String> warnings;

  factory ImageQuality.fromJson(Map<String, dynamic> json) => ImageQuality(
        width: (json['width'] ?? 0) as int,
        height: (json['height'] ?? 0) as int,
        brightness: ((json['brightness'] ?? 0) as num).toDouble(),
        blurScore: ((json['blur_score'] ?? 0) as num).toDouble(),
        warnings: (json['warnings'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
