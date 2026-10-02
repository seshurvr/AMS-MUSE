import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/utils/validators.dart';
import '../../providers/class_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

/// Class list with search, create, and archive.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search classes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: provider.setSearch,
            ),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New class'),
      ),
    );
  }

  Widget _body(ClassProvider provider) {
    if (provider.loading && provider.classes.isEmpty) {
      return const LoadingView(message: 'Loading classes…');
    }
    if (provider.error != null && provider.classes.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: () => provider.load(),
      );
    }
    final classes = provider.visible;
    if (classes.isEmpty) {
      return EmptyView(
        message: 'No classes yet. Create your first class to get started.',
        icon: Icons.class_outlined,
        action: FilledButton.icon(
          onPressed: () => _showCreateDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Create class'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: classes.length,
        itemBuilder: (context, i) {
          final c = classes[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(c.name.isNotEmpty ? c.name[0] : '?'),
              ),
              title: Text('${c.name} · ${c.section}'),
              subtitle:
                  Text('${c.subject} · ${c.academicYear} · ${c.studentCount} students'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'archive') {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Archive class?',
                      message:
                          '“${c.name} ${c.section}” will be hidden from the active list.',
                      confirmLabel: 'Archive',
                    );
                    if (ok && context.mounted) {
                      await provider.updateStatus(c.id, 'archived');
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'archive', child: Text('Archive')),
                ],
              ),
              onTap: () => Navigator.of(context)
                  .pushNamed(RouteNames.classDetail(c.id))
                  .then((_) => provider.load()),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final section = TextEditingController();
    final subject = TextEditingController();
    final year = TextEditingController(
        text: '${DateTime.now().year}-${(DateTime.now().year + 1) % 100}');
    var saved = false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create class'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                    controller: name,
                    label: 'Class name',
                    hint: 'e.g. 10',
                    validator: (v) => Validators.required(v, 'Class name')),
                AppTextField(
                    controller: section,
                    label: 'Section',
                    hint: 'e.g. A',
                    validator: (v) => Validators.required(v, 'Section')),
                AppTextField(
                    controller: subject,
                    label: 'Subject',
                    hint: 'e.g. Mathematics',
                    validator: (v) => Validators.required(v, 'Subject')),
                AppTextField(
                    controller: year,
                    label: 'Academic year',
                    hint: 'e.g. 2026-27',
                    validator: (v) =>
                        Validators.required(v, 'Academic year')),
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
              final created = await context.read<ClassProvider>().create(
                    name: name.text,
                    section: section.text,
                    subject: subject.text,
                    academicYear: year.text,
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
                saved = created != null;
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    section.dispose();
    subject.dispose();
    year.dispose();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created.')),
      );
    }
  }
}
