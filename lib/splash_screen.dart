import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:local_auth/local_auth.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // Use a short delay to ensure the screen is visible before TTS and auth
    Future.delayed(const Duration(milliseconds: 500), _initiateStartupSequence);
  }

  /// Initializes Text-to-Speech and starts the welcome/auth flow.
  Future<void> _initiateStartupSequence() async {
    // Configure TTS settings
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    // Speak the welcome message
    await _speak("Welcome to VocalEye, please authenticate to continue.");
    
    // Start authentication immediately after speaking
    _authenticateUser();
  }

  /// Speaks the given text using the TTS engine.
  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  /// Handles the biometric/device authentication.
  Future<void> _authenticateUser() async {
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to access VocalEye',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep the dialog up until success/failure
          biometricOnly: false, // Allow PIN/Pattern as well as biometrics
        ),
      );
    } on PlatformException catch (e) {
      // Handle cases where auth is not available
      print("Authentication error: $e");
      await _speak("Authentication service is not available on this device.");
      SystemNavigator.pop(); // Close the app
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      await _speak("Authentication successful.");
      // Navigate to the camera screen on success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      await _speak("Authentication failed.");
      SystemNavigator.pop(); // Close the app on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'VocalEye',
          style: TextStyle(
            fontSize: 52.0,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 176, 39, 101),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
