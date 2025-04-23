// lib/main.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/navigation_service.dart';
import 'services/location_service.dart';
import 'services/google_maps_service.dart';
import 'services/app_language_service.dart';
import 'pages/home_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Error getting cameras: $e');
  }

  // Initialize the required services
  final appLanguageService = AppLanguageService();
  final googleMapsService =
      GoogleMapsService(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');
  final locationService = LocationService();

  runApp(
    MultiProvider(
      providers: [
        // Provide the basic services
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider.value(value: appLanguageService),

        // Provide the NavigationService with its dependencies
        ChangeNotifierProvider(
            create: (context) => NavigationService(
                googleMapsService, locationService, appLanguageService)),
      ],
      child: MyApp(cameras: cameras),
    ),
  );
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
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
      home: const HomePage(title: 'Eyes on the Road'),
    );
  }
}
