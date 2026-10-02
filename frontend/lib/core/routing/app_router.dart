import 'package:flutter/material.dart';

import '../screens/attendance/confirm_screen.dart';
import '../screens/attendance/review_screen.dart';
import '../screens/attendance/session_detail_screen.dart';
import '../screens/attendance/take_attendance_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/classes/class_detail_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/shell/auth_gate.dart';

/// Named routes used with [Navigator.pushNamed].
class RouteNames {
  static const login = '/login';
  static const home = '/';
  static String classDetail(int id) => '/classes/$id';
  static const takeAttendance = '/attendance/new';
  static String reviewSession(int id) => '/sessions/$id/review';
  static String confirmSession(int id) => '/sessions/$id/confirm';
  static String sessionDetail(int id) => '/sessions/$id';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;

    Widget page;
    if (uri.path == RouteNames.login) {
      page = const LoginScreen();
    } else if (segments.length == 2 && segments[0] == 'classes') {
      final id = int.tryParse(segments[1]);
      page = id == null ? const AuthGate() : ClassDetailScreen(classId: id);
    } else if (uri.path == RouteNames.takeAttendance) {
      page = const TakeAttendanceScreen();
    } else if (segments.length == 3 &&
        segments[0] == 'sessions' &&
        segments[2] == 'review') {
      final id = int.tryParse(segments[1]);
      page = id == null ? const AuthGate() : ReviewScreen(sessionId: id);
    } else if (segments.length == 3 &&
        segments[0] == 'sessions' &&
        segments[2] == 'confirm') {
      final id = int.tryParse(segments[1]);
      page = id == null ? const AuthGate() : ConfirmScreen(sessionId: id);
    } else if (segments.length == 2 && segments[0] == 'sessions') {
      final id = int.tryParse(segments[1]);
      page = id == null ? const AuthGate() : SessionDetailScreen(sessionId: id);
    } else {
      page = const AuthGate();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
