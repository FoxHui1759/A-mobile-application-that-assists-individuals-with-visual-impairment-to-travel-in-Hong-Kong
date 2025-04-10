import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/tts_service.dart';
import 'home_page.dart';

const String appTitle = 'Eyes on the Road';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.black,
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Colors.black45),
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
    );
  }
}
