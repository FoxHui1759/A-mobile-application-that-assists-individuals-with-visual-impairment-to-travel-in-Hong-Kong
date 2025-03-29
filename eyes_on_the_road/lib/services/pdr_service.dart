// lib/services/pdr_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

class PDRService extends ChangeNotifier {
  // PDR state
  bool _isInitialized = false;
  bool _isRunning = false;
  bool _hasPermission = false;
  String _errorMessage = '';

  // Sensor data subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Sensor data
  AccelerometerEvent? _lastAccelerometerEvent;
  MagnetometerEvent? _lastMagnetometerEvent;

  // Step detection variables
  final double _stepThreshold = 11.5; // Adjust based on testing
  bool _isStepDetected = false;
  int _stepCount = 0;
  double _averageStepLength = 0.75; // Default average step length in meters
  DateTime? _lastStepTime;
  final List<double> _accelerationMagnitudes = [];
  static const int _magnitudeHistorySize = 10;

  // Heading detection
  double _heading = 0.0; // in degrees, 0 = North, 90 = East
  double _headingOffset = 0.0; // Calibration offset
  double _lastHeading = 0.0;
  bool _isHeadingStable = false;

  // Position tracking
  Position? _lastGpsPosition;
  double _lastLatitude = 0.0;
  double _lastLongitude = 0.0;
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  double _pdrAccuracy = 0.0; // Estimated accuracy in meters
  int _stepsSinceGpsFix = 0;

  // PDR drift correction - increase with more steps without GPS
  double _driftFactor = 0.0;
  static const double _maxDriftFactor = 0.95; // Cap to prevent complete loss

  // Confidence in PDR data (0.0 - 1.0)
  double _confidence = 0.5;

  // Timer for sensor processing
  Timer? _processingTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  String get errorMessage => _errorMessage;
  int get stepCount => _stepCount;
  double get heading => _heading;
  bool get isHeadingStable => _isHeadingStable;
  double get latitude => _currentLatitude;
  double get longitude => _currentLongitude;
  double get confidence => _confidence;
  double get pdrAccuracy => _pdrAccuracy;

  // Get position in a format compatible with location service
  Position? get currentPdrPosition {
    if (_currentLatitude == 0.0 || _currentLongitude == 0.0) return null;

    // Create a position object with estimated PDR data
    return Position(
      latitude: _currentLatitude,
      longitude: _currentLongitude,
      timestamp: DateTime.now(),
      accuracy: _pdrAccuracy,
      altitude: _lastGpsPosition?.altitude ?? 0.0,
      heading: _heading,
      speed: _calculateCurrentSpeed(),
      speedAccuracy: 5.0, // Higher value to indicate less certainty
      altitudeAccuracy: _lastGpsPosition?.altitudeAccuracy ?? 0.0,
      headingAccuracy: _isHeadingStable ? 10.0 : 45.0, // Better accuracy when stable
    );
  }

  // Calculate current speed based on step frequency
  double _calculateCurrentSpeed() {
    if (_lastStepTime == null) return 0.0;

    final now = DateTime.now();
    final timeSinceLastStep = now.difference(_lastStepTime!).inMilliseconds;

    // If no steps recently, speed is zero
    if (timeSinceLastStep > 2000) return 0.0;

    // Calculate speed based on step frequency and length
    final stepFrequency = 1000 / timeSinceLastStep.toDouble(); // steps per second
    return stepFrequency * _averageStepLength; // meters per second
  }

