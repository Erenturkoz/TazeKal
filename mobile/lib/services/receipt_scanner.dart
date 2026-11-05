import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum ReceiptSource { camera, gallery }

abstract class ReceiptScanner {
  Future<String?> scan(ReceiptSource source);
  Future<String?> recover();
}

class DeviceReceiptScanner implements ReceiptScanner {
  final ImagePicker _picker = ImagePicker();

  Future<String> _read(XFile image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<String?> scan(ReceiptSource source) async {
    final photo = await _picker.pickImage(
      source: source == ReceiptSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    return photo == null ? null : _read(photo);
  }

  @override
  Future<String?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    return files == null || files.isEmpty ? null : _read(files.first);
  }
}
