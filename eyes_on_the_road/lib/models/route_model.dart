// lib/models/route_model.dart
import 'dart:math';

class NavigationRoute {
  final String destination;
  final List<RoutePoint> points;
  final List<RouteStep> steps;
  final double distance; // in meters
  final int estimatedDuration; // in seconds

  NavigationRoute({
    required this.destination,
    required this.points,
    required this.steps,
    required this.distance,
    required this.estimatedDuration,
  });

  // Current progress through the route (0.0 to 1.0)
  double progressForPosition(RoutePoint currentPosition) {
    // Find closest point and estimate progress
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      // Simplified distance calculation (good enough for progress estimation)
      final dist = _calculateSquaredDistance(
          currentPosition.latitude, currentPosition.longitude,
          point.latitude, point.longitude
      );

      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Return progress as fraction of route completed
    return closestIndex / points.length;
  }

  // Get remaining distance (approximate)
  double remainingDistance(RoutePoint currentPosition) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final dist = _calculateSquaredDistance(
          currentPosition.latitude, currentPosition.longitude,
          point.latitude, point.longitude
      );

      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Sum up distances from closest point to end
    double remainingDist = 0;
    for (int i = closestIndex; i < points.length - 1; i++) {
      remainingDist += _calculateDistance(
          points[i].latitude, points[i].longitude,
          points[i + 1].latitude, points[i + 1].longitude
      );
    }

    return remainingDist;
  }

  // Get estimated remaining time
  int remainingDuration(RoutePoint currentPosition) {
    final progress = progressForPosition(currentPosition);
    return ((1 - progress) * estimatedDuration).round();
  }

  // Helper for squared distance (faster than full distance for comparisons)
  double _calculateSquaredDistance(
      double lat1, double lon1,
      double lat2, double lon2
      ) {
    // Simplified squared distance - only for comparison, not actual distance
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  // Helper for actual distance calculation
  double _calculateDistance(
      double lat1, double lon1,
      double lat2, double lon2
      ) {
    // Haversine formula
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Get human-readable distance string
  String get distanceText {
    if (distance < 1000) {
      return '${distance.round()} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  // Get human-readable duration string
  String get durationText {
    final minutes = (estimatedDuration / 60).round();
    if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours hr${hours > 1 ? 's' : ''} $mins min${mins > 1 ? 's' : ''}';
    }
  }
}

class RoutePoint {
  final double latitude;
  final double longitude;

  RoutePoint({
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => '[$latitude, $longitude]';
}

class RouteStep {
  final String instruction;
  final double distance; // in meters
  final int duration; // in seconds
  final RoutePoint startLocation;
  final RoutePoint endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  // Get human-readable distance string
  String get distanceText {
    if (distance < 1000) {
      return '${distance.round()} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  // Get human-readable duration string
  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes < 1) {
      return 'less than 1 min';
    } else if (minutes < 60) {
      return '$minutes min${minutes > 1 ? 's' : ''}';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours hr${hours > 1 ? 's' : ''} $mins min${mins > 1 ? 's' : ''}';
    }
  }
}
