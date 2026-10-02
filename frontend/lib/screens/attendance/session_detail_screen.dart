import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/attendance_session.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_badge.dart';

/// Read-only view of a session: summary, records, exports.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadSession(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final detail = provider.detail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session detail'),
        actions: [
          if (detail != null && !detail.session.isFinalized)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(
                  RouteNames.reviewSession(widget.sessionId)),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Continue review'),
            ),
        ],
      ),
      body: provider.loading && detail == null
          ? const LoadingView()
          : provider.error != null && detail == null
              ? ErrorView(
                  message: provider.error!,
                  onRetry: () => provider.loadSession(widget.sessionId),
                )
              : detail == null
                  ? const Center(child: Text('Session not found.'))
                  : _content(provider, detail.session, detail.summary),
    );
  }

  Widget _content(AttendanceProvider provider, AttendanceSession session,
      SessionSummary summary) {
    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${session.subject} · ${dateFmt.format(session.date)} ${session.shortTime}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SessionStatusBadge(
                          status: session.processingStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _stat('Present', '${summary.present}',
                          Colors.green),
                      _stat('Absent', '${summary.absent}', Colors.red),
                      _stat('Excused', '${summary.excused}',
                          Colors.orange),
                      _stat('Needs review',
                          '${summary.needsReview}', Colors.blueGrey),
                      _stat('Detected', '${summary.detected}',
                          Colors.teal),
                      _stat('Attendance',
                          '${summary.attendancePercentage.toStringAsFixed(1)}%',
                          Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => provider.export(
                            widget.sessionId, 'csv'),
                        icon: const Icon(Icons.download),
                        label: const Text('CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => provider.export(
                            widget.sessionId, 'xlsx'),
                        icon: const Icon(Icons.download),
                        label: const Text('Excel'),
                      ),
                    ],
                  ),
                  if (provider.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(provider.notice!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Records (${provider.records.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...provider.records.map((r) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(r.studentName.isNotEmpty
                          ? r.studentName[0]
                          : '?')),
                  title: Text(r.studentName),
                  subtitle:
                      Text('Roll ${r.rollNumber} · ID ${r.studentCode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.manuallyConfirmed)
                        const Tooltip(
                          message: 'Manually confirmed by teacher',
                          child: Icon(Icons.verified_outlined,
                              size: 18),
                        ),
                      const SizedBox(width: 8),
                      AttendanceStatusBadge(status: r.status),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