  // Initialize the PDR service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _errorMessage = '';
    try {
      _hasPermission = await _checkSensorPermissions();

      if (!_hasPermission) {
        _errorMessage = 'Sensor permissions are required for PDR.';
        debugPrint(_errorMessage);
        notifyListeners();
        return false;
      }

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize PDR: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Check for sensor permissions
  Future<bool> _checkSensorPermissions() async {
    // For sensors_plus, no explicit permissions needed on most devices
    // But we should check if sensors are available
    try {
      // Test accelerometer access by just checking if we can subscribe to the stream
      final accelerometerStream = accelerometerEvents.timeout(
        const Duration(seconds: 2),
        onTimeout: (sink) {
          sink.addError(TimeoutException('Accelerometer not responding'));
          sink.close();
        },
      );

      await accelerometerStream.first;

      // Test magnetometer access
      final magnetometerStream = magnetometerEvents.timeout(
        const Duration(seconds: 2),
        onTimeout: (sink) {
          sink.addError(TimeoutException('Magnetometer not responding'));
          sink.close();
        },
      );

      await magnetometerStream.first;

      return true;
    } catch (e) {
      debugPrint('Sensor permission check failed: $e');
      return false;
    }
  }

  // Start PDR tracking
  Future<bool> start({Position? initialPosition}) async {
    if (!_isInitialized) {
      bool initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isRunning) return true;

    try {
      // Initialize with current GPS position if available
      if (initialPosition != null) {
        _lastGpsPosition = initialPosition;
        _lastLatitude = initialPosition.latitude;
        _lastLongitude = initialPosition.longitude;
        _currentLatitude = initialPosition.latitude;
        _currentLongitude = initialPosition.longitude;
        _stepsSinceGpsFix = 0;
        _driftFactor = 0.0;
        _confidence = 0.9; // High confidence with recent GPS
      }

      // Start collecting sensor data
      _startSensorSubscriptions();

      // Start the processing timer
      _processingTimer = Timer.periodic(const Duration(milliseconds: 100), _processSensorData);

      _isRunning = true;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start PDR: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Stop PDR tracking
  void stop() {
    if (!_isRunning) return;

    // Cancel subscriptions
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _processingTimer?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
    _processingTimer = null;

    _isRunning = false;
    notifyListeners();
  }

  // Start sensor subscriptions
  void _startSensorSubscriptions() {
    // Accelerometer for step detection
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _lastAccelerometerEvent = event;
    });

    // Gyroscope for orientation changes - we don't store this value directly
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      // Process gyroscope data directly if needed
      // We don't store the event to avoid the unused variable warning
    });

