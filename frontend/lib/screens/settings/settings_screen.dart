import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/validators.dart';
import '../../models/report.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_view.dart';

/// Settings: profile, server URL, password change, admin tools, about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrl = TextEditingController();
  List<AppUser>? _users;
  List<AuditLogEntry>? _audit;
  bool _loadingAdmin = false;

  @override
  void initState() {
    super.initState();
    _serverUrl.text = context.read<StorageService>().baseUrl();
    final user = context.read<AuthProvider>().user;
    if (user != null && user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdmin());
    }
  }

  @override
  void dispose() {
    _serverUrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    setState(() => _loadingAdmin = true);
    try {
      final admin = context.read<AdminService>();
      final users = await admin.listUsers();
      final audit = await admin.auditLogs(limit: 50);
      if (!mounted) return;
      setState(() {
        _users = users;
        _audit = audit;
      });
    } catch (_) {
      // Admin tools are best-effort; the rest of settings still works.
    }
    if (mounted) setState(() => _loadingAdmin = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?')),
                  title: Text(user.username),
                  subtitle: Text('${user.email} · ${user.role}'),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Server connection',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _serverUrl,
                      label: 'Server URL',
                      hint: 'http://localhost:8000  or  /api',
                      prefixIcon: Icons.dns,
                      keyboardType: TextInputType.url,
                    ),
                    FilledButton(
                      onPressed: () async {
                        await context
                            .read<StorageService>()
                            .setBaseUrlOverride(_serverUrl.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Server URL saved. It applies to new requests.')),
                          );
                        }
                      },
                      child: const Text('Save server URL'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_reset_outlined),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPasswordDialog(context),
              ),
            ),
            if (user != null && user.isAdmin) ...[
              const SizedBox(height: 12),
              _AdminPanel(
                users: _users,
                audit: _audit,
                loading: _loadingAdmin,
                onUserCreated: _loadAdmin,
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        '${AppConfig.appName} v${AppConfig.appVersion}'),
                    const SizedBox(height: 4),
                    Text(
                      'Face recognition suggests matches; the teacher always reviews and confirms attendance. Recognition is never 100% accurate.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                  controller: current,
                  label: 'Current password',
                  obscureText: true,
                  validator: (v) =>
                      Validators.required(v, 'Current password')),
              AppTextField(
                  controller: next,
                  label: 'New password',
                  obscureText: true,
                  validator: (v) =>
                      Validators.minLength(v ?? '', 8, 'New password')),
            ],
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
              try {
                await context.read<AuthService>().changePassword(
                    current.text, next.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Password changed.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel(
      {required this.users,
      required this.audit,
      required this.loading,
      required this.onUserCreated});

  final List<AppUser>? users;
  final List<AuditLogEntry>? audit;
  final bool loading;
  final VoidCallback onUserCreated;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Administration',
                      style:
                          Theme.of(context).textTheme.titleMedium),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _showCreateUserDialog(context, onUserCreated),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('New user'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const LoadingView(message: 'Loading admin data…')
            else ...[
              Text('Users (${users?.length ?? 0})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...(users ?? []).map((u) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(u.username),
                    subtitle: Text(u.email),
                    trailing: Chip(label: Text(u.role)),
                  )),
              const Divider(),
              Text('Recent audit log',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...(audit ?? []).take(10).map((a) => ListTile(
                    dense: true,
                    title: Text(a.action),
                    subtitle: Text(
                        '${a.username ?? 'system'} · ${a.recordType ?? ''} ${a.recordId ?? ''}'),
                    trailing: Text(
                      '${a.timestamp.hour.toString().padLeft(2, '0')}:${a.timestamp.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _showCreateUserDialog(
      BuildContext context, VoidCallback onCreated) async {
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    String role = 'teacher';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create user'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                    controller: username,
                    label: 'Username',
                    validator: (v) =>
                        Validators.minLength(v ?? '', 3, 'Username')),
                AppTextField(
                    controller: email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        Validators.required(v, 'Email')),
                AppTextField(
                    controller: password,
                    label: 'Password',
                    obscureText: true,
                    validator: (v) =>
                        Validators.minLength(v ?? '', 8, 'Password')),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'teacher',
                        child: Text('Teacher')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) =>
                      setState(() => role = v ?? 'teacher'),
                ),
              ],
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
                try {
                  await context.read<AdminService>().createUser(
                        username: username.text,
                        email: email.text,
                        password: password.text,
                        role: role,
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    onCreated();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    email.dispose();
    password.dispose();
  }
}
