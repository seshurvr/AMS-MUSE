import 'package:flutter/foundation.dart';

import '../core/networking/api_exception.dart';
import '../models/report.dart';
import '../services/report_service.dart';

/// Attendance reports for a class + date range.
class ReportProvider extends ChangeNotifier {
  ReportProvider(this._service);

  final ReportService _service;

  ReportSummary? _summary;
  bool _loading = false;
  String? _error;

  ReportSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load(
      {required int classId, DateTime? from, DateTime? to}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _summary = await _service.summary(classId: classId, from: from, to: to);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the report.';
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _summary = null;
    _error = null;
    notifyListeners();
  }
}
