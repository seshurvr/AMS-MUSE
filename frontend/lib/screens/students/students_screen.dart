import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../models/class_room.dart';
import '../../models/student.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

/// Students tab: pick a class, manage its roster, CSV import/export.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  int? _classId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final classes = context.read<ClassProvider>();
      if (classes.classes.isEmpty) await classes.load();
      if (mounted && classes.visible.isNotEmpty) {
        setState(() => _classId = classes.visible.first.id);
        context.read<StudentProvider>().load(_classId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>();
    final students = context.watch<StudentProvider>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _classId,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
              ),
              items: classes.visible
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} · ${c.section} — ${c.subject}'),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() => _classId = id);
                context.read<StudentProvider>().load(id);
              },
            ),
            const SizedBox(height: 12),
            if (students.notice != null)
              _NoticeBar(
                message: students.notice!,
                onDismiss: () => students.clearNotice(),
              ),
            Expanded(child: _body(students)),
          ],
        ),
      ),
      floatingActionButton: _classId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showStudentDialog(context, _classId!),
              icon: const Icon(Icons.add),
              label: const Text('Add student'),
            ),
    );
  }

  Widget _body(StudentProvider students) {
    if (_classId == null) {
      return const EmptyView(
        message: 'Create a class first, then add students to it.',
        icon: Icons.people_outlined,
      );
    }
    if (students.loading && students.students.isEmpty) {
      return const LoadingView(message: 'Loading students…');
    }
    if (students.error != null && students.students.isEmpty) {
      return ErrorView(
        message: students.error!,
        onRetry: () => students.load(_classId!),
      );
    }
    final list = students.active;
    if (list.isEmpty) {
      return EmptyView(
        message: 'No students yet. Add them one by one or import a CSV.',
        icon: Icons.people_outlined,
        action: Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _showStudentDialog(context, _classId!),
              icon: const Icon(Icons.add),
              label: const Text('Add student'),
            ),
            OutlinedButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => students.load(_classId!),
      child: ListView.builder(
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _importCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => students.exportCsv(),
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            );
          }
          final s = list[i - 1];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                  child: Text(s.name.isNotEmpty ? s.name[0] : '?')),
              title: Text(s.name),
              subtitle: Text('Roll ${s.rollNumber} · ID ${s.studentId}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showStudentDialog(context, _classId!, existing: s);
                  } else if (value == 'archive') {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Archive student?',
                      message: '“${s.name}” will be hidden from the roster.',
                      confirmLabel: 'Archive',
                    );
                    if (ok && context.mounted) {
                      await students.archive(s.id);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;
    final importResult = await context
        .read<StudentProvider>()
        .importCsv(Uint8List.fromList(bytes), 'students.csv');
    if (importResult != null &&
        importResult.errors.isNotEmpty &&
        mounted) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import errors'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: importResult.errors
                  .map((e) => ListTile(
                        dense: true,
                        leading: Text('Row ${e.row}'),
                        title: Text(e.message),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showStudentDialog(BuildContext context, int classId,
      {Student? existing}) async {
    final formKey = GlobalKey<FormState>();
    final studentId = TextEditingController(text: existing?.studentId);
    final roll = TextEditingController(text: existing?.rollNumber);
    final name = TextEditingController(text: existing?.name);
    final email = TextEditingController(text: existing?.email ?? '');
    var ok = false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add student' : 'Edit student'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                    controller: studentId,
                    label: 'Student ID',
                    validator: (v) =>
                        Validators.required(v, 'Student ID')),
                AppTextField(
                    controller: roll,
                    label: 'Roll number',
                    validator: (v) =>
                        Validators.required(v, 'Roll number')),
                AppTextField(
                    controller: name,
                    label: 'Full name',
                    validator: (v) => Validators.required(v, 'Name')),
                AppTextField(
                    controller: email,
                    label: 'Email (optional)',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final provider = context.read<StudentProvider>();
              if (existing == null) {
                ok = await provider.create(Student(
                  id: 0,
                  studentId: studentId.text,
                  rollNumber: roll.text,
                  name: name.text,
                  classId: classId,
                  status: 'active',
                  email: email.text.trim().isEmpty
                      ? null
                      : email.text.trim(),
                ));
              } else {
                ok = await provider.update(existing.id, {
                  'student_id': studentId.text.trim(),
                  'roll_number': roll.text.trim(),
                  'name': name.text.trim(),
                  if (email.text.trim().isNotEmpty)
                    'email': email.text.trim(),
                });
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    studentId.dispose();
    roll.dispose();
    name.dispose();
    email.dispose();
    if (!ok && mounted) {
      final error = context.read<StudentProvider>().error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        dense: true,
        title: Text(message),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onDismiss,
        ),
      ),
    );
  }
}
