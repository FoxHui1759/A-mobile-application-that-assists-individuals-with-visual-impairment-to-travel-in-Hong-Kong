// lib/services/google_maps_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class GoogleMapsService {
  final String apiKey;

  // Add a cache to reduce repeated API calls
  final Map<String, dynamic> _responseCache = {};

  GoogleMapsService({required this.apiKey});

  // Check network connectivity before making API requests
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Helper to handle network errors consistently with additional caching
  Future<Map<String, dynamic>> _makeApiRequest(Uri uri, {bool useCache = true}) async {
    // Check the cache first if enabled
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
      // Check if we have internet connectivity
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

        // Check if we have internet connectivity
        if (!await _checkConnectivity()) {
          // If no connectivity, just return the coordinates formatted nicely
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

      // If there's an error, check if it's a coordinate and return a formatted version
      if (isCoordinates(location)) {
        final coords = extractCoordinates(location)!;
        return "Location (${coords['lat']!.toStringAsFixed(6)}, ${coords['lng']!.toStringAsFixed(6)})";
      }

      // Otherwise, just return the original location string
      return location;
    }
  }

  // Decode a polyline - safe for compute
  Future<List<Map<String, double>>> decodePolylineAsync(String polyline) async {
    return compute(_decodePolyline, polyline);
  }

  // Static method to decode polyline (for compute)
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

  // Compute approximate slope factor for a route
  Future<double> computeRouteSlope(String routePolyline) async {
    // Simplified version that doesn't use compute, as it's not critical
    try {
      final points = _decodePolyline(routePolyline);

      if (points.length < 2) {
        return 0.0; // No slope if there's only one or no point
      }

      // Simplified slope calculation
      return 0.5; // Simulate a moderate slope
    } catch (e) {
      debugPrint('Error computing route slope: $e');
      return 0.0;
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
      {String languageCode = 'en-US'}) async {
    print("Getting the path from $origin to $destination with language: $languageCode");

    // Check network connectivity
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection. Please check your network settings and try again.');
    }

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

  // Process route result and pick the best route
  Map<String, dynamic> _processRouteResult(Map<String, dynamic> res) {
    try {
      final routes = res.containsKey('routes')
          ? List<dynamic>.from(res['routes'])
          : <dynamic>[];

      print("Number of routes returned by Directions API: ${routes.length}");

      if (routes.isEmpty) {
        throw Exception("No routes found. Please try different locations.");
      }

      // Evaluate and pick best route
      Map<String, dynamic>? bestRoute;
      double bestScore = double.infinity;

      for (int idx = 0; idx < routes.length; idx++) {
        final route = routes[idx];

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

        // Use a simplified slope calculation
        double slopeFactor = 0.0;

        // Simplified scoring without slope API calls
        const timeWeight = 1.0;
        const stepWeight = 0.5;
        const turnWeight = 0.75;

        final score = (timeWeight * travelTime) +
            (stepWeight * stepCount) +
            (turnWeight * turnCount);

        // Update best route if this one is better
        if (score < bestScore) {
          bestScore = score;
          bestRoute = route;
        }
      }

      if (bestRoute == null) {
        throw Exception("No valid routes found");
      }

      // Find chosen route index
      int chosenIndex = -1;
      for (int i = 0; i < routes.length; i++) {
        if (routes[i] == bestRoute) {
          chosenIndex = i;
          break;
        }
      }

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
    } catch (e) {
      debugPrint('Error processing route: $e');
      rethrow;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}