import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/networking/api_exception.dart';
import '../core/utils/file_download.dart';
import '../models/student.dart';
import '../services/student_service.dart';

/// Students of the currently selected class.
class StudentProvider extends ChangeNotifier {
  StudentProvider(this._service);

  final StudentService _service;

  int? _classId;
  List<Student> _students = [];
  bool _loading = false;
  String? _error;
  String? _notice;

  int? get classId => _classId;
  List<Student> get students => _students;
  bool get loading => _loading;
  String? get error => _error;
  String? get notice => _notice;

  List<Student> get active => _students.where((s) => s.isActive).toList();

  Future<void> load(int classId) async {
    _classId = classId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _students = await _service.listForClass(classId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load students.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> create(Student student) async {
    try {
      await _service.create(student);
      await load(student.classId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> patch) async {
    try {
      await _service.update(id, patch);
      if (_classId != null) await load(_classId!);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> archive(int id) async {
    try {
      await _service.archive(id);
      if (_classId != null) await load(_classId!);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<CsvImportResult?> importCsv(Uint8List bytes, String filename) async {
    if (_classId == null) return null;
    try {
      final result = await _service.importCsv(_classId!, bytes, filename);
      await load(_classId!);
      _notice =
          'Imported ${result.imported}, skipped ${result.skipped}.';
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> exportCsv() async {
    if (_classId == null) return;
    try {
      final bytes = await _service.exportCsv(_classId!);
      final where = await saveDownloadedFile(bytes, 'students.csv');
      _notice = 'Students exported to $where.';
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
}
