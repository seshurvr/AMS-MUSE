import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Android/Desktop: write the bytes into the app documents directory.
Future<String> saveDownloadedFile(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
