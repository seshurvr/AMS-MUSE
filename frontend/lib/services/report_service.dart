import '../core/networking/api_client.dart';
import '../models/report.dart';

/// Attendance reports.
class ReportService {
  ReportService(this._api);

  final ApiClient _api;

  Future<ReportSummary> summary({
    required int classId,
    DateTime? from,
    DateTime? to,
  }) async {
    String? fmt(DateTime? d) => d == null
        ? null
        : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final json = await _api.get('/api/reports/summary', query: {
      'class_id': '$classId',
      if (fmt(from) != null) 'from': fmt(from)!,
      if (fmt(to) != null) 'to': fmt(to)!,
    }) as Map<String, dynamic>;
    return ReportSummary.fromJson(json);
  }
}
