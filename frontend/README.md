# Frontend — Flutter (Android + Web)

One Dart codebase for Android and Web/Desktop. Material 3, responsive
(bottom navigation on phones, navigation rail on wide screens).

## Layout

```
lib/
  main.dart                 # bootstrap: services → providers → MaterialApp
  core/
    config/app_config.dart  # API_BASE_URL via --dart-define
    networking/             # ApiClient (auth headers, error mapping, 401 handling)
    routing/app_router.dart # named routes
    theme/app_theme.dart    # Material 3 seed-color theme
    utils/                  # validators, file_download (conditional web/io)
  models/                   # typed API models, hand-written fromJson/toJson
  services/                 # thin typed wrappers over ApiClient
  providers/                # ChangeNotifier state per feature
  screens/                  # auth, shell, dashboard, classes, students,
                            #   attendance (wizard/review/confirm/history/detail),
                            #   reports, settings
  widgets/
    common/                 # loading/error/empty, badges, dialogs, stat cards
    image_review/           # detection_overlay.dart (tappable boxes, zoom/pan)
test/
  models_test.dart          # JSON contract tests against the backend shapes
  attendance_provider_test.dart  # review logic: backfill, duplicate guard…
  login_test.dart           # login UI validation
```

## Run

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

## Build

```bash
# Web (relative /api so nginx can proxy it)
flutter build web --release --dart-define=API_BASE_URL=/api
# Android (then set the server URL in Settings if it differs)
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

## Test & analyze

```bash
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
```

## Notes

- The API base URL can be overridden at runtime in Settings → Server
  connection (useful for Android on a LAN).
- Classroom photos are fetched with the auth token (`Image.memory`), never
  via unauthenticated URLs.
- Recognition results are suggestions; the review screen is where the
  teacher confirms or corrects every match.
