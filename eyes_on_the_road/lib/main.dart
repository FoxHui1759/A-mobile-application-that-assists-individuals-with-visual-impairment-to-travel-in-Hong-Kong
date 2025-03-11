// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'services/google_maps_service.dart';
import 'services/navigation_service.dart';

const String appTitle = 'Eyes on the Road';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get API key from .env file
    final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    return MultiProvider(
      providers: [
        // Google Maps service
        Provider<GoogleMapsService>(
          create: (_) => GoogleMapsService(apiKey: apiKey ?? (throw Exception('Missing required environment variable: GOOGLE_MAPS_API_KEY'))),
        ),

        // Navigation service (depends on Google Maps service)
        ChangeNotifierProxyProvider<GoogleMapsService, NavigationService>(
          create: (context) => NavigationService(
              Provider.of<GoogleMapsService>(context, listen: false)
          ),
          update: (context, mapsService, previous) =>
          previous ?? NavigationService(mapsService),
        ),
      ],
      child: MaterialApp(
        title: appTitle,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: Colors.indigo[900],
          colorScheme:
          ColorScheme.fromSwatch().copyWith(secondary: Colors.indigo[700]),
          scaffoldBackgroundColor: Colors.white,
          textTheme: TextTheme(
            headlineMedium: GoogleFonts.carlito(
                fontSize: 25,
                fontStyle: FontStyle.normal,
                color: Colors.white,
                fontWeight: FontWeight.bold),
            bodyLarge: GoogleFonts.carlito(
                fontSize: 50,
                fontStyle: FontStyle.normal,
                color: Colors.white,
                fontWeight: FontWeight.bold),
            bodyMedium: GoogleFonts.carlito(
                fontSize: 20, fontStyle: FontStyle.normal, color: Colors.white),
            labelMedium: GoogleFonts.carlito(
                fontSize: 10, fontStyle: FontStyle.normal, color: Colors.white),
          ),
        ),
        home: HomePage(title: appTitle),
      ),
    );
  }
}