import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/attendance_session.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/common/loading_view.dart';

/// Final confirmation before attendance is saved.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
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
      appBar: AppBar(title: const Text('Confirm attendance')),
      body: provider.loading && detail == null
          ? const LoadingView()
          : detail == null
              ? const Center(child: Text('Session not found.'))
              : _content(provider, detail.session),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to review'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: provider.saving
                            ? null
                            : () => _confirm(provider),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm & save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _content(
      AttendanceProvider provider, AttendanceSession session) {
    final summary = provider.localSummary();
    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    final rows = [
      ('Class', 'ID ${session.classId}'),
      ('Date', dateFmt.format(session.date)),
      ('Time', session.shortTime),
      ('Subject', session.subject),
      ('Total students', '${summary.total}'),
      ('Detected faces', '${summary.detected}'),
      ('Present', '${summary.present}'),
      ('Absent', '${summary.absent}'),
      ('Excused', '${summary.excused}'),
      ('Needs review', '${summary.needsReview}'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please confirm',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Recognition results are suggestions. Only what you confirm here is saved.',
              ),
              const SizedBox(height: 16),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(r.$1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium)),
                        Text(r.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const Divider(),
                Text('Notes: ${session.notes}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(AttendanceProvider provider) async {
    final ok = await provider.finalize();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Attendance saved successfully.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.sessionDetail(widget.sessionId),
        (route) => route.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(provider.error ?? 'Could not save attendance.')),
      );
    }
  }
}
