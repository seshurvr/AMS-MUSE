import 'package:classroom_attendance/core/networking/api_client.dart';
import 'package:classroom_attendance/providers/auth_provider.dart';
import 'package:classroom_attendance/screens/auth/login_screen.dart';
import 'package:classroom_attendance/services/auth_service.dart';
import 'package:classroom_attendance/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app() {
    final storage = StorageService();
    final api = ApiClient(
      tokenProvider: () async => null,
      baseUrlProvider: () => 'http://localhost:8000',
    );
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(AuthService(api, storage), storage),
        ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('login screen renders branding and fields',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Classroom Attendance'), findsOneWidget);
    expect(find.text('Sign in to take attendance'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username or email'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });

  testWidgets('empty submit shows validation errors', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('server settings section expands', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Server URL'),
        findsNothing);
    await tester.tap(find.text('Server settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Server URL'),
        findsOneWidget);
  });
}
