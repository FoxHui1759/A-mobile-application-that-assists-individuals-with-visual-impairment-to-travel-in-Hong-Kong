// sensor.service.dart
// lib/services/sensor_service.dart
import 'package:flutter/foundation.dart';
import 'package:location/location_model.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import '../models/location_model.dart';

class SensorService {
  final Location _location = Location();
  late StreamController<UserLocation> _locationController;
  late StreamController<CompassHeading> _compassController;
  late StreamController<AccelerometerData> _accelerometerController;
  bool _isInitialized = false;

  // Subscriptions to native device sensors
  StreamSubscription? _locationSubscription;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _magnetometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  // Getters for the streams
  Stream<UserLocation> get locationStream => _locationController.stream;
  Stream<CompassHeading> get compassStream => _compassController.stream;
  Stream<AccelerometerData> get accelerometerStream => _accelerometerController.stream;

  // Latest values
  UserLocation? _lastKnownLocation;
  CompassHeading? _lastKnownHeading;
  AccelerometerData? _lastAccelerometerData;

  // Getters for latest values
  UserLocation? get lastKnownLocation => _lastKnownLocation;
  CompassHeading? get lastKnownHeading => _lastKnownHeading;
  AccelerometerData? get lastAccelerometerData => _lastAccelerometerData;

  Future<void> initialize() async {
    if (!_isInitialized) {
      // Initialize location service
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service not enabled');
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission not granted');
        }
      }

      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, // Update interval in milliseconds
      );

      // Initialize stream controllers
      _locationController = StreamController<UserLocation>.broadcast();
      _compassController = StreamController<CompassHeading>.broadcast();
      _accelerometerController = StreamController<AccelerometerData>.broadcast();

      // Start listening to sensors
      _startLocationTracking();
      _startCompassTracking();
      _startAccelerometerTracking();

      _isInitialized = true;
    }
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen((locationData) {
      final location = UserLocation(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        accuracy: locationData.accuracy!,
        timestamp: DateTime.now(),
      );

      _lastKnownLocation = location;
      _locationController.add(location);
    });
  }

  void _startCompassTracking() {
    // We need both magnetometer and accelerometer to calculate compass heading
    List<double> accelerometerValues = [0, 0, 0];
    List<double> magnetometerValues = [0, 0, 0];

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      accelerometerValues = [event.x, event.y, event.z];
      _updateCompassHeading(accelerometerValues, magnetometerValues);
    });

    _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      magnetometerValues = [event.x, event.y, event.z];
      _updateCompassHeading(accelerometerValues, magnetometerValues);
    });
  }

  void _updateCompassHeading(List<double> accelerometerValues, List<double> magnetometerValues) {
    // Calculate compass heading using accelerometer and magnetometer data
    // This is a simplified calculation
    double x = magnetometerValues[0];
    double y = magnetometerValues[1];
    double z = magnetometerValues[2];

    double heading = atan2(y, x) * (180 / pi);
    if (heading < 0) heading += 360;

    final compassHeading = CompassHeading(
      heading: heading,
      accuracy: 1.0, // Mock accuracy
      timestamp: DateTime.now(),
    );

    _lastKnownHeading = compassHeading;
    _compassController.add(compassHeading);
  }

  void _startAccelerometerTracking() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final accelerometerData = AccelerometerData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );

      _lastAccelerometerData = accelerometerData;
      _accelerometerController.add(accelerometerData);
    });
  }

  Future<UserLocation> getCurrentLocation() async {
    if (!_isInitialized) await initialize();

    final locationData = await _location.getLocation();
    final location = UserLocation(
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      accuracy: locationData.accuracy!,
      timestamp: DateTime.now(),
    );

    _lastKnownLocation = location;
    return location;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _locationController.close();
    _compassController.close();
    _accelerometerController.close();
  }
}