// lib/utils/permission_handler.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:geolocator/geolocator.dart';

class AppPermissions {
  // Group permissions by category for better request flow
  static final List<ph.Permission> _mediaPermissions = [
    ph.Permission.camera,
    ph.Permission.microphone,
  ];

  // Request permissions one category at a time
  static Future<bool> requestLocationPermissions() async {
    // First check the geolocator permission - more reliable for location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }

    return true;
  }

  static Future<bool> requestMediaPermissions(BuildContext context) async {
    bool allGranted = true;

    // First check if we need to request these permissions
    bool needRequest = false;
    for (var permission in _mediaPermissions) {
      if (await permission.isDenied) {
        needRequest = true;
        break;
      }
    }

    if (needRequest) {
      // Show explanation dialog first
      bool shouldRequest = await _showPermissionRationaleDialog(
        context,
        'Camera & Microphone',
        'This app needs camera and microphone access for road detection and voice commands.',
      );

      if (!shouldRequest) return false;

      // Request each permission individually
      for (var permission in _mediaPermissions) {
        final status = await permission.request();
        if (!status.isGranted) {
          allGranted = false;
        }
      }
    }

    return allGranted;
  }

  static Future<bool> requestStoragePermissions(BuildContext context) async {
    bool allGranted = true;

    // Check if we need to request these permissions
    bool needRequest = await ph.Permission.storage.isDenied;

    if (needRequest) {
      // Show explanation dialog first
      bool shouldRequest = await _showPermissionRationaleDialog(
        context,
        'Storage Access',
        'This app needs storage access to save your settings and route information.',
      );

      if (!shouldRequest) return false;

      final status = await ph.Permission.storage.request();
      if (!status.isGranted) {
        allGranted = false;
      }
    }

    return allGranted;
  }

  static Future<bool> requestActivityPermissions(BuildContext context) async {
    bool allGranted = true;

    // Check if we need to request
    bool needRequest = await ph.Permission.activityRecognition.isDenied;

    if (needRequest) {
      // Show explanation dialog first
      bool shouldRequest = await _showPermissionRationaleDialog(
        context,
        'Motion Detection',
        'This app needs to detect your movement to improve navigation accuracy.',
      );

      if (!shouldRequest) return false;

      final status = await ph.Permission.activityRecognition.request();
      if (!status.isGranted) {
        allGranted = false;
      }
    }

    return allGranted;
  }

  // Check if all essential permissions are granted
  static Future<bool> checkEssentialPermissions() async {
    // Location
    LocationPermission locationPermission = await Geolocator.checkPermission();
    bool locationGranted = locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always;

    // Media
    bool cameraGranted = await ph.Permission.camera.isGranted;
    bool microphoneGranted = await ph.Permission.microphone.isGranted;

    // Storage
    bool storageGranted = await ph.Permission.storage.isGranted;

    // Activity Recognition
    bool activityGranted = await ph.Permission.activityRecognition.isGranted;

    return locationGranted && cameraGranted && microphoneGranted &&
        storageGranted && activityGranted;
  }

  // Permission rationale dialog
  static Future<bool> _showPermissionRationaleDialog(
      BuildContext context,
      String permissionType,
      String explanation,
      ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionType Permission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(explanation),
              const SizedBox(height: 16),
              const Text(
                'Without this permission, some app features may not work properly.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Skip'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Allow'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Show settings dialog when permissions are permanently denied
  static Future<bool> showSettingsDialog(BuildContext context, String permissionType) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$permissionType permission was denied. You need to enable it in app settings.'),
            const SizedBox(height: 12),
            const Text(
              'Go to Settings > Apps > Eyes on the Road > Permissions',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text('Open Settings'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  // Open app settings
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// New implementation of permission request flow - step by step
  static Future<bool> requestPermissionsStepByStep(BuildContext context) async {
    // Show initial permissions overview dialog
    bool shouldProceed = await _showInitialPermissionsDialog(context);
    if (!shouldProceed) return false;

    // Step 1: Request location permission (most important)
    bool locationGranted = await requestLocationPermissions();
    if (!locationGranted) {
      // If location permission denied, show settings dialog
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever && context.mounted) {
        bool goToSettings = await showSettingsDialog(context, 'Location');
        if (goToSettings) {
          await Geolocator.openLocationSettings();
        }
      }
      return false; // Cannot proceed without location
    }

    // Step 2: Request media permissions (camera & microphone)
    if (context.mounted) {
      bool mediaGranted = await requestMediaPermissions(context);
      if (!mediaGranted) {
        // Non-critical, can still proceed but with limited functionality
        debugPrint('Media permissions not granted - limited functionality');
      }
    }

    // Step 3: Request storage permissions
    if (context.mounted) {
      bool storageGranted = await requestStoragePermissions(context);
      if (!storageGranted) {
        // Non-critical, can still proceed but with limited functionality
        debugPrint('Storage permissions not granted - limited functionality');
      }
    }

    // Step 4: Request activity recognition permission
    if (context.mounted) {
      bool activityGranted = await requestActivityPermissions(context);
      if (!activityGranted) {
        // Non-critical, can still proceed but with limited functionality
        debugPrint('Activity permissions not granted - limited functionality');
      }
    }

    // Return true as we've handled all permissions, at least the critical ones
    return true;
  }

  // Initial dialog explaining all permissions needed
  static Future<bool> _showInitialPermissionsDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eyes on the Road needs several permissions to function properly:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildPermissionItem(
                  'Location',
                  'For route navigation and your position on the map',
                  Icons.location_on,
                ),
                _buildPermissionItem(
                  'Camera',
                  'For road detection and augmented reality features',
                  Icons.camera_alt,
                ),
                _buildPermissionItem(
                  'Microphone',
                  'For voice commands while navigating',
                  Icons.mic,
                ),
                _buildPermissionItem(
                  'Storage',
                  'To save your settings and route information',
                  Icons.storage,
                ),
                _buildPermissionItem(
                  'Activity Recognition',
                  'To detect your movement and improve navigation',
                  Icons.directions_walk,
                ),
                const SizedBox(height: 12),
                const Text(
                  'You\'ll be asked for each permission separately. You can change these later in your device settings.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Helper to build permission explanation items
  static Widget _buildPermissionItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(description, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated method for checking and requesting permissions
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    // Check if permissions are already granted
    bool hasPermissions = await checkEssentialPermissions();
    if (hasPermissions) {
      return true;
    }

    // Request permissions step by step
    return await requestPermissionsStepByStep(context);
  }
}