import 'package:flutter/material.dart';
import 'splash_screen.dart'; // Import our splash screen

void main() {
  // Ensure that all Flutter bindings are initialized before running the app.
  // This is required for plugins like the camera to work correctly.
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'VocalEye',
      // Set the SplashScreen as the home screen of the app
      home: SplashScreen(),
      // Hide the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,
    );
  }
}
