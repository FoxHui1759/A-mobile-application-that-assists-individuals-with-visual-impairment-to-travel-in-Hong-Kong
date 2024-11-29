import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_page.dart';

const String appTitle = 'Eyes on the Road';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'appTitle',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color.fromARGB(255, 26, 26, 26),
        textTheme: TextTheme(
          headlineMedium: GoogleFonts.oswald(
              fontSize: 25, fontStyle: FontStyle.normal, color: Colors.white),
          bodyMedium: GoogleFonts.oswald(
              fontSize: 20, fontStyle: FontStyle.normal, color: Colors.white),
          labelMedium: GoogleFonts.oswald(
              fontSize: 10, fontStyle: FontStyle.normal, color: Colors.white),
        ),
      ),
      home: HomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
