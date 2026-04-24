import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class OfflineDetection {
  final FlutterTts tts;
  final ObjectDetector objectDetector;

  // Correct constructor
  OfflineDetection({required this.tts, required this.objectDetector});

  /// Processes image offline and speaks detected objects
  Future<void> detect(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final objects = await objectDetector.processImage(inputImage);

      if (objects.isEmpty) {
        await tts.speak("I could not detect any objects.");
      } else {
        final detectedObjects = objects.where((obj) {
          return obj.labels.isNotEmpty && obj.labels.first.confidence > 0.6;
        }).map((obj) => obj.labels.first.text).join(", ");

        if (detectedObjects.isEmpty) {
          await tts.speak("I couldn't confidently recognize any objects.");
        } else {
          await tts.speak("I see: $detectedObjects.");
        }
      }
    } catch (e) {
      print("Offline detection error: $e");
      await tts.speak("An error occurred during offline detection.");
    }
  }
}
