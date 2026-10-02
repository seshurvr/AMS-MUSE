import 'package:flutter/foundation.dart';

import '../models/attendance_session.dart';
import '../models/class_room.dart';
import '../services/attendance_service.dart';
import '../services/class_service.dart';

/// Aggregates the dashboard cards.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._classes, this._attendance);

  final ClassService _classes;
  final AttendanceService _attendance;

  bool _loading = false;
  String? _error;
  List<ClassRoom> _classesList = [];
  List<HistoryItem> _todaySessions = [];

  bool get loading => _loading;
  String? get error => _error;
  List<ClassRoom> get classes => _classesList;
  List<HistoryItem> get todaySessions => _todaySessions;

  int get totalClasses => _classesList.length;
  int get totalStudents =>
      _classesList.fold(0, (sum, c) => sum + c.studentCount);
  int get sessionsNeedingReview =>
      _todaySessions.where((s) => s.needsReview > 0).length;
  int get presentToday =>
      _todaySessions.fold(0, (sum, s) => sum + s.present);
  int get absentToday =>
      _todaySessions.fold(0, (sum, s) => sum + s.absent);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _classesList = await _classes.list();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      _todaySessions = await _attendance.history(from: start, to: start);
    } catch (_) {
      _error = 'Could not load the dashboard.';
    }
    _loading = false;
    notifyListeners();
  }
}
