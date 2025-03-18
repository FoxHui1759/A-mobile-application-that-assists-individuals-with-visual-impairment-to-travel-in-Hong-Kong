// lib/services/navigation_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../utils/connectivity_checker.dart';
import '../utils/polyline_utils.dart';
import 'google_maps_service.dart';
import 'location_service.dart';
import 'app_language_service.dart';

class NavigationService extends ChangeNotifier {
  final GoogleMapsService _mapsService;
  final LocationService _locationService;
  final AppLanguageService _languageService;

  // Navigation state
  RouteModel? _currentRoute;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  String _destination = '';
  String _error = '';
  bool _isLoading = false;

  // Location tracking
  Timer? _locationCheckTimer;
  static const int _locationCheckIntervalSeconds = 5;
  static const double _waypointReachedThresholdMeters = 30.0;
  static const double _routeThresholdMeters = 100.0; // Distance threshold for off-route detection

  // Enhanced navigation information
  String _distanceToNextStep = '';
  String _nextManeuverInfo = '';
  bool _isOffRoute = false;
  bool _autoAdvance = true; // Flag to enable/disable auto-advancement to next step

  // Add a grace period to avoid immediate off-route detection
  DateTime? _navigationStartTime;
  static const int _offRouteGracePeriodSeconds = 15;

  NavigationService(
      this._mapsService,
      this._locationService,
      this._languageService,
      );

  // Getters
  RouteModel? get currentRoute => _currentRoute;
  int get currentStepIndex => _currentStepIndex;
  bool get isNavigating => _isNavigating;
  String get destination => _destination;
  String get error => _error;
  bool get isLoading => _isLoading;
  bool get isOffRoute => _isOffRoute;
  bool get autoAdvance => _autoAdvance;

  // Enhanced navigation getters
  String get distanceToNextStep => _distanceToNextStep;
  String get nextManeuverInfo => _nextManeuverInfo;

  // Toggle auto-advancement of steps based on location
  void toggleAutoAdvance() {
    _autoAdvance = !_autoAdvance;
    notifyListeners();
  }

  // Current navigation information
  String get currentNavigationCue {
    if (_currentRoute == null || !_isNavigating) {
      return 'Set destination';
    }

    if (_isOffRoute) {
      return 'You are off route. Please return to the path.';
    }

    if (_currentStepIndex < _currentRoute!.steps.length) {
      return _currentRoute!.getCurrentStepInstructions(_currentStepIndex);
    }

    return 'You have arrived';
  }

  String get currentDistance {
    if (_currentRoute == null || !_isNavigating) {
      return '';
    }

    // If we have real-time distance to next step, show that instead
    if (_distanceToNextStep.isNotEmpty) {
      return _distanceToNextStep;
    }

    if (_currentStepIndex < _currentRoute!.steps.length) {
      return _currentRoute!.getCurrentStepDistance(_currentStepIndex);
    }

    return '';
  }

  // Get the next turn/maneuver type
  String get nextManeuver {
    if (_currentRoute == null || !_isNavigating) {
      return '';
    }

    return _currentRoute!.getNextManeuver(_currentStepIndex);
  }

