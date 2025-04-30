// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/navigation_service.dart';
import 'services/location_service.dart';
import 'services/google_maps_service.dart';
import 'services/app_language_service.dart';
import 'pages/home_page.dart';


// Global error handler for uncaught exceptions
void _handleError(Object error, StackTrace stack) {
  debugPrint('=== Uncaught app exception ===');
  debugPrint('Error: $error');
  debugPrint('Stack trace: $stack');
  // You could also implement crash reporting here
}

Future<void> main() async {
  // Set up error handling for the entire app
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Capture all other errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables safely
    String? apiKey;
    try {
      await dotenv.load(fileName: ".env");
      apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Warning: GOOGLE_MAPS_API_KEY is missing in .env file');
      } else {
        debugPrint('Google Maps API key loaded successfully');
      }
    } catch (e) {
      debugPrint('Error loading .env file: $e');
      // Fallback: proceed with empty API key, will show proper errors later
    }

    // Initialize the required services
    final appLanguageService = AppLanguageService();
    final googleMapsService = GoogleMapsService(apiKey: apiKey ?? '');
    final locationService = LocationService();

    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          // Provide the basic services
          ChangeNotifierProvider.value(value: locationService),
          ChangeNotifierProvider.value(value: appLanguageService),

          // ADD THIS LINE: Directly provide GoogleMapsService
          Provider.value(value: googleMapsService),

          // Provide the NavigationService with its dependencies
          ChangeNotifierProvider(
              create: (context) => NavigationService(
                  googleMapsService, locationService, appLanguageService)),
        ],
        child: const MyApp(),
      ),
    );
  }, _handleError);
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Set device orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eyes on the Road',
      theme: ThemeData(
        primaryColor: Colors.indigo[900],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          secondary: Colors.indigo[300],
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: Colors.black,
            fontSize: 18,
          ),
          bodyMedium: TextStyle(
            color: Colors.black,
          ),
        ),
      ),
      // Error handling for widget errors
      builder: (context, child) {
        return MediaQuery(
          // Prevent text scaling to avoid layout issues
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!
        );
      },
      home: const HomePage(title: 'Eyes on the Road'),
    );
  }
}