import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/models.dart';
import '../domain/parking_rules.dart';
import '../domain/plate_recognition_service.dart';

class PlateRecognizer implements PlateRecognitionService {
  @override
  Future<List<String>?> captureAndRecognize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const ParkFailure(
        'OCR on-device cần ứng dụng Android/iOS. Bạn vẫn có thể nhập biển số thủ công.',
      );
    }
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 95,
    );
    if (photo == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      return plateCandidates(recognized.text);
    } finally {
      await recognizer.close();
    }
  }
}
