// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'camera_page.dart';
import 'settings_page.dart';
import 'route_test_page.dart';
import '../services/location_service.dart';
import '../utils/permission_handler.dart';

class HomePage extends StatefulWidget {
  final String title;

  const HomePage({super.key, required this.title});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _locationInitialized = false;
  bool _isRequestingPermissions = false;

  static final List<Widget> _widgetOptions = <Widget>[
    const CameraPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app is resumed
    WidgetsBinding.instance.addObserver(this);

    // Initialize location service after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationInitialized) {
      // App came back from settings, try to initialize location again
      _checkPermissionsAfterSettings();
    }
  }

  // Check permissions after returning from settings
  Future<void> _checkPermissionsAfterSettings() async {
    // Avoid showing dialogs immediately after resuming
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Check if permissions are now granted without showing dialogs
    final hasPermissions = await AppPermissions.checkEssentialPermissions();
    if (hasPermissions) {
      _initializeLocationService();
    }
  }

  // Main app initialization flow
  Future<void> _initializeApp() async {
    if (_isRequestingPermissions) return;

    setState(() {
      _isRequestingPermissions = true;
    });

    try {
      // Request permissions with step-by-step flow
      final hasPermissions = await AppPermissions.checkAndRequestPermissions(context);

      if (hasPermissions) {
        await _initializeLocationService();
      } else {
        // Show a permanent banner with instruction if permissions denied
        if (mounted) {
          _showPermissionsBanner();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermissions = false;
        });
      }
    }
  }

  // Initialize location service
  Future<void> _initializeLocationService() async {
    final locationService = Provider.of<LocationService>(context, listen: false);

    try {
      // Initialize location service
      await locationService.initialize();
      if (locationService.isInitialized) {
        await locationService.getCurrentPosition();
        if (mounted) {
          setState(() {
            _locationInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing location: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Show a persistent banner about permissions
  void _showPermissionsBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
            'Location and other permissions are required for this app to work properly.'
        ),
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('DISMISS'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _initializeApp();
            },
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Location status indicator
          Consumer<LocationService>(
            builder: (context, locationService, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  locationService.hasLocation
                      ? Icons.location_on
                      : Icons.location_off,
                  color: locationService.hasLocation
                      ? Colors.green
                      : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'Eyes on the Road',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            // Add navigation menu items
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // Add test page menu item
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Route Test'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RouteTestPage(),
                  ),
                );
              },
            ),
            // Permissions menu item
            ListTile(
              leading: Icon(
                _locationInitialized ? Icons.check_circle : Icons.perm_device_information,
                color: _locationInitialized ? Colors.green : Colors.orange,
              ),
              title: Text(
                _locationInitialized ? 'Permissions Granted' : 'Request Permissions',
              ),
              onTap: () {
                Navigator.pop(context);
                if (!_locationInitialized) {
                  _initializeApp();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All required permissions are already granted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Main content
          Center(
            child: _widgetOptions.elementAt(_selectedIndex),
          ),

          // Loading indicator for permission requests
          if (_isRequestingPermissions)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Requesting permissions...",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Please respond to permission dialogs",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Navigation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}