    // Magnetometer for heading
    _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      _lastMagnetometerEvent = event;
    });
  }

  // Process sensor data periodically
  void _processSensorData(Timer timer) {
    if (_lastAccelerometerEvent != null) {
      _detectSteps(_lastAccelerometerEvent!);
    }

    if (_lastMagnetometerEvent != null) {
      _detectHeading(_lastMagnetometerEvent!);
    }

    // Update confidence based on time since last GPS fix
    _updateConfidence();

    // Notify listeners about updates
    notifyListeners();
  }

  // Step detection algorithm
  void _detectSteps(AccelerometerEvent accelerometerEvent) {
    // Calculate magnitude of acceleration vector
    final double magnitude = math.sqrt(
        accelerometerEvent.x * accelerometerEvent.x +
            accelerometerEvent.y * accelerometerEvent.y +
            accelerometerEvent.z * accelerometerEvent.z
    );

    // Add to rolling window
    _accelerationMagnitudes.add(magnitude);
    if (_accelerationMagnitudes.length > _magnitudeHistorySize) {
      _accelerationMagnitudes.removeAt(0);
    }

    // Need enough samples to detect steps
    if (_accelerationMagnitudes.length < _magnitudeHistorySize) {
      return;
    }

    // Calculate average magnitude
    double sum = 0;
    for (double mag in _accelerationMagnitudes) {
      sum += mag;
    }
    double averageMagnitude = sum / _accelerationMagnitudes.length;

    // Step detection using peak detection
    if (magnitude > _stepThreshold && magnitude > averageMagnitude * 1.2 && !_isStepDetected) {
      _isStepDetected = true;
      _onStepDetected();
    } else if (magnitude < _stepThreshold - 1.0) {
      _isStepDetected = false;
    }
  }

  // Called when a step is detected
  void _onStepDetected() {
    final now = DateTime.now();

    // Filter out too frequent steps (debounce)
    if (_lastStepTime != null) {
      final duration = now.difference(_lastStepTime!).inMilliseconds;
      if (duration < 250) { // Minimum 250ms between steps (max 4 steps/second)
        return;
      }
    }

    _stepCount++;
    _lastStepTime = now;
    _stepsSinceGpsFix++;

    // Update position based on step and heading
    _updatePosition();

    // Increase drift factor based on steps since last GPS fix
    // Each step adds a small amount to the drift factor
    _driftFactor = math.min(_maxDriftFactor, _driftFactor + 0.001);
  }

  // Heading detection from magnetometer
  void _detectHeading(MagnetometerEvent magnetometerEvent) {
    // Calculate heading based on magnetometer data (simplified)
    double x = magnetometerEvent.x;
    double y = magnetometerEvent.y;

    // Calculate heading in degrees (0 = North, 90 = East)
    double newHeading = (math.atan2(y, x) * 180 / math.pi) + _headingOffset;

    // Normalize to 0-360 degrees
    newHeading = (newHeading + 360) % 360;

    // Apply low-pass filter to smooth heading
    double alpha = 0.3; // Smoothing factor
    _heading = (_heading * (1 - alpha)) + (newHeading * alpha);

    // Check if heading is stable by comparing with last heading
    double headingDifference = (_heading - _lastHeading).abs();
    if (headingDifference > 180) {
      headingDifference = 360 - headingDifference;
    }

    _isHeadingStable = headingDifference < 10; // Less than 10 degrees change
    _lastHeading = _heading;
  }

  // Calibrate heading based on GPS course
  void calibrateHeading(double gpsCourse) {
    if (gpsCourse >= 0 && _lastMagnetometerEvent != null) {
      // Current raw heading without offset
      double rawHeading = (math.atan2(_lastMagnetometerEvent!.y, _lastMagnetometerEvent!.x) * 180 / math.pi);

      // Calculate new offset
      _headingOffset = gpsCourse - rawHeading;

      // Update current heading
      _heading = gpsCourse;
      _lastHeading = gpsCourse;

      // Reset heading stability flag
      _isHeadingStable = true;
    }
  }

  // Update current position based on step and heading
  void _updatePosition() {
    if (_lastLatitude == 0.0 || _lastLongitude == 0.0) return;

    // Convert heading to radians
    double headingRadians = _heading * math.pi / 180;

    // Calculate displacement
    double dx = _averageStepLength * math.sin(headingRadians);
    double dy = _averageStepLength * math.cos(headingRadians);

    // Convert displacement to latitude/longitude changes
    // Earth's radius is approximately 6,371,000 meters
    const double earthRadius = 6371000.0;

    // Calculate new position
    double newLatitude = _currentLatitude + (dy / earthRadius) * (180 / math.pi);
    double newLongitude = _currentLongitude + (dx / earthRadius) * (180 / math.pi) /
        math.cos(_currentLatitude * math.pi / 180);

    // Update current position
    _currentLatitude = newLatitude;
    _currentLongitude = newLongitude;

    // Update PDR accuracy based on steps since GPS fix
    _pdrAccuracy = math.max(5.0, 3.0 + (_stepsSinceGpsFix * 0.2));
  }

  // Update PDR confidence
  void _updateConfidence() {
    // Confidence decreases with time since last GPS fix and increases with heading stability
    double baseConfidence = math.max(0.1, 1.0 - _driftFactor);

    // Adjust based on heading stability
    if (_isHeadingStable) {
      baseConfidence = math.min(1.0, baseConfidence * 1.2);
    } else {
      baseConfidence = math.max(0.1, baseConfidence * 0.9);
    }

    // Smoothly update confidence
    _confidence = _confidence * 0.8 + baseConfidence * 0.2;
  }

  // Update PDR with new GPS fix
  void updateWithGpsFix(Position position) {
    if (!_isRunning) return;

    _lastGpsPosition = position;

    // If GPS accuracy is good enough, use it to correct PDR
    if (position.accuracy < 20) { // Only use GPS if accuracy is less than 20 meters
      // Calculate heading from GPS if moving
      if (position.speed > 0.5) { // Only use course if actually moving
        calibrateHeading(position.heading);
      }

      // Calculate step length from recent movement if possible
      if (_stepsSinceGpsFix > 0) {
        final double distance = Geolocator.distanceBetween(
            _lastLatitude,
            _lastLongitude,
            position.latitude,
            position.longitude
        );

        // Update average step length if distance is reasonable
        if (distance > 1.0 && distance < _stepsSinceGpsFix * 2.0) {
          _averageStepLength = distance / _stepsSinceGpsFix;

          // Clamp step length to reasonable values
          _averageStepLength = math.max(0.5, math.min(1.2, _averageStepLength));
        }
      }

      // Reset position to GPS coordinates
      _lastLatitude = position.latitude;
      _lastLongitude = position.longitude;
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;

      // Reset drift tracking
      _stepsSinceGpsFix = 0;
      _driftFactor = 0.0;
      _confidence = 0.9; // High confidence with fresh GPS
    }

    notifyListeners();
  }

  // Reset PDR state
  void reset() {
    _stepCount = 0;
    _stepsSinceGpsFix = 0;
    _driftFactor = 0.0;
    _confidence = 0.5;

    if (_lastGpsPosition != null) {
      _lastLatitude = _lastGpsPosition!.latitude;
      _lastLongitude = _lastGpsPosition!.longitude;
      _currentLatitude = _lastGpsPosition!.latitude;
      _currentLongitude = _lastGpsPosition!.longitude;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}