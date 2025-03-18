// lib/utils/polyline_utils.dart
import 'dart:math' as math;

class PolylineUtils {
  /// Decode an encoded polyline string into a list of coordinates
  static List<Map<String, double>> decodePolyline(String encoded) {
    List<Map<String, double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latV = lat / 1e5;
      double lngV = lng / 1e5;
      poly.add({'lat': latV, 'lng': lngV});
    }
    return poly;
  }

  /// Calculate the distance between two geographical coordinates in meters
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6378137.0; // Earth radius in meters

    // Convert degrees to radians
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    // Haversine formula
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c; // Distance in meters
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Calculate the minimum distance from a point to a polyline
  static double distanceToPolyline(
      double pointLat,
      double pointLng,
      List<Map<String, double>> polyline) {
    if (polyline.isEmpty) {
      return double.infinity;
    }

    double minDistance = double.infinity;

    // Check distance to each segment of the polyline
    for (int i = 0; i < polyline.length - 1; i++) {
      double distance = distanceToSegment(
        pointLat,
        pointLng,
        polyline[i]['lat']!,
        polyline[i]['lng']!,
        polyline[i + 1]['lat']!,
        polyline[i + 1]['lng']!,
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Calculate the distance from a point to a line segment
  static double distanceToSegment(
      double pointLat,
      double pointLng,
      double startLat,
      double startLng,
      double endLat,
      double endLng) {
    // Special case: start equals end (segment is a point)
    if (startLat == endLat && startLng == endLng) {
      return calculateDistance(pointLat, pointLng, startLat, startLng);
    }

    // Convert to planar coordinates for simpler calculation
    // This is an approximation that works for small distances
    const double metersPerLat = 111320.0; // Meters per degree latitude
    double metersPerLng = 111320.0 * math.cos(_toRadians(pointLat)); // Meters per degree longitude varies with latitude

    double x = pointLng * metersPerLng;
    double y = pointLat * metersPerLat;

    double x1 = startLng * metersPerLng;
    double y1 = startLat * metersPerLat;

    double x2 = endLng * metersPerLng;
    double y2 = endLat * metersPerLat;

    // Calculate squared length of segment
    double lengthSquared = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);

    // If segment is effectively a point, return distance to the point
    if (lengthSquared < 0.0000001) {
      return math.sqrt((x - x1) * (x - x1) + (y - y1) * (y - y1));
    }

    // Calculate projection ratio of point onto segment line
    double t = math.max(0, math.min(1, ((x - x1) * (x2 - x1) + (y - y1) * (y2 - y1)) / lengthSquared));

    // Calculate nearest point on segment
    double projectionX = x1 + t * (x2 - x1);
    double projectionY = y1 + t * (y2 - y1);

    // Return distance from point to nearest point on segment
    return math.sqrt((x - projectionX) * (x - projectionX) + (y - projectionY) * (y - projectionY));
  }
}