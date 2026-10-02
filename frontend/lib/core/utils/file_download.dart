/// Saves a downloaded file (CSV/XLSX export) and returns a human-readable
/// location ("Downloads folder" on web, the file path on Android/Desktop).
///
/// Implemented per platform via conditional import so `dart:html` never
/// leaks into the Android build and `dart:io` never leaks into web.
export 'src/file_download_stub.dart'
    if (dart.library.html) 'src/file_download_web.dart'
    if (dart.library.io) 'src/file_download_io.dart';
