// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  // Add a flag to prevent multiple simultaneous initializations
  bool _isInitializing = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String get errorMessage => _errorMessage;
  bool get hasLocation => _currentPosition != null;
  bool get isInitialized => _isInitialized;

  // Get current location as a string in format "latitude,longitude"
  String get currentLocationString {
    if (_currentPosition != null) {
      return "${_currentPosition!.latitude},${_currentPosition!.longitude}";
    }
    return "";
  }

  // Initialize location service - optimized version
  Future<void> initialize() async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable location services.';
        notifyListeners();
        _isInitializing = false;
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permissions are denied. Please grant location permissions.';
          notifyListeners();
          _isInitializing = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permissions are permanently denied. Please enable in settings.';
        notifyListeners();
        _isInitializing = false;
        return;
      }

      // Get current position
      await _getCurrentPositionOptimized();

      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error initializing location service: $e';
      debugPrint(_errorMessage);
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Get current position - optimized to reduce main thread work
  Future<void> getCurrentPosition() async {
    return _getCurrentPositionOptimized();
  }

  // Internal implementation with optimization
  Future<void> _getCurrentPositionOptimized() async {
    try {
      _errorMessage = '';

      // Run this on a background thread when possible
      final positionFuture = Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Use compute for this, but it's not always possible due to platform channel limitations
      Position position;
      try {
        position = await positionFuture;
      } catch (e) {
        debugPrint('Error getting position: $e');
        throw e;
      }

      _currentPosition = position;
      debugPrint('Current position: ${position.latitude}, ${position.longitude}');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error getting current location: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // Start tracking location - optimized version
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      _errorMessage = '';

      // Define location settings - updated for newer geolocator version
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update if moved 10 meters
        timeLimit: Duration(seconds: 15),
      );

      // Start the subscription with optimized handlers
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
            (position) {
          // Run potentially heavy position processing off main thread where possible
          _handlePositionUpdateOptimized(position);
        },
        onError: (dynamic error) {
          // Error handling can be lightweight
          _handlePositionError(error);
        },
      );

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error starting location tracking: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // Optimize position update handling
  void _handlePositionUpdateOptimized(Position position) {
    // Set current position
    _currentPosition = position;
    debugPrint('Updated position: ${position.latitude}, ${position.longitude}');

    // Use microtask for notification to avoid blocking main thread immediately
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Error handler method
  void _handlePositionError(dynamic error) {
    _errorMessage = 'Location tracking error: $error';
    debugPrint(_errorMessage);
    notifyListeners();
  }

  // Stop tracking location
  void stopTracking() {
    if (!_isTracking) return;

    _positionStreamSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  // Get distance between two points in meters
  double getDistanceBetween(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  // Get bearing between two points in degrees
  double getBearingBetween(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.bearingBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  // Calculate if user is close to a location (within given meters)
  bool isCloseToLocation(double latitude, double longitude, {double threshold = 25}) {
    if (_currentPosition == null) return false;

    double distance = getDistanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        latitude, longitude
    );

    return distance <= threshold;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}