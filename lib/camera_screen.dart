import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'offline_detection.dart';
import 'online_detection.dart';
import 'settings_screen.dart';
import 'constants.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  bool _isCameraInitialized = false;
  bool _isListening = false;
  bool _isOnlineMode = true; // default online mode
  bool _isProcessing = false; // processing overlay indicator

  late OnlineDetection onlineDetection;
  late OfflineDetection offlineDetection;

  double _soundLevel = 0.0; // Add this variable to the state class

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize TTS
    await _tts.setSpeechRate(0.5);

    // Initialize STT with error handling
    try {
      print("Initializing speech recognition...");
      bool available = await _speechToText.initialize(
        onStatus: _onSpeechStatusChanged,
        onError: (error) {
          print("Speech-to-Text Error: $error");
          _tts.speak("Speech recognition error occurred");
        },
        debugLogging: true, // Add debug logging
      );
      print("Speech recognition available: $available");

      if (!available) {
        await _tts.speak("Speech recognition not available.");
      } else {
        await _tts.speak("Speech recognition ready.");
      }
    } catch (e) {
      print("Error initializing speech recognition: $e");
      await _tts.speak("Failed to initialize speech recognition.");
    }

    // Initialize Camera
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _setupCameraController(cameras.first);
    } else {
      await _tts.speak("No camera found on this device.");
    }

    // Initialize Online Detection
    onlineDetection = OnlineDetection(tts: _tts);

    // Initialize Offline Detection
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    offlineDetection = OfflineDetection(
        tts: _tts, objectDetector: ObjectDetector(options: options));
  }

  void _setupCameraController(CameraDescription cameraDescription) {
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    }).catchError((e) async {
      print("Camera initialization error: $e");
      await _tts.speak("Failed to initialize camera.");
    });
  }

  // Voice command handling
  void _startListening() async {
    if (!_isListening) {
      print("Starting to listen...");
      try {
        // Don't re-initialize if already initialized
        if (!_speechToText.isAvailable) {
          bool available = await _speechToText.initialize(
            onStatus: _onSpeechStatusChanged,
            onError: (error) {
              print("Speech-to-Text Error: $error");
              _tts.speak("Speech recognition error occurred");
            },
            debugLogging: true,
          );
          if (!available) {
            print("Speech recognition not available");
            await _tts.speak("Speech recognition not available");
            return;
          }
        }

        await _speechToText.listen(
          onResult: (result) => _onSpeechResult(result),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
          onSoundLevelChange: (level) {
            if (mounted) {
              setState(() {
                _soundLevel = level;
                print("Sound level: $level");
              });
            }
          },
        );

        setState(() => _isListening = true);
        await _tts.speak("Listening for command");
        print("Listening started successfully");
      } catch (e) {
        print("Error starting speech recognition: $e");
        await _tts.speak("Error starting speech recognition");
      }
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _onSpeechStatusChanged(String status) {
    setState(() => _isListening = status == SpeechToText.listeningStatus);
  }

  void _onSpeechResult(dynamic result) async {
    if (!result.finalResult) {
      print("Partial: ${result.recognizedWords}");
      return;
    }

    final command = result.recognizedWords.toLowerCase().trim();
    print("Final command received: '$command'");

    setState(() => _isListening = false);

    try {
      // Help command check first
      if (command.contains("help") ||
          command == "help" ||
          command.contains("emergency") ||
          command.contains("call") ||
          command == "emergency") {
        print("Help command recognized, making emergency call");
        await _makeEmergencyCall();
        return;
      }

      // Rest of your existing conditions
      if (command.contains("setting") ||
          command.contains("settings") ||
          command.contains("setup") ||
          command == "setting" ||
          command == "settings") {
        print("Settings command recognized, navigating to settings screen");
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        return;
      } else if (command.contains("location") ||
          command.contains("send location") ||
          command.contains("share location")) {
        await _shareLocation();
      } else if (command.contains("online") || command.contains("on line")) {
        setState(() => _isOnlineMode = true);
        await _tts.speak("Switched to online mode.");
      } else if (command.contains("offline") || command.contains("off line")) {
        setState(() => _isOnlineMode = false);
        await _tts.speak("Switched to offline mode.");
      } else if (command.contains("what") ||
          command.contains("describe") ||
          command.contains("detect") ||
          command.contains("see")) {
        await _captureAndDetect();
      } else if (command.contains("logout") ||
          command.contains("exit") ||
          command.contains("close")) {
        await _logout();
      } else {
        print("Command not recognized: '$command'");
        await _tts.speak("Command not recognized. Please try again.");
      }
    } catch (e) {
      print("Error processing command: $e");
      await _tts.speak("An error occurred while processing your command");
    }
  }

  Future<void> _makeEmergencyCall() async {
    final prefs = await SharedPreferences.getInstance();
    final emergencyContact = prefs.getString('emergency_contact');

    if (emergencyContact != null && emergencyContact.isNotEmpty) {
      // Use tel: instead of tel:// for direct dialing
      final Uri phoneUri = Uri.parse('tel:$emergencyContact');
      try {
        await _tts.speak("Calling emergency contact");
        // Use launch with forceSafariVC: false and universalLinksOnly: false for direct dialing
        await launchUrl(phoneUri, mode: LaunchMode.platformDefault);
      } catch (e) {
        print('Error making emergency call: $e');
        await _tts.speak("Unable to make emergency call");
      }
    } else {
      await _tts
          .speak("No emergency contact found. Please set one in settings.");
    }
  }

  // Capture image and send to online/offline detection
  Future<void> _captureAndDetect() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      if (_isOnlineMode) {
        await onlineDetection.detect(image.path);
      } else {
        await offlineDetection.detect(image.path);
      }
    } catch (e) {
      print("Detection error: $e");
      await _tts.speak("An error occurred during detection.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Add this method before the build method
  Future<void> _logout() async {
    await _tts.speak("Logging out. Goodbye!");
    // Wait for the TTS to finish speaking
    await Future.delayed(const Duration(seconds: 2));
    // Terminate the app
    SystemNavigator.pop();
  }

  // Replace the _shareLocation method with this updated version
  Future<void> _shareLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emergencyContact = prefs.getString('emergency_contact');

      if (emergencyContact == null || emergencyContact.isEmpty) {
        await _tts
            .speak("No emergency contact found. Please set one in settings.");
        return;
      }

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _tts.speak("Please enable location services on your device");
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _tts.speak("Location permission denied");
          return;
        }
      }

      await _tts.speak("Getting your location");
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Use a more reliable Google Maps URL format
      final String locationUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude}%2C${position.longitude}';

      final String messageBody =
          "Emergency Alert! My current location: $locationUrl";

      // Create and launch SMS
      final Uri smsLaunchUri = Uri(
        scheme: 'sms',
        path: emergencyContact,
        queryParameters: {'body': messageBody},
      );

      if (!await launchUrl(smsLaunchUri)) {
        throw Exception('Could not launch SMS app');
      }

      await _tts.speak("Location message ready to send");
    } catch (e) {
      print('Error sharing location: $e');
      await _tts.speak("Failed to share location. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // Add this GestureDetector
        onTap: _isListening ? _stopListening : _startListening,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isCameraInitialized && _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!)
            else
              const Center(child: CircularProgressIndicator()),
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            // Settings button
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon:
                      const Icon(Icons.settings, color: Colors.white, size: 30),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                  tooltip: 'Settings',
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
            // Microphone indicator
            if (_isListening)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 24 + (_soundLevel * 5),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Listening...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    offlineDetection.objectDetector.close();
    _speechToText.stop();
    _tts.stop();
    super.dispose();
  }
}
