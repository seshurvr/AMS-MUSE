/// A student enrolled in a class.
class Student {
  Student({
    required this.id,
    required this.studentId,
    required this.rollNumber,
    required this.name,
    required this.classId,
    required this.status,
    this.email,
  });

  final int id;
  final String studentId;
  final String rollNumber;
  final String name;
  final int classId;
  final String status;
  final String? email;

  bool get isActive => status == 'active';

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as int,
        studentId: json['student_id'] as String,
        rollNumber: json['roll_number'] as String,
        name: json['name'] as String,
        classId: json['class_id'] as int,
        status: (json['status'] ?? 'active') as String,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'class_id': classId,
        'student_id': studentId,
        'roll_number': rollNumber,
        'name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
      };
}

/// Result of the CSV bulk-import endpoint.
class CsvImportResult {
  CsvImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  final int imported;
  final int skipped;
  final List<CsvImportError> errors;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) =>
      CsvImportResult(
        imported: (json['imported'] ?? 0) as int,
        skipped: (json['skipped'] ?? 0) as int,
        errors: (json['errors'] as List<dynamic>? ?? [])
            .map((e) => CsvImportError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CsvImportError {
  CsvImportError({required this.row, required this.message});

  final int row;
  final String message;

  factory CsvImportError.fromJson(Map<String, dynamic> json) => CsvImportError(
        row: (json['row'] ?? 0) as int,
        message: (json['message'] ?? '') as String,
      );
}
