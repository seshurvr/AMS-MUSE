import 'dart:typed_data';

/// Fallback for platforms with neither dart:html nor dart:io.
Future<String> saveDownloadedFile(Uint8List bytes, String filename) {
  throw UnsupportedError('File download is not supported on this platform.');
}
