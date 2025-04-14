// lib/services/navigation_service.dart
import 'dart:async';
import 'dart:math' as math;
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
  int _currentRouteIndex = 0;
  int _alternativeRouteCount = 0;

  // Location tracking
  Timer? _locationCheckTimer;
  static const int _locationCheckIntervalSeconds = 2; // Reduced from 5 to 2 seconds
  static const double _waypointReachedThresholdMeters = 30.0;
  static const double _routeThresholdMeters = 100.0; // Distance threshold for off-route detection

  // Enhanced navigation information
  String _distanceToNextStep = '';
  final String _nextManeuverInfo = '';
  bool _isOffRoute = false;
  bool _autoAdvance = true; // Flag to enable/disable auto-advancement to next step

  // Add more detailed distance tracking
  double _distanceToNextStepMeters = 0.0;
  double _distanceToDestinationMeters = 0.0;
  Duration _estimatedTimeToDestination = Duration.zero;
  String _estimatedArrivalTime = '';

  // Add progress tracking
  double _routeProgress = 0.0;  // 0.0 to 1.0
  double _stepProgress = 0.0;   // 0.0 to 1.0

  // Add a grace period to avoid immediate off-route detection
  DateTime? _navigationStartTime;
  static const int _offRouteGracePeriodSeconds = 15;

  // Add timer for real-time distance updates
  Timer? _distanceUpdateTimer;
  static const int _distanceUpdateIntervalMillis = 1000; // Update every second

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
  double get routeProgress => _routeProgress;
  double get stepProgress => _stepProgress;
  double get distanceToNextStepMeters => _distanceToNextStepMeters;
  double get distanceToDestinationMeters => _distanceToDestinationMeters;
  Duration get estimatedTimeToDestination => _estimatedTimeToDestination;
  String get estimatedArrivalTime => _estimatedArrivalTime;
  int get currentRouteIndex => _currentRouteIndex;
  int get alternativeRouteCount => _alternativeRouteCount;
  bool get hasAlternativeRoutes => _alternativeRouteCount > 1;

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

      // Store route index and count
      _currentRouteIndex = routeData['route_index'] ?? 0;
      _alternativeRouteCount = routeData['alternative_count'] ?? 1;

      // Set navigation start time for grace period
      _navigationStartTime = DateTime.now();

      // Start location check timer for automatic step advancement
      _startLocationCheckTimer();

      // Start distance update timer for real-time distance updates
      _startDistanceUpdateTimer();

      // Update initial distance to next step
      _calculateDistanceToNextStep();

      // Calculate initial estimated time of arrival
      _calculateEstimatedArrival();

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

    // Create new timer with reduced interval
    _locationCheckTimer = Timer.periodic(
        Duration(seconds: _locationCheckIntervalSeconds),
            (_) => _checkLocationOnRoute()
    );
  }

  // Start timer for real-time distance updates
  void _startDistanceUpdateTimer() {
    // Cancel existing timer if any
    _distanceUpdateTimer?.cancel();

    // Create new timer for more frequent updates
    _distanceUpdateTimer = Timer.periodic(
        Duration(milliseconds: _distanceUpdateIntervalMillis),
            (_) => _calculateDistanceToNextStep()
    );
  }

  // Check if user has reached the next waypoint or if they're off route
  void _checkLocationOnRoute() {
    if (!_isNavigating || _currentRoute == null || !_locationService.hasLocation) {
      return;
    }

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

    // Update progress values
    _updateRouteProgress();
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

  // Calculate distance to next waypoint
  void _calculateDistanceToNextStep() {
    if (!_locationService.hasLocation || _currentRoute == null ||
        _currentStepIndex >= _currentRoute!.steps.length) {
      _distanceToNextStep = '';
      _distanceToNextStepMeters = 0.0;
      return;
    }

    // Get current step
    final step = _currentRoute!.steps[_currentStepIndex];

    // If no end location for step, can't calculate distance
    if (step.endLocation == null) {
      _distanceToNextStep = step.distance;
      // Try to extract meters from the text distance
      _extractDistanceMeters(step.distance);
      return;
    }

    // Calculate distance from current location to end of step
    final currentPosition = _locationService.currentPosition!;
    final double endLat = step.endLocation!['lat'];
    final double endLng = step.endLocation!['lng'];

    final double distanceMeters = _locationService.getDistanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        endLat,
        endLng
    );

    _distanceToNextStepMeters = distanceMeters;

    // Format distance for display
    if (distanceMeters > 1000) {
      _distanceToNextStep = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    } else {
      _distanceToNextStep = '${distanceMeters.round()} m';
    }

    // Also calculate distance to final destination (for ETA purposes)
    _calculateDistanceToDestination();

    // Update step progress
    if (_currentStepIndex < _currentRoute!.steps.length) {
      _updateStepProgress(distanceMeters, step);
    }

    notifyListeners();
  }

  // Helper to extract distance in meters from text
  void _extractDistanceMeters(String distanceText) {
    // Format examples: "500 m", "1.2 km"
    try {
      if (distanceText.contains('km')) {
        // Extract kilometers
        final kmStr = distanceText.replaceAll('km', '').trim();
        _distanceToNextStepMeters = double.parse(kmStr) * 1000;
      } else if (distanceText.contains('m')) {
        // Extract meters
        final mStr = distanceText.replaceAll('m', '').trim();
        _distanceToNextStepMeters = double.parse(mStr);
      }
    } catch (e) {
      debugPrint('Error extracting distance from text: $e');
      _distanceToNextStepMeters = 0.0;
    }
  }

  // Calculate distance to final destination (used for ETA calculations)
  void _calculateDistanceToDestination() {
    if (!_locationService.hasLocation || _currentRoute == null) {
      _distanceToDestinationMeters = 0.0;
      return;
    }

    // Get the final step
    final finalStep = _currentRoute!.steps.last;
    if (finalStep.endLocation == null) {
      return;
    }

    // Get current position for calculation
    final currentPosition = _locationService.currentPosition!;

    // Calculate direct distance to final destination
    final double destLat = finalStep.endLocation!['lat'];
    final double destLng = finalStep.endLocation!['lng'];

    _distanceToDestinationMeters = _locationService.getDistanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        destLat,
        destLng
    );

    // Update estimated arrival time if distance changed significantly
    _calculateEstimatedArrival();
  }

  // Calculate estimated time of arrival
  void _calculateEstimatedArrival() {
    if (_currentRoute == null || !_isNavigating) {
      _estimatedTimeToDestination = Duration.zero;
      _estimatedArrivalTime = '';
      return;
    }

    try {
      // Extract total duration in seconds from route
      final String durationString = _currentRoute!.totalDuration;
      int totalSeconds = 0;

      // Parse duration string (e.g., "10 mins" or "1 hour 5 mins")
      if (durationString.contains('hour')) {
        final hourParts = durationString.split('hour');
        final hours = int.parse(hourParts[0].trim());
        totalSeconds += hours * 3600;

        if (hourParts.length > 1 && hourParts[1].contains('min')) {
          final minutesStr = hourParts[1].replaceAll('mins', '').replaceAll('min', '').trim();
          final minutes = int.parse(minutesStr);
          totalSeconds += minutes * 60;
        }
      } else if (durationString.contains('min')) {
        final minutesStr = durationString.replaceAll('mins', '').replaceAll('min', '').trim();
        final minutes = int.parse(minutesStr);
        totalSeconds += minutes * 60;
      }

      // Adjust based on progress if already on route
      if (_routeProgress > 0 && _routeProgress < 1) {
        totalSeconds = (totalSeconds * (1 - _routeProgress)).toInt();
      }

      // Set the estimated time to destination
      _estimatedTimeToDestination = Duration(seconds: totalSeconds);

      // Calculate estimated arrival time
      final now = DateTime.now();
      final arrival = now.add(_estimatedTimeToDestination);

      // Format time as HH:MM
      final hour = arrival.hour.toString().padLeft(2, '0');
      final minute = arrival.minute.toString().padLeft(2, '0');
      _estimatedArrivalTime = '$hour:$minute';
    } catch (e) {
      debugPrint('Error calculating ETA: $e');
      _estimatedTimeToDestination = Duration.zero;
      _estimatedArrivalTime = '';
    }
  }

  // Update the progress along the current step
  void _updateStepProgress(double distanceToEndOfStep, RouteStep step) {
    try {
      // Extract the total step distance in meters
      final String totalDistanceStr = step.distance;
      double totalStepDistanceMeters = 0;

      if (totalDistanceStr.contains('km')) {
        final kmStr = totalDistanceStr.replaceAll('km', '').trim();
        totalStepDistanceMeters = double.parse(kmStr) * 1000;
      } else if (totalDistanceStr.contains('m')) {
        final mStr = totalDistanceStr.replaceAll('m', '').trim();
        totalStepDistanceMeters = double.parse(mStr);
      }

      if (totalStepDistanceMeters > 0) {
        // Calculate progress as percentage completed
        _stepProgress = 1.0 - (distanceToEndOfStep / totalStepDistanceMeters);

        // Clamp to valid range
        _stepProgress = math.min(1.0, math.max(0.0, _stepProgress));
      }
    } catch (e) {
      debugPrint('Error updating step progress: $e');
      _stepProgress = 0.0;
    }
  }

  // Update overall route progress
  void _updateRouteProgress() {
    try {
      if (_currentRoute == null || !_isNavigating) {
        _routeProgress = 0.0;
        return;
      }

      // Calculate progress based on completed steps and current step progress
      double totalDistance = _extractTotalDistanceMeters(_currentRoute!.totalDistance);
      double coveredDistance = 0;

      // Sum distances of completed steps
      for (int i = 0; i < _currentStepIndex; i++) {
        coveredDistance += _extractStepDistanceMeters(_currentRoute!.steps[i].distance);
      }

      // Add partial distance of current step
      if (_currentStepIndex < _currentRoute!.steps.length) {
        double currentStepTotal = _extractStepDistanceMeters(_currentRoute!.steps[_currentStepIndex].distance);
        coveredDistance += currentStepTotal * _stepProgress;
      }

      // Calculate progress as percentage
      if (totalDistance > 0) {
        _routeProgress = coveredDistance / totalDistance;

        // Clamp to valid range
        _routeProgress = math.min(1.0, math.max(0.0, _routeProgress));
      }
    } catch (e) {
      debugPrint('Error updating route progress: $e');
      _routeProgress = 0.0;
    }
  }

  // Helper to extract distance in meters from step distance
  double _extractStepDistanceMeters(String distanceText) {
    try {
      if (distanceText.contains('km')) {
        final kmStr = distanceText.replaceAll('km', '').trim();
        return double.parse(kmStr) * 1000;
      } else if (distanceText.contains('m')) {
        final mStr = distanceText.replaceAll('m', '').trim();
        return double.parse(mStr);
      }
    } catch (e) {
      debugPrint('Error extracting step distance: $e');
    }
    return 0.0;
  }

  // Helper to extract total distance in meters from route
  double _extractTotalDistanceMeters(String distanceText) {
    try {
      if (distanceText.contains('km')) {
        final kmStr = distanceText.replaceAll('km', '').trim();
        return double.parse(kmStr) * 1000;
      } else if (distanceText.contains('m')) {
        final mStr = distanceText.replaceAll('m', '').trim();
        return double.parse(mStr);
      }
    } catch (e) {
      debugPrint('Error extracting total distance: $e');
    }
    return 0.0;
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
    final position = _locationService.currentPosition!;
    final userLat = position.latitude;
    final userLng = position.longitude;

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
      _calculateDistanceToNextStep();
      _stepProgress = 0.0; // Reset step progress for new step
      notifyListeners();
    }
  }

  // Move to previous step in navigation
  void previousStep() {
    if (_currentRoute != null && _currentStepIndex > 0) {
      _currentStepIndex--;
      _calculateDistanceToNextStep();
      _stepProgress = 0.0; // Reset step progress for new step
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
    _routeProgress = 0.0;
    _stepProgress = 0.0;
    _distanceToNextStepMeters = 0.0;
    _distanceToDestinationMeters = 0.0;
    _estimatedTimeToDestination = Duration.zero;
    _estimatedArrivalTime = '';
    _currentRouteIndex = 0;
    _alternativeRouteCount = 0;

    // Cancel timers
    _locationCheckTimer?.cancel();
    _locationCheckTimer = null;

    _distanceUpdateTimer?.cancel();
    _distanceUpdateTimer = null;

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
      _stepProgress = 0.0;
      _routeProgress = 0.0;

      // Store route index and count
      _currentRouteIndex = routeData['route_index'] ?? 0;
      _alternativeRouteCount = routeData['alternative_count'] ?? 1;

      _calculateDistanceToNextStep();
      _calculateEstimatedArrival();
    } catch (e) {
      _error = 'Failed to recalculate route: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Use alternative route
  Future<void> useAlternativeRoute() async {
    if (!_isNavigating || !_locationService.hasLocation) return;

    // Check if we have alternatives available
    if (_alternativeRouteCount <= 1) {
      _error = 'No alternative routes available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Get current location as starting point
      final String startLocation = _locationService.currentLocationString;

      // Process locations
      final processedStart = await _mapsService.preprocessCoordinates(startLocation);
      final processedDestination = await _mapsService.preprocessCoordinates(_destination);

      // Get an alternative route
      final routeData = await _mapsService.getAlternativeRoute(
        processedStart,
        processedDestination,
        languageCode: _languageService.currentLanguageCode,
        currentRouteIndex: _currentRouteIndex,
      );

      // Update route model
      _currentRoute = RouteModel.fromJson(routeData);
      _currentStepIndex = 0;
      _isOffRoute = false;
      _navigationStartTime = DateTime.now(); // Reset grace period for new route
      _stepProgress = 0.0;
      _routeProgress = 0.0;

      // Store route index
      _currentRouteIndex = routeData['route_index'] ?? 0;
      _alternativeRouteCount = routeData['alternative_count'] ?? 1;

      _calculateDistanceToNextStep();
      _calculateEstimatedArrival();
    } catch (e) {
      _error = 'Failed to get alternative route: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get detailed navigation status information
  Map<String, dynamic> getNavigationStatus() {
    return {
      'isNavigating': _isNavigating,
      'currentStepIndex': _currentStepIndex,
      'totalSteps': _currentRoute?.steps.length ?? 0,
      'distanceToNextStep': _distanceToNextStep,
      'distanceToNextStepMeters': _distanceToNextStepMeters,
      'distanceToDestinationMeters': _distanceToDestinationMeters,
      'routeProgress': _routeProgress,
      'stepProgress': _stepProgress,
      'estimatedTimeToDestination': _estimatedTimeToDestination.inSeconds,
      'estimatedArrivalTime': _estimatedArrivalTime,
      'isOffRoute': _isOffRoute,
      'nextManeuver': nextManeuver,
      'currentInstruction': currentNavigationCue,
      'currentRouteIndex': _currentRouteIndex,
      'alternativeRouteCount': _alternativeRouteCount,
      'hasAlternativeRoutes': _alternativeRouteCount > 1,
    };
  }

  @override
  void dispose() {
    _locationCheckTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    super.dispose();
  }
}