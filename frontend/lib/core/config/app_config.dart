/// App-wide configuration.
///
/// The API base URL is baked in at build time with `--dart-define`:
///
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///
/// On Android the teacher can also override it at runtime in Settings
/// (useful when the server runs on a LAN address like http://192.168.1.5:8000).
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String appName = 'Classroom Attendance';
  static const String appVersion = '1.0.0';

  /// Demo credentials shown on the login screen (dev only, seeded by backend).
  static const String demoTeacher = 'teacher@demo.local';
  static const String demoPassword = 'Demo1234!';
}
