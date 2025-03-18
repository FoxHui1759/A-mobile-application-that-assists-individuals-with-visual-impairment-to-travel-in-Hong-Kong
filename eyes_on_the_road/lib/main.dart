// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'pages/home_page.dart';
import 'services/google_maps_service.dart';
import 'services/navigation_service.dart';
import 'services/location_service.dart';
import 'services/app_language_service.dart'; // Add this import
import 'utils/connectivity_checker.dart';

const String appTitle = 'Eyes on the Road';

// Use a more efficient loading approach to reduce main thread work
Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations to reduce layout calculations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Create a separate function for loading to isolate work
  await _loadApplicationData();

  // Run app without additional work in this call
  runApp(const MyApp());
}

// Isolate initialization work
Future<void> _loadApplicationData() async {
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env: $e');
    // Continue with default values
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Flag to track if we've attempted to initialize
  bool _isInitialized = false;

  // Minimalist initialization flag
  bool _canProceed = true;

  @override
  void initState() {
    super.initState();

    // Add observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Defer non-critical work with a microtask
    Future.microtask(() {
      _checkInitialRequirements();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle changes to prevent work when app is in background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check if we need to do any work
      if (!_isInitialized) {
        _checkInitialRequirements();
      }
    }
  }

  // Check initial requirements without blocking UI
  Future<void> _checkInitialRequirements() async {
    try {
      // Check for critical conditions only (e.g., API key)
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('WARNING: Missing Google Maps API key in .env');
        // Still allow the app to proceed, but it will show error later
      }

      // Don't run permission checks here - defer to services
      _isInitialized = true;

      // Only rebuild if mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error in initialization: $e');
    }
  }

  // Create providers lazily to avoid work during startup
  List<SingleChildWidget> _buildProviders() {
    // Get API key from .env file
    final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    return [
      // ConnectivityChecker - lightweight
      Provider<ConnectivityChecker>(
        create: (_) => ConnectivityChecker(),
        lazy: false, // Create this early as it's lightweight
      ),

      // AppLanguageService - language preferences
      ChangeNotifierProvider<AppLanguageService>(
        create: (_) => AppLanguageService(),
        lazy: false, // Initialize early since it's lightweight
      ),

      // GoogleMapsService - lazy load
      Provider<GoogleMapsService>(
        create: (_) => GoogleMapsService(
          apiKey: apiKey ?? 'missing_api_key',
        ),
        lazy: true, // Only initialize when first requested
      ),

      // LocationService - lazy load
      ChangeNotifierProvider<LocationService>(
        create: (_) => LocationService(),
        lazy: true, // Only initialize when first accessed
      ),

      // NavigationService - depends on other services
      ChangeNotifierProxyProvider3<GoogleMapsService, LocationService, AppLanguageService, NavigationService>(
        create: (context) => NavigationService(
          Provider.of<GoogleMapsService>(context, listen: false),
          Provider.of<LocationService>(context, listen: false),
          Provider.of<AppLanguageService>(context, listen: false),
        ),
        update: (context, mapsService, locationService, languageService, previous) =>
        previous ?? NavigationService(mapsService, locationService, languageService),
        lazy: true, // Only initialize when first accessed
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _buildProviders(),
      child: MaterialApp(
        title: appTitle,
        debugShowCheckedModeBanner: false, // Reduce overlay drawing
        theme: _buildAppTheme(),
        home: HomePage(title: appTitle),
        builder: (context, child) {
          // Add overall error boundary
          if (!_canProceed) {
            return _buildErrorScreen();
          }

          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }

  // Extract theme building to reduce work in build method
  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      primaryColor: Colors.indigo[900],
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: Colors.indigo[700],
      ),
      scaffoldBackgroundColor: Colors.white,
      // Precache text styles to avoid recalculation
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
    );
  }

  // Error screen for critical failures
  Widget _buildErrorScreen() {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Critical Error',
                  style: GoogleFonts.carlito(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The app could not initialize properly. Please restart the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.carlito(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}