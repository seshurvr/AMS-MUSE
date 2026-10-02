import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/class_provider.dart';
import '../../providers/report_provider.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

/// Class attendance report: totals + per-student table.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int? _classId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = context.read<ClassProvider>();
      if (classes.classes.isEmpty) classes.load();
    });
  }

  void _load() {
    if (_classId == null) return;
    context
        .read<ReportProvider>()
        .load(classId: _classId!, from: _from, to: _to);
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>();
    final reports = context.watch<ReportProvider>();
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<int>(
                    initialValue: _classId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: classes.visible
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                  '${c.name} ${c.section} — ${c.subject}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _load();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                      _from == null ? 'From' : dateFmt.format(_from!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _from ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _from = picked);
                      _load();
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label:
                      Text(_to == null ? 'To' : dateFmt.format(_to!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _to ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _to = picked);
                      _load();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _body(reports)),
          ],
        ),
      ),
    );
  }

  Widget _body(ReportProvider reports) {
    if (_classId == null) {
      return const EmptyView(
        message: 'Select a class to view its attendance report.',
        icon: Icons.bar_chart_outlined,
      );
    }
    if (reports.loading && reports.summary == null) {
      return const LoadingView(message: 'Loading report…');
    }
    if (reports.error != null && reports.summary == null) {
      return ErrorView(message: reports.error!, onRetry: _load);
    }
    final summary = reports.summary;
    if (summary == null) {
      return const EmptyView(
          message: 'No report data.', icon: Icons.bar_chart_outlined);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _total('Sessions',
                      '${summary.totals.totalSessions}'),
                  _total('Students',
                      '${summary.totals.totalStudents}'),
                  _total('Avg attendance',
                      '${summary.totals.avgAttendancePercentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Roll')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Sessions'), numeric: true),
                  DataColumn(label: Text('Present'), numeric: true),
                  DataColumn(label: Text('Absent'), numeric: true),
                  DataColumn(label: Text('Excused'), numeric: true),
                  DataColumn(label: Text('Review'), numeric: true),
                  DataColumn(label: Text('%'), numeric: true),
                ],
                rows: summary.students
                    .map((s) => DataRow(cells: [
                          DataCell(Text(s.rollNumber)),
                          DataCell(Text(s.name)),
                          DataCell(Text('${s.totalSessions}')),
                          DataCell(Text('${s.present}')),
                          DataCell(Text('${s.absent}')),
                          DataCell(Text('${s.excused}')),
                          DataCell(Text('${s.needsReview}')),
                          DataCell(Text(
                              '${s.attendancePercentage.toStringAsFixed(1)}%')),
                        ]))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Attendance % = present ÷ (present + absent + excused) × 100. '
            '“Needs review” is never counted as absent.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _total(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
