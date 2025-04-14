// lib/services/google_maps_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class GoogleMapsService {
  final String apiKey;
  final Map<String, dynamic> _responseCache = {};

  // Store the last route response to access alternative routes
  Map<String, dynamic>? _lastRoutesResponse;
  static const int _maxElevationSamples = 300;

  GoogleMapsService({required this.apiKey});

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Map<String, dynamic>> _makeApiRequest(Uri uri, {bool useCache = true}) async {
    final cacheKey = uri.toString();
    if (useCache && _responseCache.containsKey(cacheKey)) {
      return _responseCache[cacheKey];
    }

    try {
      // Check connectivity first
      if (!await _checkConnectivity()) {
        throw Exception('No internet connection. Please check your network settings and try again.');
      }

      // Set timeout for the request
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('The connection has timed out. Please try again.'),
      );

      // Check response status
      if (response.statusCode == 200) {
        // Decode JSON on the main thread since we're already handling the network request here
        final result = json.decode(response.body) as Map<String, dynamic>;

        // Cache successful responses
        if (useCache) {
          _responseCache[cacheKey] = result;
        }

        return result;
      } else if (response.statusCode == 403) {
        throw Exception('API key may be invalid or restricted. Status: ${response.statusCode}');
      } else {
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Socket Exception: $e');
      throw Exception('Network error: Unable to connect to Google Maps. Please check your internet connection and try again.');
    } on HttpException catch (e) {
      debugPrint('HTTP Exception: $e');
      throw Exception('HTTP error: $e');
    } on FormatException catch (e) {
      debugPrint('Format Exception: $e');
      throw Exception('Data format error: $e');
    } catch (e) {
      debugPrint('General Exception: $e');
      throw Exception('Error connecting to Google Maps: $e');
    }
  }

  // Check if the location string is in latitude,longitude format.
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

  // Get coordinates from a location string if it's in lat,lng format
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

  // Search for a place using the Google Places API or Geocoding API as fallback
  Future<String> getPlaceLocation(String placeName, {bool useGeocoding = true}) async {
    try {
      if (!await _checkConnectivity()) {
        throw Exception('No internet connection. Please check your network settings and try again.');
      }

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
        final result = await _makeApiRequest(uri);

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
          final geocodeResult = await _makeApiRequest(geocodeUri);

          if (geocodeResult['status'] == 'OK' &&
              geocodeResult.containsKey('results') &&
              geocodeResult['results'].isNotEmpty) {
            return geocodeResult['results'][0]['formatted_address'];
          }
        }

        throw Exception('Location not found: $placeName');
      } catch (e) {
        debugPrint('Error in getPlaceLocation: $e');
        throw Exception('Error finding place: $e');
      }
    } catch (e) {
      debugPrint('Error in getPlaceLocation: $e');
      rethrow; // Re-throw to be handled by the caller
    }
  }

  // If location is lat,lng coordinates, convert to a proper place name
  Future<String> preprocessCoordinates(String location) async {
    try {
      if (isCoordinates(location)) {
        final coords = extractCoordinates(location)!;

        if (!await _checkConnectivity()) {
          return "Location (${coords['lat']!.toStringAsFixed(6)}, ${coords['lng']!.toStringAsFixed(6)})";
        }

        // Use reverse geocoding for coordinates
        const geocodeUrl = "https://maps.googleapis.com/maps/api/geocode/json";
        final params = {
          'latlng': '${coords['lat']},${coords['lng']}',
          'key': apiKey,
          'region': 'hk',
          'language': 'en-US'
        };

        final uri = Uri.parse(geocodeUrl).replace(queryParameters: params);
        final result = await _makeApiRequest(uri);

        if (result['status'] == 'OK' &&
            result.containsKey('results') &&
            result['results'].isNotEmpty) {
          return result['results'][0]['formatted_address'];
        } else {
          // If reverse geocoding fails, return a formatted string of the coordinates
          return "Location (${coords['lat']!.toStringAsFixed(6)}, ${coords['lng']!.toStringAsFixed(6)})";
        }
      } else {
        return await getPlaceLocation(location);
      }
    } catch (e) {
      debugPrint('Error in preprocessCoordinates: $e');

      if (isCoordinates(location)) {
        final coords = extractCoordinates(location)!;
        return "Location (${coords['lat']!.toStringAsFixed(6)}, ${coords['lng']!.toStringAsFixed(6)})";
      }

      return location;
    }
  }

  Future<List<Map<String, double>>> decodePolylineAsync(String polyline) async {
    return compute(_decodePolyline, polyline);
  }

  static List<Map<String, double>> _decodePolyline(String polyline) {
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

  // Get elevation data for route points using the Google Elevation API
  Future<List<Map<String, dynamic>>> getElevationData(List<Map<String, double>> routePoints) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection. Please check your network settings and try again.');
    }

    List<Map<String, double>> sampledPoints = [];
    if (routePoints.length > _maxElevationSamples) {
      // Calculate sampling interval
      int interval = (routePoints.length / _maxElevationSamples).ceil();
      sampledPoints.add(routePoints.first);

      for (int i = interval; i < routePoints.length - 1; i += interval) {
        sampledPoints.add(routePoints[i]);
      }

      sampledPoints.add(routePoints.last);
    } else {
      sampledPoints = List.from(routePoints);
    }

    final locationString = sampledPoints.map((point) =>
    "${point['lat']},${point['lng']}"
    ).join('|');

    // Setup API request
    const url = "https://maps.googleapis.com/maps/api/elevation/json";
    final params = {
      'locations': locationString,
      'key': apiKey
    };

    try {
      final uri = Uri.parse(url).replace(queryParameters: params);
      final res = await _makeApiRequest(uri, useCache: true);

      if (res['status'] == "OK") {
        // Extract elevation results
        final results = res['results'] as List;
        List<Map<String, dynamic>> elevationData = [];

        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          elevationData.add({
            'lat': result['location']['lat'],
            'lng': result['location']['lng'],
            'elevation': result['elevation'],
            'resolution': result['resolution'],
            'index': i, // Keep track of position in route
          });
        }

        return elevationData;
      } else {
        throw Exception("Elevation API error: ${res['status']}");
      }
    } catch (e) {
      debugPrint("Error getting elevation data: $e");
      return []; // Return empty list on error - will fall back to default slope calculation
    }
  }

  Future<Map<String, dynamic>> computeRouteSlopeMetrics(String polyline) async {
    try {
      // Decode polyline to get path points
      final points = _decodePolyline(polyline);

      if (points.length < 2) {
        return {
          'avgSlope': 0.0,
          'maxSlope': 0.0,
          'totalAscent': 0.0,
          'totalDescent': 0.0,
          'slopeFactor': 0.0
        };
      }

      // Get elevation data for path points
      final elevationData = await getElevationData(points);

      // If no elevation data available, return default values
      if (elevationData.isEmpty) {
        return {
          'avgSlope': 0.0,
          'maxSlope': 0.0,
          'totalAscent': 0.0,
          'totalDescent': 0.0,
          'slopeFactor': 0.5 // Default moderate slope factor
        };
      }

      double totalAscent = 0.0;
      double totalDescent = 0.0;
      double maxSlope = 0.0;
      List<double> slopes = [];

      // Process elevation changes along the route
      for (int i = 0; i < elevationData.length - 1; i++) {
        final point1 = elevationData[i];
        final point2 = elevationData[i + 1];

        // Calculate horizontal distance between points (in meters)
        final double lat1 = point1['lat'];
        final double lng1 = point1['lng'];
        final double lat2 = point2['lat'];
        final double lng2 = point2['lng'];

        // Haversine formula for distance (simplified)
        final double R = 6371000; // Earth radius in meters
        final double dLat = (lat2 - lat1) * (math.pi / 180);
        final double dLng = (lng2 - lng1) * (math.pi / 180);
        final double a =
            math.sin(dLat / 2) * math.sin(dLat / 2) +
                math.sin(dLng / 2) * math.sin(dLng / 2) *
                    math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180);
        final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        final double distance = R * c;

        // Calculate elevation change
        final double elev1 = point1['elevation'];
        final double elev2 = point2['elevation'];
        final double elevChange = elev2 - elev1;

        // Track ascents and descents
        if (elevChange > 0) {
          totalAscent += elevChange;
        } else {
          totalDescent += elevChange.abs();
        }

        // Calculate slope (as percentage)
        final double slope = distance > 0 ? (elevChange / distance) * 100 : 0;
        slopes.add(slope);

        // Track maximum slope
        if (slope.abs() > maxSlope) {
          maxSlope = slope.abs();
        }
      }

      // Calculate average slope
      final double avgSlope = slopes.isNotEmpty ?
      slopes.reduce((a, b) => a + b) / slopes.length : 0;

      // Calculate slope factor (0-1 scale, higher means more difficult terrain)
      // This is a weighted combination of average slope, max slope, and total ascent
      // Adjust weights as needed for your specific use case
      final double slopeFactor = (
          0.3 * (avgSlope.abs() / 10) + // Normalize to 0-1 range, assuming 10% as challenging avg slope
              0.3 * (maxSlope / 20) +        // Normalize to 0-1 range, assuming 20% as challenging max slope
              0.4 * (totalAscent / 100)       // Normalize to 0-1 range, assuming 100m as challenging ascent
      ).clamp(0.0, 1.0);  // Ensure result is between 0-1

      return {
        'avgSlope': avgSlope,
        'maxSlope': maxSlope,
        'totalAscent': totalAscent,
        'totalDescent': totalDescent,
        'slopeFactor': slopeFactor
      };
    } catch (e) {
      debugPrint('Error computing route slope: $e');
      return {
        'avgSlope': 0.0,
        'maxSlope': 0.0,
        'totalAscent': 0.0,
        'totalDescent': 0.0,
        'slopeFactor': 0.5 // Default moderate slope factor on error
      };
    }
  }

  // Recursively flattens nested steps in directions response
  static List<dynamic> flattenSteps(List<dynamic> steps) {
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

  // Extract important navigation information from a step
  static Map<String, dynamic> processStep(dynamic step) {
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

    // Extract polyline if available
    String polylinePoints = '';
    if (step.containsKey('polyline') && step['polyline'] is Map && step['polyline'].containsKey('points')) {
      polylinePoints = step['polyline']['points'] as String;
    }

    return {
      'instructions': instructions,
      'distance': distance,
      'duration': duration,
      'start_location': step.containsKey('start_location') ? step['start_location'] : null,
      'end_location': step.containsKey('end_location') ? step['end_location'] : null,
      'maneuver': step.containsKey('maneuver') ? step['maneuver'] : '',
      'polyline': polylinePoints, // Added polyline to the output
    };
  }

  // Get navigation path from origin to destination with language support
  Future<Map<String, dynamic>> getNavigationPath(
      String origin,
      String destination,
      {String languageCode = 'en-US', int alternativeIndex = -1}) async {
    print("Getting the path from $origin to $destination with language: $languageCode");

    // Check network connectivity
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection. Please check your network settings and try again.');
    }

    // If alternativeIndex >= 0, we're requesting a specific alternative route
    // and we already have the routes response cached
    if (alternativeIndex >= 0 && _lastRoutesResponse != null) {
      final routes = _lastRoutesResponse!.containsKey('routes')
          ? List<dynamic>.from(_lastRoutesResponse!['routes'])
          : <dynamic>[];

      if (alternativeIndex < routes.length) {
        // Process the selected alternative route
        return _processSelectedRoute(routes[alternativeIndex], routes, alternativeIndex);
      } else {
        throw Exception("Alternative route index out of range");
      }
    }

    // Otherwise, make a new API request
    const url = "https://maps.googleapis.com/maps/api/directions/json";
    final params = {
      'origin': origin,
      'destination': destination,
      'mode': 'walking',
      'departure_time': 'now',
      'alternatives': 'true',
      'language': languageCode, // Use the provided language code
      'key': apiKey
    };

    try {
      final uri = Uri.parse(url).replace(queryParameters: params);
      final res = await _makeApiRequest(uri, useCache: false); // Don't cache routes

      // Store the response for potential alternative route requests
      _lastRoutesResponse = res;

      if (res['status'] == "OK") {
        // Process the results directly in the main isolate
        return _processRouteResult(res);
      } else if (res['status'] == "ZERO_RESULTS") {
        throw Exception("No walking route found between these locations. Try locations closer together.");
      } else if (res['status'] == "NOT_FOUND") {
        throw Exception("Origin or destination not found. Please check your locations.");
      } else if (res['status'] == "OVER_QUERY_LIMIT") {
        throw Exception("Google Maps API query limit exceeded. Please try again later.");
      } else if (res['status'] == "REQUEST_DENIED") {
        throw Exception("Google Maps API request was denied. The API key may be invalid.");
      } else if (res['status'] == "INVALID_REQUEST") {
        throw Exception("Invalid route request. Please check your origin and destination.");
      } else {
        throw Exception("Directions API error: ${res['status']}");
      }
    } on TimeoutException {
      throw Exception("Connection timed out. Please check your internet and try again.");
    } catch (e) {
      print("Error in getNavigationPath: $e");
      throw Exception("Failed to get navigation path: $e");
    }
  }

  // Get an alternative route
  Future<Map<String, dynamic>> getAlternativeRoute(
      String origin,
      String destination,
      {String languageCode = 'en-US', int currentRouteIndex = 0}) async {

    // Check if we have available alternative routes
    if (_lastRoutesResponse == null) {
      // If no previous response, get a new one
      return await getNavigationPath(origin, destination, languageCode: languageCode);
    }

    final routes = _lastRoutesResponse!.containsKey('routes')
        ? List<dynamic>.from(_lastRoutesResponse!['routes'])
        : <dynamic>[];

    if (routes.length <= 1) {
      // No alternatives available
      throw Exception("No alternative routes available");
    }

    // Find the next route index (circular)
    int nextRouteIndex = (currentRouteIndex + 1) % routes.length;

    // Process the selected alternative route
    return _processSelectedRoute(routes[nextRouteIndex], routes, nextRouteIndex);
  }

  // Process the selected route
  Future<Map<String, dynamic>> _processSelectedRoute(dynamic selectedRoute, List<dynamic> allRoutes, int routeIndex) async {
    try {
      if (!selectedRoute.containsKey('legs') || selectedRoute['legs'].isEmpty) {
        throw Exception("Selected route has no legs");
      }

      final leg = selectedRoute['legs'][0]; // For walking, typically 1 leg
      final steps = leg.containsKey('steps') ? List<dynamic>.from(leg['steps']) : <dynamic>[];

      // Flatten sub-steps to avoid duplicate instructions
      final flattenedSteps = flattenSteps(steps);

      // Process steps into a more usable format
      final processedSteps = <Map<String, dynamic>>[];
      for (int i = 0; i < flattenedSteps.length; i++) {
        processedSteps.add(processStep(flattenedSteps[i]));
      }

      // Get overview polyline for slope analysis
      String overviewPolyline = '';
      if (selectedRoute.containsKey('overview_polyline') &&
          selectedRoute['overview_polyline'] is Map &&
          selectedRoute['overview_polyline'].containsKey('points')) {
        overviewPolyline = selectedRoute['overview_polyline']['points'] as String;
      }

      // Calculate slope metrics for the route
      Map<String, dynamic> slopeMetrics = {'slopeFactor': 0.5};
      if (overviewPolyline.isNotEmpty) {
        slopeMetrics = await computeRouteSlopeMetrics(overviewPolyline);
      }

      // Add slope info to route data
      return {
        'route': selectedRoute,
        'all_routes': allRoutes,
        'route_index': routeIndex,
        'alternative_count': allRoutes.length,
        'steps': processedSteps,
        'total_distance': leg['distance']['text'],
        'total_duration': leg['duration']['text'],
        'start_address': leg['start_address'],
        'end_address': leg['end_address'],
        'slope_metrics': slopeMetrics,
      };
    } catch (e) {
      debugPrint('Error processing selected route: $e');
      rethrow;
    }
  }

  // Process route result and pick the best route
  Future<Map<String, dynamic>> _processRouteResult(Map<String, dynamic> res) async {
    try {
      final routes = res.containsKey('routes')
          ? List<dynamic>.from(res['routes'])
          : <dynamic>[];

      print("Number of routes returned by Directions API: ${routes.length}");

      if (routes.isEmpty) {
        throw Exception("No routes found. Please try different locations.");
      }

      // Analyze all routes for slope factors
      List<Map<String, dynamic>> routeAnalyses = [];
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];

        if (!route.containsKey('legs') || route['legs'].isEmpty) {
          continue; // Skip if no legs
        }

        // Get overview polyline for the route
        String polyline = '';
        if (route.containsKey('overview_polyline') &&
            route['overview_polyline'] is Map &&
            route['overview_polyline'].containsKey('points')) {
          polyline = route['overview_polyline']['points'] as String;
        }

        // Calculate slope metrics
        Map<String, dynamic> slopeMetrics = {'slopeFactor': 0.5}; // Default
        if (polyline.isNotEmpty) {
          slopeMetrics = await computeRouteSlopeMetrics(polyline);
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

        routeAnalyses.add({
          'index': i,
          'travelTime': travelTime,
          'stepCount': stepCount,
          'turnCount': turnCount,
          'slopeMetrics': slopeMetrics,
        });
      }

      // Evaluate and pick best route using all factors
      Map<String, dynamic>? bestRoute;
      double bestScore = double.infinity;
      int bestRouteIndex = 0;

      for (var analysis in routeAnalyses) {
        // Scoring factors
        final int travelTime = analysis['travelTime'];
        final int stepCount = analysis['stepCount'];
        final int turnCount = analysis['turnCount'];
        final double slopeFactor = analysis['slopeMetrics']['slopeFactor'] ?? 0.5;

        // Calculate weighted score - adjust weights based on priorities
        const timeWeight = 1.0;     // Time is important
        const stepWeight = 0.3;     // Fewer steps is somewhat better
        const turnWeight = 0.5;     // Fewer turns is better
        const slopeWeight = 2.0;    // Slope is very important for walking

        final score = (timeWeight * travelTime) +
            (stepWeight * stepCount) +
            (turnWeight * turnCount) +
            (slopeWeight * slopeFactor * 1000); // Scale up slope factor

        debugPrint('Route ${analysis['index']}: Time=$travelTime, Steps=$stepCount, Turns=$turnCount, Slope=$slopeFactor, Score=$score');

        // Update best route if this one is better
        if (score < bestScore) {
          bestScore = score;
          bestRouteIndex = analysis['index'];
          bestRoute = routes[bestRouteIndex];
        }
      }

      if (bestRoute == null) {
        throw Exception("No valid routes found");
      }

      // Process the best route
      return await _processSelectedRoute(bestRoute, routes, bestRouteIndex);
    } catch (e) {
      debugPrint('Error processing route: $e');
      rethrow;
    }
  }

  // Get the number of alternative routes available
  int getAlternativeRouteCount() {
    if (_lastRoutesResponse == null) return 0;

    final routes = _lastRoutesResponse!.containsKey('routes')
        ? List<dynamic>.from(_lastRoutesResponse!['routes'])
        : <dynamic>[];

    return routes.length;
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}