  // Start navigation to a destination
  Future<void> startNavigation(String destination) async {
    _isLoading = true;
    _error = '';
    _destination = destination;
    notifyListeners();

    try {
      // Check connectivity first
      final connectivityChecker = ConnectivityChecker();
      final isConnected = await connectivityChecker.isConnected();

      if (!isConnected) {
        throw Exception('No internet connection. Please check your network settings and try again.');
      }

      // Initialize location in parallel
      final locationFuture = _initializeLocation();

      // Prepare locations directly on main isolate
      String startLocation;
      if (_locationService.hasLocation) {
        // Use actual user location if available
        startLocation = _locationService.currentLocationString;
      } else {
        // Fallback to default location
        startLocation = "22.2835513,114.1345991"; // HKU coordinates
        debugPrint('Warning: Using default location as fallback.');
      }

      // Process locations directly on the main isolate
      final processedStart = await _mapsService.preprocessCoordinates(startLocation);
      final processedDestination = await _mapsService.preprocessCoordinates(destination);

      // Wait for location initialization to complete
      await locationFuture;

      // Get navigation path directly on main isolate
      final routeData = await _mapsService.getNavigationPath(
        processedStart,
        processedDestination,
        languageCode: _languageService.currentLanguageCode, // Use the selected language
      );

      // Create route model
      _currentRoute = RouteModel.fromJson(routeData);
      _currentStepIndex = 0;
      _isNavigating = true;
      _isOffRoute = false;

      // Set navigation start time for grace period
      _navigationStartTime = DateTime.now();

      // Start location check timer for automatic step advancement
      _startLocationCheckTimer();

      // Update initial distance to next step
      _updateDistanceToNextStep();

    } catch (e) {
      _error = e.toString();
      _isNavigating = false;
      _currentRoute = null;
      _locationService.stopTracking();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Initialize location in parallel
  Future<void> _initializeLocation() async {
    try {
      // Initialize location service if not already done
      if (!_locationService.isInitialized) {
        await _locationService.initialize();
      }

      if (!_locationService.hasLocation) {
        await _locationService.getCurrentPosition();
      }

      // Start location tracking
      await _locationService.startTracking();
    } catch (e) {
      debugPrint('Error initializing location: $e');
      // We'll continue even if this fails
    }
  }

  // Start timer to periodically check user's location relative to the route
  void _startLocationCheckTimer() {
    // Cancel existing timer if any
    _locationCheckTimer?.cancel();

    // Create new timer
    _locationCheckTimer = Timer.periodic(
        Duration(seconds: _locationCheckIntervalSeconds),
            (_) => _checkLocationOnRoute()
    );
  }

  // Check if user has reached the next waypoint or if they're off route
  void _checkLocationOnRoute() {
    if (!_isNavigating || _currentRoute == null || !_locationService.hasLocation) {
      return;
    }

    // Use compute for this operation if it becomes expensive
    _updateDistanceToNextStep();

    // Check if user has reached the destination (last step)
    if (_currentStepIndex >= _currentRoute!.steps.length - 1) {
      final lastStep = _currentRoute!.steps.last;
      if (lastStep.endLocation != null && _isNearWaypoint(lastStep.endLocation!)) {
        // User has reached the final destination
        _announceArrived();
        return;
      }
    }

    // Check if user has reached current step endpoint (and should move to next step)
    final currentStep = _currentRoute!.steps[_currentStepIndex];
    if (currentStep.endLocation != null && _isNearWaypoint(currentStep.endLocation!)) {
      // User has reached the end of current step
      if (_autoAdvance && _currentStepIndex < _currentRoute!.steps.length - 1) {
        nextStep();
      }
      return;
    }

    // Check if user is off route (but respect grace period)
    _checkIfOffRoute();
  }

  // Check if user is near a specific waypoint
  bool _isNearWaypoint(Map<String, dynamic> waypoint) {
    if (!_locationService.hasLocation) return false;

    final waypointLat = waypoint['lat'] as double;
    final waypointLng = waypoint['lng'] as double;

    return _locationService.isCloseToLocation(
        waypointLat,
        waypointLng,
        threshold: _waypointReachedThresholdMeters
    );
  }

  // Update distance to next waypoint based on current location
  void _updateDistanceToNextStep() {
    if (!_locationService.hasLocation || _currentRoute == null ||
        _currentStepIndex >= _currentRoute!.steps.length) {
      _distanceToNextStep = '';
      return;
    }

    // Get current step
    final step = _currentRoute!.steps[_currentStepIndex];

    // If no end location for step, can't calculate distance
    if (step.endLocation == null) {
      _distanceToNextStep = step.distance;
      return;
    }

    // Calculate distance from current location to end of step
    final double endLat = step.endLocation!['lat'];
    final double endLng = step.endLocation!['lng'];

    final double distanceMeters = _locationService.getDistanceBetween(
        _locationService.currentPosition!.latitude,
        _locationService.currentPosition!.longitude,
        endLat,
        endLng
    );

    // Format distance for display
    if (distanceMeters > 1000) {
      _distanceToNextStep = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    } else {
      _distanceToNextStep = '${distanceMeters.round()} m';
    }

    notifyListeners();
  }

  // Check if user is off the route path - IMPROVED with polyline distance
  void _checkIfOffRoute() {
    if (!_locationService.hasLocation || _currentRoute == null) return;

    // Don't check for off-route during grace period
    if (_navigationStartTime != null) {
      final elapsedSeconds = DateTime.now().difference(_navigationStartTime!).inSeconds;
      if (elapsedSeconds < _offRouteGracePeriodSeconds) {
        if (_isOffRoute) {
          // Reset off-route status during grace period
          _isOffRoute = false;
          notifyListeners();
        }
        return;
      }
    }

    // Get user's current position
    final userLat = _locationService.currentPosition!.latitude;
    final userLng = _locationService.currentPosition!.longitude;

    // Check if we have the overview polyline to use for off-route detection
    if (_currentRoute!.overviewPolyline.isNotEmpty) {
      // Decode the overview polyline
      final routePoints = PolylineUtils.decodePolyline(_currentRoute!.overviewPolyline);

      // Calculate minimum distance to the route polyline
      final distanceToRoute = PolylineUtils.distanceToPolyline(userLat, userLng, routePoints);

      debugPrint('Distance to route: $distanceToRoute meters');

      // Check if we're close enough to the route
      final bool wasOffRoute = _isOffRoute;
      _isOffRoute = distanceToRoute > _routeThresholdMeters;

      // Only notify if status changed
      if (wasOffRoute != _isOffRoute) {
        notifyListeners();
      }
      return;
    }

    // Fallback method if overview polyline isn't available
    // Try to use the polyline of the current step or nearby steps

    // First check current step and collect polyline points
    List<Map<String, double>> stepPolylinePoints = [];

    // Current step polyline
    final currentStep = _currentRoute!.steps[_currentStepIndex];
    if (currentStep.polyline.isNotEmpty) {
      stepPolylinePoints.addAll(PolylineUtils.decodePolyline(currentStep.polyline));
    }

    // Add previous step polyline (if not first step)
    if (_currentStepIndex > 0) {
      final prevStep = _currentRoute!.steps[_currentStepIndex - 1];
      if (prevStep.polyline.isNotEmpty) {
        stepPolylinePoints.addAll(PolylineUtils.decodePolyline(prevStep.polyline));
      }
    }

    // Add next step polyline (if not last step)
    if (_currentStepIndex < _currentRoute!.steps.length - 1) {
      final nextStep = _currentRoute!.steps[_currentStepIndex + 1];
      if (nextStep.polyline.isNotEmpty) {
        stepPolylinePoints.addAll(PolylineUtils.decodePolyline(nextStep.polyline));
      }
    }

    // If we have points from polylines, use them for distance calculation
    if (stepPolylinePoints.isNotEmpty) {
      final distanceToPolyline = PolylineUtils.distanceToPolyline(userLat, userLng, stepPolylinePoints);
      debugPrint('Distance to step polyline: $distanceToPolyline meters');

      final bool wasOffRoute = _isOffRoute;
      _isOffRoute = distanceToPolyline > _routeThresholdMeters;

      // Only notify if status changed
      if (wasOffRoute != _isOffRoute) {
        notifyListeners();
      }
      return;
    }

    // Last resort: use the old distance to endpoints method if no polylines are available

    // Check distance to current step endpoint
    if (currentStep.endLocation != null) {
      final endLat = currentStep.endLocation!['lat'] as double;
      final endLng = currentStep.endLocation!['lng'] as double;

      final double distanceMeters = _locationService.getDistanceBetween(
          userLat, userLng, endLat, endLng
      );

      // If within threshold of current step, we're not off route
      if (distanceMeters <= _routeThresholdMeters) {
        if (_isOffRoute) {
          _isOffRoute = false;
          notifyListeners();
        }
        return;
      }

      // If not close to current step, check next step if available
      if (_currentStepIndex < _currentRoute!.steps.length - 1) {
        final nextStep = _currentRoute!.steps[_currentStepIndex + 1];
        if (nextStep.endLocation != null) {
          final nextEndLat = nextStep.endLocation!['lat'] as double;
          final nextEndLng = nextStep.endLocation!['lng'] as double;

          final double nextDistanceMeters = _locationService.getDistanceBetween(
              userLat, userLng, nextEndLat, nextEndLng
          );

          // If within threshold of next step, we're not off route
          if (nextDistanceMeters <= _routeThresholdMeters) {
            if (_isOffRoute) {
              _isOffRoute = false;
              notifyListeners();
            }
            return;
          }
        }
      }

      // If we're here, we're too far from current and next step
      final bool wasOffRoute = _isOffRoute;
      _isOffRoute = true;

      // Only notify if status changed
      if (wasOffRoute != _isOffRoute) {
        notifyListeners();
      }
    }
  }

  // Announce arrival at destination
  void _announceArrived() {
    // In a real app, you might trigger a notification or sound
    debugPrint('User has arrived at destination!');

    // You may want to keep navigation active until user dismisses it
    // or automatically end after a delay
    Future.delayed(Duration(seconds: 10), () {
      if (_isNavigating) {
        endNavigation();
      }
    });
  }

  // Move to next step in navigation
  void nextStep() {
    if (_currentRoute != null && _currentStepIndex < _currentRoute!.steps.length - 1) {
      _currentStepIndex++;
      _updateDistanceToNextStep();
      notifyListeners();
    }
  }

  // Move to previous step in navigation
  void previousStep() {
    if (_currentRoute != null && _currentStepIndex > 0) {
      _currentStepIndex--;
      _updateDistanceToNextStep();
      notifyListeners();
    }
  }

  // End current navigation
  void endNavigation() {
    _isNavigating = false;
    _currentRoute = null;
    _currentStepIndex = 0;
    _destination = '';
    _distanceToNextStep = '';
    _isOffRoute = false;
    _navigationStartTime = null;

    // Cancel timer
    _locationCheckTimer?.cancel();
    _locationCheckTimer = null;

    // Stop location tracking
    _locationService.stopTracking();

    notifyListeners();
  }

  // Manually recalculate route (for when user is off-route)
  Future<void> recalculateRoute() async {
    if (!_isNavigating || !_locationService.hasLocation) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Get current location as starting point
      final String startLocation = _locationService.currentLocationString;

      // Process locations directly
      final processedStart = await _mapsService.preprocessCoordinates(startLocation);
      final processedDestination = await _mapsService.preprocessCoordinates(_destination);

      // Get new navigation path directly
      final routeData = await _mapsService.getNavigationPath(
        processedStart,
        processedDestination,
        languageCode: _languageService.currentLanguageCode,
      );

      // Update route model
      _currentRoute = RouteModel.fromJson(routeData);
      _currentStepIndex = 0;
      _isOffRoute = false;
      _navigationStartTime = DateTime.now(); // Reset grace period for new route

      _updateDistanceToNextStep();
    } catch (e) {
      _error = 'Failed to recalculate route: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _locationCheckTimer?.cancel();
    super.dispose();
  }
}