import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/class_room.dart';
import '../../providers/class_provider.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

/// Class detail: info, student roster, quick actions.
class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final int classId;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  ClassRoom? _classroom;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final detail =
        await context.read<ClassProvider>().detail(widget.classId);
    if (!mounted) return;
    setState(() {
      _classroom = detail;
      _loading = false;
      _error = detail == null ? 'Could not load the class.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class detail')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _content(_classroom!),
    );
  }

  Widget _content(ClassRoom c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c.name} · ${c.section}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${c.subject} · ${c.academicYear}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed(
                            RouteNames.takeAttendance),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take attendance'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Students (${c.students.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (c.students.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No students in this class yet.'),
              ),
            )
          else
            ...c.students.map((s) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(s.name.isNotEmpty ? s.name[0] : '?')),
                    title: Text(s.name),
                    subtitle: Text(
                        'Roll ${s.rollNumber} · ID ${s.studentId}'),
                  ),
                )),
        ],
      ),
    );
  }
}
