// lib/services/google_maps_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class GoogleMapsService {
  final String apiKey;

  GoogleMapsService({required this.apiKey});

  /// Check if the location string is in latitude,longitude format.
  bool isCoordinates(String location) {
    final RegExp coordPattern =
    RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$');
    final match = coordPattern.firstMatch(location.trim());

    if (match != null) {
      final lat = double.parse(match.group(1)!);
      final lng = double.parse(match.group(2)!);
      return (-90 <= lat && lat <= 90 && -180 <= lng && lng <= 180);
    }
    return false;
  }

  /// Get coordinates from a location string if it's in lat,lng format
  Map<String, double>? extractCoordinates(String location) {
    final RegExp coordPattern =
    RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$');
    final match = coordPattern.firstMatch(location.trim());

    if (match != null) {
      final lat = double.parse(match.group(1)!);
      final lng = double.parse(match.group(2)!);
      if (-90 <= lat && lat <= 90 && -180 <= lng && lng <= 180) {
        return {'lat': lat, 'lng': lng};
      }
    }
    return null;
  }

  /// Search for a place using the Google Places API or Geocoding API as fallback
  Future<String> getPlaceLocation(String placeName, {bool useGeocoding = true}) async {
    const placeUrl = 'https://maps.googleapis.com/maps/api/place/findplacefromtext/json';
    final params = {
      'input': '$placeName, Hong Kong',
      'inputtype': 'textquery',
      'fields': 'formatted_address,name,geometry',
      'language': 'zh-TW',
      'key': apiKey
    };

    try {
      final uri = Uri.parse(placeUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      final result = json.decode(response.body);

      if (result['status'] == 'OK' &&
          result.containsKey('candidates') &&
          result['candidates'].isNotEmpty) {
        final place = result['candidates'][0];
        return place['formatted_address'];
      } else if (useGeocoding) {
        // Use Geocoding as fallback
        const geocodeUrl = "https://maps.googleapis.com/maps/api/geocode/json";
        final geocodeParams = {
          'address': '$placeName, Hong Kong',
          'key': apiKey,
          'region': 'hk',
          'language': 'zh-TW'
        };

        final geocodeUri = Uri.parse(geocodeUrl).replace(queryParameters: geocodeParams);
        final geocodeResponse = await http.get(geocodeUri);
        final geocodeResult = json.decode(geocodeResponse.body);

        if (geocodeResult['status'] == 'OK' &&
            geocodeResult.containsKey('results') &&
            geocodeResult['results'].isNotEmpty) {
          return geocodeResult['results'][0]['formatted_address'];
        }
      }

      throw Exception('Location not found: $placeName');
    } catch (e) {
      throw Exception('Error finding place: $e');
    }
  }

  /// If location is lat,lng coordinates, convert to a proper place name
  Future<String> preprocessCoordinates(String location) async {
    if (isCoordinates(location)) {
      final coords = extractCoordinates(location)!;

      // Use reverse geocoding for coordinates
      const geocodeUrl = "https://maps.googleapis.com/maps/api/geocode/json";
      final params = {
        'latlng': '${coords['lat']},${coords['lng']}',
        'key': apiKey,
        'region': 'hk',
        'language': 'zh-TW'
      };

      final uri = Uri.parse(geocodeUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      final result = json.decode(response.body);

      if (result['status'] == 'OK' &&
          result.containsKey('results') &&
          result['results'].isNotEmpty) {
        return result['results'][0]['formatted_address'];
      } else {
        throw Exception('No valid address found for coordinates: $location');
      }
    } else {
      return await getPlaceLocation(location);
    }
  }

  /// Decode a polyline that encodes a series of lat/lng points
  List<Map<String, double>> decodePolyline(String polyline) {
    List<Map<String, double>> points = [];
    int index = 0;
    double lat = 0.0;
    double lng = 0.0;

    while (index < polyline.length) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      while (true) {
        int b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      double dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toDouble();
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      while (true) {
        int b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      double dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toDouble();
      lng += dlng;

      points.add({'lat': lat / 1e5, 'lng': lng / 1e5});
    }

    return points;
  }

  /// Compute approximate slope factor for a route
  Future<double> computeRouteSlope(String routePolyline) async {
    final points = decodePolyline(routePolyline);
    if (points.length < 2) {
      return 0.0; // No slope if there's only one or no point
    }

    // Elevation API (batch request)
    const elevationUrl = "https://maps.googleapis.com/maps/api/elevation/json";
    // Sample every nth point to limit API calls
    const stepSize = 5;
    final sampledPoints = <Map<String, double>>[];

    for (int i = 0; i < points.length; i += stepSize) {
      if (i < points.length) {
        sampledPoints.add(points[i]);
      }
    }

    final locationsStr = sampledPoints
        .map((p) => "${p['lat']},${p['lng']}")
        .join('|');

    final params = {
      'locations': locationsStr,
      'key': apiKey
    };

    try {
      final uri = Uri.parse(elevationUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      final elevationData = json.decode(response.body);

      if (elevationData['status'] != 'OK') {
        return 0.0;
      }

      final elevations = elevationData['results']
          .map<double>((res) => res['elevation'] as double)
          .toList();

      double totalSlope = 0.0;
      int segmentCount = 0;

      for (int i = 0; i < elevations.length - 1; i++) {
        final deltaElevation = elevations[i + 1] - elevations[i];
        // Approximate horizontal distance between sampled points
        final lat1 = sampledPoints[i]['lat']!;
        final lng1 = sampledPoints[i]['lng']!;
        final lat2 = sampledPoints[i + 1]['lat']!;
        final lng2 = sampledPoints[i + 1]['lng']!;

        // Very rough approximation for horizontal distance in meters
        final distLat = (lat2 - lat1) * 111111;
        final avgLat = (lat1 + lat2) / 2;
        final distLng = (lng2 - lng1) * 111111 * math.cos(avgLat * math.pi / 180).abs();
        final horizontalDist = math.sqrt(distLat * distLat + distLng * distLng);

        double slope = 0.0;
        if (horizontalDist > 0) {
          slope = (deltaElevation / horizontalDist) * 100.0; // Slope in %
        }

        totalSlope += slope.abs();
        segmentCount += 1;
      }

      final avgSlope = totalSlope / math.max(1, segmentCount);
      return avgSlope;
    } catch (e) {
      print('Error computing route slope: $e');
      return 0.0;
    }
  }

  /// Recursively flattens nested steps in directions response
  List<dynamic> flattenSteps(List<dynamic> steps) {
    List<dynamic> flattened = [];

    for (var step in steps) {
      if (step.containsKey('steps') &&
          step['steps'] is List &&
          step['steps'].isNotEmpty) {
        // If this step has sub-steps, flatten them recursively
        flattened.addAll(flattenSteps(step['steps']));
      } else {
        flattened.add(step);
      }
    }

    return flattened;
  }

  /// Evaluate routes based on multiple factors
  Future<Map<String, dynamic>> evaluateRoutes(List<dynamic> routesData) async {
    Map<String, dynamic>? bestRoute;
    double bestScore = double.infinity;

    print("Evaluating routes...");

    for (int idx = 0; idx < routesData.length; idx++) {
      final route = routesData[idx];

      if (!route.containsKey('legs') || route['legs'].isEmpty) {
        continue; // Skip if no legs
      }

      final leg = route['legs'][0]; // For walking, typically 1 leg
      final steps = leg.containsKey('steps') ? List<dynamic>.from(leg['steps']) : <dynamic>[];

      // Flatten sub-steps to avoid duplicate instructions
      final flattenedSteps = flattenSteps(steps);

      // Travel time in seconds
      final travelTime = leg.containsKey('duration')
          ? leg['duration']['value'] as int
          : 999999;

      // Number of (flattened) steps
      final stepCount = flattenedSteps.length;

      // Count "turn" instructions as a proxy for complexity
      int turnCount = 0;
      for (var s in flattenedSteps) {
        final htmlInstructions = s.containsKey('html_instructions')
            ? s['html_instructions'].toString().toLowerCase()
            : '';
        if (htmlInstructions.contains('turn')) {
          turnCount += 1;
        }
      }

      // Compute slope
      double slopeFactor = 0.0;
      if (route.containsKey('overview_polyline') &&
          route['overview_polyline'].containsKey('points')) {
        final overviewPolyline = route['overview_polyline']['points'].toString();
        slopeFactor = await computeRouteSlope(overviewPolyline);
      }

      // Weighted scoring
      const timeWeight = 1.0;
      const slopeWeight = 2.0;
      const stepWeight = 0.5;
      const turnWeight = 0.75;

      final score = (timeWeight * travelTime) +
          (slopeWeight * slopeFactor) +
          (stepWeight * stepCount) +
          (turnWeight * turnCount);

      print("Route #${idx + 1} -> "
          "Time: ${travelTime}s, Steps: $stepCount, Turns: $turnCount, "
          "Slope: ${slopeFactor.toStringAsFixed(2)}, Score: ${score.toStringAsFixed(2)}");

      // Update best route if this one is better
      if (score < bestScore) {
        bestScore = score;
        bestRoute = route;
      }
    }

    if (bestScore != double.infinity && bestRoute != null) {
      print("\nBest score: ${bestScore.toStringAsFixed(2)}\n");
      return bestRoute;
    } else {
      print("\nNo valid routes found.\n");
      throw Exception("No valid routes found");
    }
  }

  /// Extract important navigation information from a step
  Map<String, dynamic> processStep(dynamic step) {
    final distance = step.containsKey('distance') ? step['distance']['text'] : 'N/A';
    final duration = step.containsKey('duration') ? step['duration']['text'] : 'N/A';

    // Clean up HTML in instructions
    var instructions = step.containsKey('html_instructions')
        ? step['html_instructions'].toString()
        : '';

    instructions = instructions.replaceAll(RegExp(r'<b>'), '')
        .replaceAll(RegExp(r'</b>'), '')
        .replaceAll(RegExp(r'<div[^>]*>'), ', ')
        .replaceAll(RegExp(r'</div>'), '');

    return {
      'instructions': instructions,
      'distance': distance,
      'duration': duration,
      'start_location': step.containsKey('start_location') ? step['start_location'] : null,
      'end_location': step.containsKey('end_location') ? step['end_location'] : null,
      'maneuver': step.containsKey('maneuver') ? step['maneuver'] : '',
    };
  }

  /// Get navigation path from origin to destination
  Future<Map<String, dynamic>> getNavigationPath(String origin, String destination) async {
    print("Getting the path from $origin to $destination...");

    const url = "https://maps.googleapis.com/maps/api/directions/json";
    final params = {
      'origin': origin,
      'destination': destination,
      'mode': 'walking',
      'departure_time': 'now',
      'alternatives': 'true',
      'language': 'zh-HK',
      'key': apiKey
    };

    try {
      final uri = Uri.parse(url).replace(queryParameters: params);
      final response = await http.get(uri);
      final res = json.decode(response.body);

      if (res['status'] == "OK") {
        final routes = res.containsKey('routes')
            ? List<dynamic>.from(res['routes'])
            : <dynamic>[];

        print("Number of routes returned by Directions API: ${routes.length}");

        if (routes.isEmpty) {
          throw Exception("No routes found. Please try different locations.");
        }

        // Evaluate and pick best route
        final bestRoute = await evaluateRoutes(routes);

        // Find chosen route index
        int chosenIndex = -1;
        for (int i = 0; i < routes.length; i++) {
          if (routes[i] == bestRoute) {
            chosenIndex = i;
            break;
          }
        }

        print("Chosen Route Index: ${chosenIndex + 1} (0-based index: $chosenIndex)");

        // Get legs and flatten steps
        final legs = bestRoute.containsKey('legs')
            ? List<dynamic>.from(bestRoute['legs'])
            : <dynamic>[];

        if (legs.isEmpty) {
          throw Exception("No legs in the chosen route.");
        }

        final steps = legs[0].containsKey('steps')
            ? List<dynamic>.from(legs[0]['steps'])
            : <dynamic>[];
        final flattenedSteps = flattenSteps(steps);

        // Process steps into a more usable format
        final processedSteps = <Map<String, dynamic>>[];
        for (int i = 0; i < flattenedSteps.length; i++) {
          processedSteps.add(processStep(flattenedSteps[i]));
        }

        return {
          'route': bestRoute,
          'all_routes': routes,
          'steps': processedSteps,
          'total_distance': legs[0]['distance']['text'],
          'total_duration': legs[0]['duration']['text'],
          'start_address': legs[0]['start_address'],
          'end_address': legs[0]['end_address'],
        };
      } else {
        throw Exception("Directions API error: ${res['status']}");
      }
    } catch (e) {
      print("Error in getNavigationPath: $e");
      throw Exception("Failed to get navigation path: $e");
    }
  }
}