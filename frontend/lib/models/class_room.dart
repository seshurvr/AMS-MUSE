import 'student.dart';

/// A teaching class, e.g. "10-A · Mathematics · 2026-27".
class ClassRoom {
  ClassRoom({
    required this.id,
    required this.name,
    required this.section,
    required this.subject,
    required this.academicYear,
    required this.teacherId,
    required this.status,
    this.studentCount = 0,
    this.students = const [],
  });

  final int id;
  final String name;
  final String section;
  final String subject;
  final String academicYear;
  final int teacherId;
  final String status;
  final int studentCount;
  final List<Student> students;

  bool get isActive => status == 'active';

  String get displayName => '$name · $section';

  factory ClassRoom.fromJson(Map<String, dynamic> json) => ClassRoom(
        id: json['id'] as int,
        name: json['name'] as String,
        section: json['section'] as String,
        subject: json['subject'] as String,
        academicYear: (json['academic_year'] ?? '') as String,
        teacherId: (json['teacher_id'] ?? 0) as int,
        status: (json['status'] ?? 'active') as String,
        studentCount: (json['student_count'] ?? 0) as int,
        students: (json['students'] as List<dynamic>?)
                ?.map((e) => Student.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'section': section,
        'subject': subject,
        'academic_year': academicYear,
      };
}
