// lib/services/location_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/pdr_service.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  // Add a flag to prevent multiple simultaneous initializations
  bool _isInitializing = false;

  final PDRService _pdrService;

  // GPS quality metrics
  double _horizontalAccuracy = 0.0;
  final int _satelliteCount = 0;
  bool _isGpsSignalLow = false;

  // Timer for regular position updates
  Timer? _locationUpdateTimer;
  static const int _locationUpdateIntervalMillis = 1000; // Update every second

  // Position fusion mode
  bool _usePositionFusion = true; // Default to using fusion of GPS and PDR

  // Constructor with PDR service
  LocationService({PDRService? pdrService}) : _pdrService = pdrService ?? PDRService();

  // Getters
  Position? get currentPosition => _getFusedPosition();
  bool get isTracking => _isTracking;
  String get errorMessage => _errorMessage;
  bool get hasLocation => _currentPosition != null || (_pdrService.isRunning && _pdrService.confidence > 0.3);
  bool get isInitialized => _isInitialized;
  double get horizontalAccuracy => _horizontalAccuracy;
  int get satelliteCount => _satelliteCount;
  bool get isGpsSignalLow => _isGpsSignalLow;
  bool get usePositionFusion => _usePositionFusion;
  PDRService get pdrService => _pdrService;

  // Set position fusion mode
  set usePositionFusion(bool value) {
    _usePositionFusion = value;
    notifyListeners();
  }

  // Get fused position (combining GPS and PDR data)
  Position? _getFusedPosition() {
    if (!_usePositionFusion || !_pdrService.isRunning) {
      return _currentPosition;
    }

    // If GPS position is recent and accurate, use it
    if (_currentPosition != null) {
      final timeSinceUpdate = DateTime.now().difference(_currentPosition!.timestamp).inSeconds;

      // If GPS is recent and accurate, use it directly
      if (timeSinceUpdate < 5 && _currentPosition!.accuracy < 20) {
        return _currentPosition;
      }
    }

    // If PDR has high confidence, use PDR position
    if (_pdrService.confidence > 0.7 && _pdrService.currentPdrPosition != null) {
      return _pdrService.currentPdrPosition;
    }

    // If GPS is available but not great, fuse with PDR
    if (_currentPosition != null && _pdrService.currentPdrPosition != null) {
      // Calculate weights based on accuracy and confidence
      double gpsWeight = math.max(0.1, math.min(0.9, 1.0 - (_currentPosition!.accuracy / 100.0)));
      double pdrWeight = math.max(0.1, math.min(0.9, _pdrService.confidence));

      // Normalize weights
      double total = gpsWeight + pdrWeight;
      gpsWeight /= total;
      pdrWeight /= total;

      // Create fused position
      return Position(
        latitude: (_currentPosition!.latitude * gpsWeight) + (_pdrService.latitude * pdrWeight),
        longitude: (_currentPosition!.longitude * gpsWeight) + (_pdrService.longitude * pdrWeight),
        timestamp: DateTime.now(),
        accuracy: _currentPosition!.accuracy * gpsWeight + _pdrService.pdrAccuracy * pdrWeight,
        altitude: _currentPosition!.altitude,
        heading: _pdrService.isHeadingStable ? _pdrService.heading : _currentPosition!.heading,
        speed: _currentPosition!.speed,
        speedAccuracy: _currentPosition!.speedAccuracy,
        altitudeAccuracy: _currentPosition!.altitudeAccuracy,
        headingAccuracy: _pdrService.isHeadingStable ? 10.0 : _currentPosition!.headingAccuracy,
      );
    }

    // Fallback: use whatever is available
    return _currentPosition ?? _pdrService.currentPdrPosition;
  }

  // Get current location as a string in format "latitude,longitude"
  String get currentLocationString {
    final position = currentPosition;
    if (position != null) {
      return "${position.latitude},${position.longitude}";
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

      // Initialize PDR system
      await _pdrService.initialize();

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

  // Get current position
  Future<void> getCurrentPosition() async {
    return _getCurrentPositionOptimized();
  }

  // Internal implementation with optimization
  Future<void> _getCurrentPositionOptimized() async {
    try {
      _errorMessage = '';

      final positionFuture = Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      Position position;
      try {
        position = await positionFuture;
      } catch (e) {
        debugPrint('Error getting position: $e');
        rethrow;
      }

      _updatePosition(position);
      debugPrint('Current position: ${position.latitude}, ${position.longitude}');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error getting current location: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // Start tracking location
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      _errorMessage = '';

      // Define location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update if moved 5 meters (reduced from 10)
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

      // Start PDR tracking if initialized
      if (_pdrService.isInitialized && !_pdrService.isRunning) {
        await _pdrService.start(initialPosition: _currentPosition);
      }

      // Start the timer for regular position updates
      _startLocationUpdateTimer();

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error starting location tracking: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // Start timer for regular position updates
  void _startLocationUpdateTimer() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
        Duration(milliseconds: _locationUpdateIntervalMillis),
            (_) => _regularPositionUpdate()
    );
  }

  // Regular position update (called by timer)
  void _regularPositionUpdate() {
    // This ensures we notify listeners periodically even if GPS doesn't update
    // Useful for continuous PDR updates and UI refreshing
    notifyListeners();
  }

  // Optimize position update handling
  void _handlePositionUpdateOptimized(Position position) {
    // Update the position
    _updatePosition(position);

    // Use microtask for notification to avoid blocking main thread immediately
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Centralized position update method
  void _updatePosition(Position position) {
    _currentPosition = position;

    // Extract GPS quality metrics
    _horizontalAccuracy = position.accuracy;

    // Check if GPS signal is considered low quality
    bool wasLowSignal = _isGpsSignalLow;
    _isGpsSignalLow = position.accuracy > 30; // 30 meters accuracy threshold

    // Update PDR with good GPS fix
    if (!_isGpsSignalLow) {
      if (_pdrService.isRunning) {
        _pdrService.updateWithGpsFix(position);
      }
    }

    // Log signal quality changes
    if (wasLowSignal != _isGpsSignalLow) {
      debugPrint(_isGpsSignalLow
          ? 'GPS signal quality degraded (accuracy: ${position.accuracy}m)'
          : 'GPS signal quality improved (accuracy: ${position.accuracy}m)');
    }
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
    _locationUpdateTimer?.cancel();
    _pdrService.stop();

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
    if (currentPosition == null) return false;

    double distance = getDistanceBetween(
        currentPosition!.latitude, currentPosition!.longitude,
        latitude, longitude
    );

    return distance <= threshold;
  }

  @override
  void dispose() {
    stopTracking();
    _pdrService.dispose();
    super.dispose();
  }
}