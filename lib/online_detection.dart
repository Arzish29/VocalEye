// online_detection.dart
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class OnlineDetection {
  final FlutterTts tts;
  final String apiKey = 'acc_1346317583a2215';
  final String apiSecret = '7fa89be53470e8b33085bbab1bdbbd26';
  bool _isProcessing = false;
  

  OnlineDetection({required this.tts});

  /// Sends the image to the online YOLOv8 server and speaks detected objects
  Future<void> detect(String imagePath) async {
    if (_isProcessing) {
      await tts.speak("Please wait, still processing previous image.");
      return;
    }

    _isProcessing = true;

    try {
      await tts.speak("Analyzing image...");

      var uri = Uri.parse('https://api.imagga.com/v2/tags');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imagePath,
        ),
      );

      print("Sending request to Imagga API...");
      var streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      print("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null && data['result']['tags'] != null) {
          final tags = data['result']['tags'] as List;

          if (tags.isNotEmpty) {
            // Get only the most confident tag above 70%
            final mostConfidentTag = tags
                .where((tag) => (tag['confidence'] as num) > 70)
                .reduce((a, b) =>
                    (a['confidence'] as num) > (b['confidence'] as num)
                        ? a
                        : b);

            if (mostConfidentTag != null) {
              String objectName = mostConfidentTag['tag']['en'].toString();
              await tts.speak("I see $objectName");
            } else {
              await tts.speak("I'm not sure what I'm looking at.");
            }
          } else {
            await tts.speak("I don't see any clear objects.");
          }
        } else {
          print("Invalid response format: $data");
          await tts.speak("I couldn't process what I'm seeing.");
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        await tts.speak("Sorry, I'm having trouble analyzing the image.");
      }
    } catch (e) {
      print("Online detection error: $e");
      await tts.speak("Sorry, I couldn't analyze the image.");
    } finally {
      _isProcessing = false;
    }
  }
}
