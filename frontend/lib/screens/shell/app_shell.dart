import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../attendance/history_screen.dart';
import '../attendance/take_attendance_screen.dart';
import '../classes/classes_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../students/students_screen.dart';

/// Responsive app shell: NavigationRail on wide screens (web/desktop),
/// BottomNavigationBar on narrow screens (Android).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static final GlobalKey<_AppShellState> navKey = GlobalKey<_AppShellState>();

  /// Switch the shell tab from anywhere (e.g. dashboard quick actions).
  static void goToTab(int index) => navKey.currentState?._go(index);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

final List<_NavItem> _items = [
  _NavItem('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
  _NavItem('Classes', Icons.class_outlined, ClassesScreen()),
  _NavItem('Students', Icons.people_outlined, StudentsScreen()),
  _NavItem('Take Attendance', Icons.camera_alt_outlined, TakeAttendanceScreen()),
  _NavItem('History', Icons.history_outlined, HistoryScreen()),
  _NavItem('Reports', Icons.bar_chart_outlined, ReportsScreen()),
  _NavItem('Settings', Icons.settings_outlined, SettingsScreen()),
];

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _go(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    if (index == 3) {
      // "Take Attendance" tab: start the wizard fresh every time it opens.
      context.read<AttendanceProvider>().clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final user = context.watch<AuthProvider>().user;

    final body = IndexedStack(index: _index, children: _items.map((e) => e.page).toList());

    return Scaffold(
      appBar: AppBar(
        title: Text(_items[_index].label),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: CircleAvatar(
                  child: Text(user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?'),
                ),
                label: Text(user.username),
              ),
            ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              // Drop back to the shell root; AuthGate swaps home to login.
              if (context.mounted) {
                Navigator.of(context)
                    .popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: _items
                  .map((e) => NavigationRailDestination(
                        icon: Icon(e.icon),
                        label: Text(e.label),
                      ))
                  .toList(),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              destinations: _items
                  .take(5)
                  .map((e) => NavigationDestination(
                        icon: Icon(e.icon),
                        label: e.label,
                      ))
                  .toList(),
            ),
    );
  }
}
