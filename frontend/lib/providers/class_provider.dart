import 'package:flutter/foundation.dart';

import '../core/networking/api_exception.dart';
import '../models/class_room.dart';
import '../services/class_service.dart';

/// Class list + CRUD for the Classes screens.
class ClassProvider extends ChangeNotifier {
  ClassProvider(this._service);

  final ClassService _service;

  List<ClassRoom> _classes = [];
  bool _loading = false;
  String? _error;
  String _search = '';

  List<ClassRoom> get classes => _classes;
  bool get loading => _loading;
  String? get error => _error;

  List<ClassRoom> get visible {
    final q = _search.trim().toLowerCase();
    final active = _classes.where((c) => c.isActive).toList();
    if (q.isEmpty) return active;
    return active
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.section.toLowerCase().contains(q) ||
            c.subject.toLowerCase().contains(q))
        .toList();
  }

  List<ClassRoom> get archived =>
      _classes.where((c) => !c.isActive).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _classes = await _service.list();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load classes.';
    }
    _loading = false;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  Future<ClassRoom?> create({
    required String name,
    required String section,
    required String subject,
    required String academicYear,
  }) async {
    try {
      final created = await _service.create(
        name: name,
        section: section,
        subject: subject,
        academicYear: academicYear,
      );
      await load();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateStatus(int id, String status) async {
    try {
      await _service.update(id, status: status);
      await load();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<ClassRoom?> detail(int id) async {
    try {
      return await _service.get(id);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }
}
