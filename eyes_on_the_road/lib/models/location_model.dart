// lib/models/location_model.dart
import 'dart:math';

class UserLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  double distanceTo(UserLocation other) {
    // Calculate distance between two locations using Haversine formula
    const double earthRadius = 6371000; // meters
    double dLat = _degreesToRadians(other.latitude - latitude);
    double dLon = _degreesToRadians(other.longitude - longitude);

    double a = (
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_degreesToRadians(latitude)) * cos(_degreesToRadians(other.latitude)) *
                sin(dLon / 2) * sin(dLon / 2)
    );

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double bearingTo(UserLocation other) {
    // Calculate initial bearing from this location to another
    double startLat = _degreesToRadians(latitude);
    double startLng = _degreesToRadians(longitude);
    double destLat = _degreesToRadians(other.latitude);
    double destLng = _degreesToRadians(other.longitude);

    double y = sin(destLng - startLng) * cos(destLat);
    double x = cos(startLat) * sin(destLat) -
        sin(startLat) * cos(destLat) * cos(destLng - startLng);

    double bearing = atan2(y, x);
    bearing = _radiansToDegrees(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  static double _radiansToDegrees(double radians) {
    return radians * (180.0 / pi);
  }
}

class CompassHeading {
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  CompassHeading({
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });

  // Get cardinal direction (N, NE, E, etc.)
  String get cardinalDirection {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  // Get textual description
  String get directionText {
    const fullDirections = [
      'North', 'Northeast', 'East', 'Southeast',
      'South', 'Southwest', 'West', 'Northwest'
    ];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return fullDirections[index];
  }
}

class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get magnitude => sqrt(x * x + y * y + z * z);

  bool get isMoving => magnitude > 1.2; // Threshold for detecting movement

  // Movement state categorization
  String get movementState {
    if (magnitude < 1.05) return 'still';
    if (magnitude < 1.5) return 'walking';
    if (magnitude < 2.5) return 'walking_fast';
    return 'running';
  }
}