import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/networking/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/report_provider.dart';
import 'providers/student_provider.dart';
import 'screens/shell/auth_gate.dart';
import 'services/admin_service.dart';
import 'services/attendance_service.dart';
import 'services/auth_service.dart';
import 'services/class_service.dart';
import 'services/image_service.dart';
import 'services/report_service.dart';
import 'services/storage_service.dart';
import 'services/student_service.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Services are cheap stateless wrappers; a single instance each is shared
    // through Provider for the whole app lifetime.
    final storage = StorageService();
    final api = ApiClient(
      tokenProvider: storage.getToken,
      baseUrlProvider: storage.baseUrl,
    );
    final authService = AuthService(api, storage);
    final classService = ClassService(api);
    final studentService = StudentService(api);
    final attendanceService = AttendanceService(api);
    final reportService = ReportService(api);

    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<ApiClient>.value(value: api),
        Provider<AuthService>.value(value: authService),
        Provider<ClassService>.value(value: classService),
        Provider<StudentService>.value(value: studentService),
        Provider<AttendanceService>.value(value: attendanceService),
        Provider<ReportService>.value(value: reportService),
        Provider<ImageService>(create: (_) => ImageService()),
        Provider<AdminService>(create: (_) => AdminService(api)),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService, storage)..bootstrap(),
        ),
        ChangeNotifierProvider<ClassProvider>(
          create: (_) => ClassProvider(classService),
        ),
        ChangeNotifierProvider<StudentProvider>(
          create: (_) => StudentProvider(studentService),
        ),
        ChangeNotifierProvider<AttendanceProvider>(
          create: (_) => AttendanceProvider(attendanceService),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(classService, attendanceService),
        ),
        ChangeNotifierProvider<ReportProvider>(
          create: (_) => ReportProvider(reportService),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Any 401 anywhere drops the session, returns to the first route,
          // and AuthGate switches home to the login screen.
          api.onUnauthorized = () {
            context.read<AuthProvider>().handleUnauthorized();
            Navigator.of(context).popUntil((route) => route.isFirst);
          };
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
