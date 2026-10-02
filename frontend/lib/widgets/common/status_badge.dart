import 'package:flutter/material.dart';

import '../../models/attendance_session.dart';

/// Colored pill for attendance statuses.
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('Present', Colors.green),
      AttendanceStatus.absent => ('Absent', Colors.red),
      AttendanceStatus.excused => ('Excused', Colors.orange),
      AttendanceStatus.needsReview => ('Needs review', Colors.blueGrey),
    };
    return _Badge(label: label, color: color);
  }
}

/// Colored pill for session processing states.
class SessionStatusBadge extends StatelessWidget {
  const SessionStatusBadge({super.key, required this.status});

  final SessionProcessingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SessionProcessingStatus.uploaded => ('Uploaded', Colors.blueGrey),
      SessionProcessingStatus.processing => ('Processing', Colors.blue),
      SessionProcessingStatus.processed => ('Processed', Colors.teal),
      SessionProcessingStatus.failed => ('Failed', Colors.red),
      SessionProcessingStatus.finalized => ('Finalized', Colors.green),
    };
    return _Badge(label: label, color: color);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color is MaterialColor ? color.shade800 : color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
