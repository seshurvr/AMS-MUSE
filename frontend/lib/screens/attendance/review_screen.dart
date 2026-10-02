import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/attendance_record.dart';
import '../../models/attendance_session.dart';
import '../../models/detection.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/image_review/detection_overlay.dart';

/// Teacher review of recognition results.
///
/// LEFT (wide) / TOP (narrow): the classroom photo with tappable bounding
/// boxes. RIGHT / BOTTOM: per-detection assignment controls and the
/// attendance summary. Nothing here is final until the teacher confirms.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<AttendanceProvider>();
    final ok = await provider.loadSession(widget.sessionId);
    if (!ok || !mounted) return;
    final classId = provider.detail!.session.classId;
    final students = context.read<StudentProvider>();
    await students.load(classId);
    if (!mounted) return;
    provider.ensureLocalRecords(students.students);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review recognition'),
        actions: [
          IconButton(
            tooltip: 'Save progress',
            icon: const Icon(Icons.save_outlined),
            onPressed: provider.saving ? null : () => _save(provider),
          ),
        ],
      ),
      body: _body(provider),
      bottomNavigationBar: _actionBar(provider),
    );
  }

  Widget _body(AttendanceProvider provider) {
    if (provider.loading && provider.detail == null) {
      return const LoadingView(message: 'Loading session…');
    }
    if (provider.error != null && provider.detail == null) {
      return ErrorView(message: provider.error!, onRetry: _load);
    }
    final detail = provider.detail;
    if (detail == null) {
      return const EmptyView(
          message: 'Session not found.', icon: Icons.search_off);
    }
    if (detail.session.isFinalized) {
      return const EmptyView(
        message:
            'This session is finalized and can no longer be edited.',
        icon: Icons.lock_outlined,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final photo = _photoPanel(provider, detail);
        final panel = _reviewPanel(provider, detail);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: photo),
              Expanded(flex: 2, child: panel),
            ],
          );
        }
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.45,
              ),
              child: photo,
            ),
            Expanded(child: panel),
          ],
        );
      },
    );
  }

  Widget _photoPanel(
      AttendanceProvider provider, SessionDetail detail) {
    final bytes = provider.imageBytes;
    final session = detail.session;
    if (bytes == null ||
        session.imageWidth == null ||
        session.imageHeight == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Classroom photo is not available. You can still review the detection list.'),
          ),
        ),
      );
    }
    final assignedNames = <int, String>{};
    for (final r in provider.records) {
      if (r.detectionId != null) {
        assignedNames[r.detectionId!] = r.studentName;
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: DetectionOverlay(
          imageBytes: bytes,
          imageWidth: session.imageWidth!,
          imageHeight: session.imageHeight!,
          detections: detail.detections,
          assignedNames: assignedNames,
          selectedDetectionId: provider.selectedDetectionId,
          onSelectDetection: provider.selectDetection,
        ),
      ),
    );
  }

  Widget _reviewPanel(
      AttendanceProvider provider, SessionDetail detail) {
    final summary = provider.localSummary();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(summary: summary, detected: detail.detections.length),
          const SizedBox(height: 16),
          Text('Detections (${detail.detections.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (detail.detections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No faces detected. Mark students present manually below.'),
              ),
            )
          else
            ...detail.detections.map(
                (d) => _DetectionCard(detection: d, onError: _showError)),
          const SizedBox(height: 16),
          Text('Needs review (${summary.needsReview})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...provider.records
              .where((r) => r.status == AttendanceStatus.needsReview)
              .map((r) => _NeedsReviewRow(record: r)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _actionBar(AttendanceProvider provider) {
    final detail = provider.detail;
    if (detail == null || detail.session.isFinalized) {
      return const SizedBox.shrink();
    }
    final summary = provider.localSummary();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    provider.saving ? null : () => _save(provider),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save progress'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: provider.saving
                    ? null
                    : () => _goFinalize(provider, summary),
                icon: const Icon(Icons.check),
                label: const Text('Review & finalize'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AttendanceProvider provider) async {
    final ok = await provider.saveRecords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Review progress saved.'
              : (provider.error ?? 'Save failed.'))),
    );
  }

  Future<void> _goFinalize(
      AttendanceProvider provider, SessionSummary summary) async {
    if (summary.needsReview > 0) {
      final proceed = await showConfirmDialog(
        context,
        title: 'Unresolved records',
        message:
            '${summary.needsReview} student(s) still need review. They will stay as “Needs review” — they will NOT be counted as absent. Continue to final confirmation?',
        confirmLabel: 'Continue',
      );
      if (!proceed) return;
    }
    if (!mounted) return;
    await provider.saveRecords();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamed(RouteNames.confirmSession(widget.sessionId));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.detected});

  final SessionSummary summary;
  final int detected;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total students', '${summary.total}'),
      ('Detected faces', '$detected'),
      ('Present', '${summary.present}'),
      ('Absent', '${summary.absent}'),
      ('Excused', '${summary.excused}'),
      ('Needs review', '${summary.needsReview}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: items
                  .map((e) => SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                            Text(e.$1,
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard(
      {required this.detection, required this.onError});

  final Detection detection;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final selected = provider.selectedDetectionId == detection.id;
    final record = provider.recordForDetection(detection.id);
    final students = provider.records
        .map((r) => (id: r.studentDbId, name: r.studentName))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => provider.selectDetection(detection.id),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Person ${detection.detectionNumber}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(
                        '${(detection.confidence * 100).toStringAsFixed(0)}%'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(record == null
                        ? 'Unassigned'
                        : 'Matched'),
                    backgroundColor: record == null
                        ? Theme.of(context)
                            .colorScheme
                            .errorContainer
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: record?.studentDbId,
              decoration: const InputDecoration(
                labelText: 'Student',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('— Unassigned —'),
                ),
                ...students.map((s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (studentDbId) {
                final ok = provider.assignDetection(
                  detectionId: detection.id,
                  studentDbId: studentDbId,
                );
                if (!ok && provider.error != null) {
                  onError(provider.error!);
                }
              },
            ),
            if (record != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => provider.assignDetection(
                      detectionId: detection.id),
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: const Text('Mark unknown'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeedsReviewRow extends StatelessWidget {
  const _NeedsReviewRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AttendanceProvider>();
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.studentName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  Text('Roll ${record.rollNumber}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            _MarkButton(
              label: 'Present',
              color: Colors.green,
              onPressed: () => provider.markStudent(
                  record.studentDbId, AttendanceStatus.present),
            ),
            _MarkButton(
              label: 'Absent',
              color: Colors.red,
              onPressed: () => provider.markStudent(
                  record.studentDbId, AttendanceStatus.absent),
            ),
            _MarkButton(
              label: 'Excused',
              color: Colors.orange,
              onPressed: () => provider.markStudent(
                  record.studentDbId, AttendanceStatus.excused),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton(
      {required this.label,
      required this.color,
      required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
