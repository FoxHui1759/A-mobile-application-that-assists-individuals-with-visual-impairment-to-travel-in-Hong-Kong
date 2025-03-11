// navigation_service.dart
// lib/services/navigation_service.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../models/route_model.dart';
import '../models/location_model.dart';

class NavigationService {
  final String _mapApiKey = 'YOUR_MAP_API_KEY'; // Replace with your actual API key
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      // Initialize map services
      _isInitialized = true;
    }
  }

  /// Checks if a string represents coordinates in format "lat,lng"
  bool _isCoordinates(String location) {
    final coordPattern = RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$');
    final match = coordPattern.firstMatch(location.trim());

    if (match != null) {
      final lat = double.parse(match.group(1)!);
      final lng = double.parse(match.group(2)!);
      return -90 <= lat && lat <= 90 && -180 <= lng && lng <= 180;
    }
    return false;
  }

  /// Process location string - handles both coordinates and place names
  Future<String> _preprocessLocation(String location) async {
    if (_isCoordinates(location)) {
      // Use reverse geocoding for coordinates
      final coordParts = location.split(',');
      final lat = double.parse(coordParts[0].trim());
      final lng = double.parse(coordParts[1].trim());

      final geocodeUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?latlng=$lat,$lng'
              '&key=$_mapApiKey'
              '&language=en'
      );

      final response = await http.get(geocodeUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      // If reverse geocoding fails, return the coordinates as is
      return location;
    } else {
      // Use Places API to get formatted address
      final placeUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
              '?input=${Uri.encodeComponent(location)}'
              '&inputtype=textquery'
              '&fields=formatted_address,name,geometry'
              '&key=$_mapApiKey'
      );

      final response = await http.get(placeUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['candidates'] as List).isNotEmpty) {
          return data['candidates'][0]['formatted_address'];
        }

        // Fallback to Geocoding API if Places API fails
        final geocodeUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json'
                '?address=${Uri.encodeComponent(location)}'
                '&key=$_mapApiKey'
        );

        final geocodeResponse = await http.get(geocodeUrl);
        if (geocodeResponse.statusCode == 200) {
          final geocodeData = json.decode(geocodeResponse.body);
          if (geocodeData['status'] == 'OK' && (geocodeData['results'] as List).isNotEmpty) {
            return geocodeData['results'][0]['formatted_address'];
          }
        }
      }
      // If all lookups fail, return the original location string
      return location;
    }
  }

  /// Decode a polyline string into a list of coordinate points
  List<RoutePoint> _decodePolyline(String polyline) {
    List<RoutePoint> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(RoutePoint(
        latitude: lat / 1e5,
        longitude: lng / 1e5,
      ));
    }

    return points;
  }

  /// Fetch elevation data for route points to calculate slope
  Future<double> _computeRouteSlope(String polyline) async {
    final points = _decodePolyline(polyline);
    if (points.length < 2) return 0.0;

    // Sample every nth point to limit API calls
    const stepSize = 5;
    final sampledPoints = <RoutePoint>[];
    for (int i = 0; i < points.length; i += stepSize) {
      if (i < points.length) sampledPoints.add(points[i]);
    }

    // Build locations string for batch elevation request
    final locationsStr = sampledPoints.map((p) =>
    '${p.latitude},${p.longitude}'
    ).join('|');

    try {
      final elevationUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/elevation/json'
              '?locations=$locationsStr'
              '&key=$_mapApiKey'
      );

      final response = await http.get(elevationUrl);
      if (response.statusCode != 200) return 0.0;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return 0.0;

      final elevations = (data['results'] as List)
          .map((res) => res['elevation'] as double)
          .toList();

      double totalSlope = 0.0;
      int segmentCount = 0;

      // Calculate slope between consecutive elevation points
      for (int i = 0; i < elevations.length - 1; i++) {
        final deltaElevation = elevations[i+1] - elevations[i];

        // Calculate horizontal distance between points
        final lat1 = sampledPoints[i].latitude;
        final lng1 = sampledPoints[i].longitude;
        final lat2 = sampledPoints[i+1].latitude;
        final lng2 = sampledPoints[i+1].longitude;

        // Approximate horizontal distance in meters
        final distLat = (lat2 - lat1) * 111111; // 1 degree lat ≈ 111,111 meters
        final avgLat = (lat1 + lat2) / 2;
        final distLng = (lng2 - lng1) * 111111 * cos(avgLat * pi / 180);
        final horizontalDist = sqrt(distLat * distLat + distLng * distLng);

        if (horizontalDist > 0) {
          // Calculate slope percentage
          final slope = (deltaElevation / horizontalDist) * 100.0;
          totalSlope += slope.abs(); // Take absolute value as both up and down are effort
          segmentCount++;
        }
      }

      return segmentCount > 0 ? totalSlope / segmentCount : 0.0;
    } catch (e) {
      debugPrint('Error calculating route slope: $e');
      return 0.0;
    }
  }

  /// Flatten nested steps from the Directions API response
  List<Map<String, dynamic>> _flattenSteps(List<dynamic> steps) {
    List<Map<String, dynamic>> flattened = [];

    for (final step in steps) {
      if (step['steps'] != null && step['steps'] is List && step['steps'].isNotEmpty) {
        // If this step has sub-steps, flatten them recursively
        flattened.addAll(_flattenSteps(step['steps']));
      } else {
        flattened.add(step);
      }
    }

    return flattened;
  }

  /// Evaluate routes based on factors important for visually impaired users
  Future<Map<String, dynamic>?> _evaluateRoutes(List<dynamic> routes) async {
    Map<String, dynamic>? bestRoute;
    double bestScore = double.infinity;

    debugPrint('Evaluating ${routes.length} routes for visually impaired navigation...');

    for (int idx = 0; idx < routes.length; idx++) {
      final route = routes[idx];

      if (route['legs'] == null || (route['legs'] as List).isEmpty) {
        continue;
      }

      final leg = route['legs'][0]; // For walking, typically 1 leg
      List<dynamic> steps = leg['steps'] ?? [];

      // Flatten sub-steps to avoid duplicate instructions
      steps = _flattenSteps(steps);

      // Travel time in seconds
      final travelTime = leg['duration']['value'] as int? ?? 999999;

      // Number of steps (instructions)
      final stepCount = steps.length;

      // Count turn instructions as a proxy for complexity
      int turnCount = 0;
      for (final step in steps) {
        final instructions = step['html_instructions'].toString().toLowerCase();
        if (instructions.contains('turn')) {
          turnCount++;
        }
      }

      // Compute slope factor for the route
      final overviewPolyline = route['overview_polyline']?['points'] as String? ?? '';
      double slopeFactor = 0.0;
      if (overviewPolyline.isNotEmpty) {
        slopeFactor = await _computeRouteSlope(overviewPolyline);
      }

      // Weighted scoring - higher weights for factors more important for visually impaired
      const timeWeight = 1.0;    // Time is important but not the most critical
      const slopeWeight = 2.0;   // Steepness is very important (harder to navigate)
      const stepWeight = 0.5;    // Number of instructions (fewer is better)
      const turnWeight = 1.5;    // Number of turns is very important (disorienting)

      final score = (timeWeight * travelTime) +
          (slopeWeight * slopeFactor) +
          (stepWeight * stepCount) +
          (turnWeight * turnCount);

      debugPrint('Route #${idx + 1} -> '
          'Time: ${travelTime}s, Steps: $stepCount, Turns: $turnCount, '
          'Slope: ${slopeFactor.toStringAsFixed(2)}, Score: ${score.toStringAsFixed(2)}');

      // Update best route if this one is better
      if (score < bestScore) {
        bestScore = score;
        bestRoute = route;
      }
    }

    debugPrint('Best route score: ${bestScore.toStringAsFixed(2)}');
    return bestRoute;
  }

  Future<NavigationRoute?> findRoute(UserLocation currentLocation, String destination) async {
    try {
      // Process origin and destination to ensure they're in the right format
      final origin = await _preprocessLocation('${currentLocation.latitude},${currentLocation.longitude}');
      final processedDestination = await _preprocessLocation(destination);

      debugPrint('Finding route from $origin to $processedDestination');

      // Request routes from the Google Directions API with alternatives
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${Uri.encodeComponent(origin)}'
            '&destination=${Uri.encodeComponent(processedDestination)}'
            '&mode=walking'
            '&alternatives=true'
            '&language=en'
            '&key=$_mapApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;

          if (routes.isEmpty) {
            debugPrint('No routes found');
            return null;
          }

          // Evaluate and select the best route for visually impaired users
          final bestRoute = await _evaluateRoutes(routes);

          if (bestRoute == null) {
            debugPrint('No suitable route found after evaluation');
            return null;
          }

          // Convert to app's NavigationRoute model
          return _convertToNavigationRoute(bestRoute, processedDestination);
        } else {
          debugPrint('Directions API error: ${data['status']}, ${data['error_message'] ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      debugPrint('Error finding route: $e');
    }
    return null;
  }

  /// Convert Google Directions API route to app's NavigationRoute model
  NavigationRoute _convertToNavigationRoute(Map<String, dynamic> route, String destination) {
    final List<RoutePoint> points = [];
    final List<RouteStep> steps = [];

    // Extract route overview polyline for all points
    final overviewPolyline = route['overview_polyline']?['points'] as String? ?? '';
    if (overviewPolyline.isNotEmpty) {
      points.addAll(_decodePolyline(overviewPolyline));
    }

    // Extract steps and flatten them
    final legs = route['legs'] as List;
    if (legs.isNotEmpty) {
      final leg = legs[0];
      final rawSteps = _flattenSteps(leg['steps']);

      // Convert each step
      for (final step in rawSteps) {
        final instruction = _cleanInstructions(step['html_instructions']);
        final distance = step['distance']['value'] as int? ?? 0;
        final duration = step['duration']['value'] as int? ?? 0;

        final startLoc = step['start_location'];
        final endLoc = step['end_location'];

        final startPoint = RoutePoint(
          latitude: startLoc['lat'],
          longitude: startLoc['lng'],
        );

        final endPoint = RoutePoint(
          latitude: endLoc['lat'],
          longitude: endLoc['lng'],
        );

        steps.add(RouteStep(
          instruction: instruction,
          distance: distance.toDouble(),
          duration: duration,
          startLocation: startPoint,
          endLocation: endPoint,
        ));
      }

      return NavigationRoute(
        destination: destination,
        points: points,
        steps: steps,
        distance: leg['distance']['value'] as int? ?? 0,
        estimatedDuration: leg['duration']['value'] as int? ?? 0,
      );
    }

    // Return empty route if processing fails
    return NavigationRoute(
      destination: destination,
      points: [],
      steps: [],
      distance: 0,
      estimatedDuration: 0,
    );
  }

  /// Clean HTML instructions from the Directions API
  String _cleanInstructions(String htmlInstructions) {
    // Remove HTML tags and replace with more speech-friendly format
    String instructions = htmlInstructions
        .replaceAll(RegExp(r'<b>|</b>'), '')
        .replaceAll(RegExp(r'<div.*?>'), ', ')
        .replaceAll('</div>', '')
        .replaceAll('/', ' or ');

    // Fix spaces after commas
    instructions = instructions.replaceAll(', ', ', ');

    return instructions;
  }

  List<String> getNavigationInstructions(NavigationRoute route) {
    // Convert route steps to voice instructions
    // Add distance information to make instructions more helpful
    return route.steps.map((step) {
      final distanceText = step.distance < 100
          ? '${step.distance.round()} meters'
          : '${(step.distance / 1000).toStringAsFixed(1)} kilometers';

      return '${step.instruction} Continue for $distanceText.';
    }).toList();
  }

  Future<NavigationRoute?> recalculateRoute(UserLocation currentLocation, NavigationRoute originalRoute) async {
    // Check if user has deviated from the route
    if (_hasDeviatedFromRoute(currentLocation, originalRoute)) {
      debugPrint('User has deviated from route. Recalculating...');
      return await findRoute(currentLocation, originalRoute.destination);
    }
    return originalRoute;
  }

  bool _hasDeviatedFromRoute(UserLocation currentLocation, NavigationRoute route) {
    // Check if current location is too far from any point on the route
    const double deviationThresholdMeters = 15.0;

    for (final point in route.points) {
      double distance = _calculateDistance(
          currentLocation.latitude, currentLocation.longitude,
          point.latitude, point.longitude
      );

      if (distance < deviationThresholdMeters) {
        return false;
      }
    }

    return true;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Calculate distance using Haversine formula
    const double earthRadius = 6371000; // in meters
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = (
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2)
    );

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  void dispose() {
    // Clean up resources

  }
}