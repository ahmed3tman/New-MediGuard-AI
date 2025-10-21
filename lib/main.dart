import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spider_doctor/my_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dotenv for environment variables (load the bundled assets/.env)
  try {
    await dotenv.load(fileName: "assets/.env");
    // debug: print a loaded value to verify the file is read at runtime
    final baseUrl = dotenv.env['BASE_URL'] ?? 'BASE_URL not set';
    print('Loaded BASE_URL from .env: $baseUrl');
  } catch (e) {
    print('Warning: Could not load assets/.env file: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Handle initialization errors gracefully
    if (e.toString().contains('duplicate-app')) {
      // Firebase already initialized, continue
      print('Firebase already initialized');
    } else {
      print('Firebase initialization failed: $e');
    }
  }

  runApp(const MyApp());
}
