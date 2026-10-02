import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Picks classroom / student photos from camera or gallery.
///
/// - Android: camera capture + gallery via image_picker.
/// - Web/Desktop: file picker (camera capture is not practical there,
///   so the UI hides the camera option on web).
class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pickFromGallery() async {
    if (kIsWeb) return pickFile();
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 92,
    );
    return xfile?.readAsBytes();
  }

  Future<Uint8List?> captureFromCamera() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      imageQuality: 92,
    );
    return xfile?.readAsBytes();
  }

  Future<Uint8List?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    return result?.files.single.bytes;
  }
}
