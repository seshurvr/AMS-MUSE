import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/attendance_session.dart';
import '../../providers/dashboard_provider.dart';
import '../shell/app_shell.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/status_badge.dart';

/// Dashboard: stat cards, quick actions, today's sessions, recent history.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    if (dash.loading && dash.classes.isEmpty) {
      return const LoadingView(message: 'Loading dashboard…');
    }
    if (dash.error != null && dash.classes.isEmpty) {
      return ErrorView(
        message: dash.error!,
        onRetry: () => dash.load(),
      );
    }

    final dateFmt = DateFormat('dd MMM yyyy');
    return RefreshIndicator(
      onRefresh: () => dash.load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                        ? 2
                        : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    StatCard(
                      label: 'Total classes',
                      value: '${dash.totalClasses}',
                      icon: Icons.class_outlined,
                    ),
                    StatCard(
                      label: 'Total students',
                      value: '${dash.totalStudents}',
                      icon: Icons.people_outlined,
                      color: Colors.teal,
                    ),
                    StatCard(
                      label: 'Present today',
                      value: '${dash.presentToday}',
                      icon: Icons.check_circle_outlined,
                      color: Colors.green,
                    ),
                    StatCard(
                      label: 'Need review',
                      value: '${dash.sessionsNeedingReview}',
                      icon: Icons.rate_review_outlined,
                      color: Colors.orange,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Quick actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(RouteNames.takeAttendance),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take attendance'),
                ),
                OutlinedButton.icon(
                  onPressed: () => AppShell.goToTab(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Create class'),
                ),
                OutlinedButton.icon(
                  onPressed: () => AppShell.goToTab(2),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add student'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Today's sessions",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (dash.todaySessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No attendance sessions recorded today yet.'),
                ),
              )
            else
              ...dash.todaySessions.map((s) => Card(
                    child: ListTile(
                      leading: SessionStatusBadge(
                          status: sessionStatusFrom(s.status)),
                      title: Text(
                          '${s.className} ${s.section} · ${s.subject}'),
                      subtitle: Text(
                          '${dateFmt.format(s.date)} · Present ${s.present}/${s.total}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context)
                          .pushNamed(RouteNames.sessionDetail(s.id)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
