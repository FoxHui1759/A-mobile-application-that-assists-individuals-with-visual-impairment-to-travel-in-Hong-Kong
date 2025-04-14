class RouteModel {
  final String totalDistance;
  final String totalDuration;
  final String startAddress;
  final String endAddress;
  final List<RouteStep> steps;
  final Map<String, dynamic> rawRoute;
  final String overviewPolyline; // Added overview polyline field
  final Map<String, dynamic> slopeMetrics; // Added slope metrics

  RouteModel({
    required this.totalDistance,
    required this.totalDuration,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.rawRoute,
    this.overviewPolyline = '', // Default to empty string
    this.slopeMetrics = const {}, // Default to empty map
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    List<RouteStep> stepsList = [];
    if (json.containsKey('steps') && json['steps'] is List) {
      for (var stepJson in json['steps']) {
        stepsList.add(RouteStep.fromJson(stepJson));
      }
    }

    // Extract overview polyline from route
    String overviewLine = '';
    if (json.containsKey('route') &&
        json['route'] is Map &&
        json['route'].containsKey('overview_polyline') &&
        json['route']['overview_polyline'] is Map &&
        json['route']['overview_polyline'].containsKey('points')) {
      overviewLine = json['route']['overview_polyline']['points'] as String;
    }

    // Extract slope metrics if available
    Map<String, dynamic> slopeData = {};
    if (json.containsKey('slope_metrics') && json['slope_metrics'] is Map) {
      slopeData = json['slope_metrics'];
    }

    return RouteModel(
      totalDistance: json['total_distance'] ?? '',
      totalDuration: json['total_duration'] ?? '',
      startAddress: json['start_address'] ?? '',
      endAddress: json['end_address'] ?? '',
      steps: stepsList,
      rawRoute: json['route'] ?? {},
      overviewPolyline: overviewLine,
      slopeMetrics: slopeData,
    );
  }

  String getCurrentStepInstructions(int index) {
    if (index >= 0 && index < steps.length) {
      return steps[index].instructions;
    }
    return '';
  }

  String getCurrentStepDistance(int index) {
    if (index >= 0 && index < steps.length) {
      return steps[index].distance;
    }
    return '';
  }

  String getNextManeuver(int currentIndex) {
    if (currentIndex >= 0 && currentIndex < steps.length - 1) {
      return steps[currentIndex + 1].maneuver;
    }
    return 'destination';
  }

  // Get total ascent (uphill) in meters
  double get totalAscent {
    return slopeMetrics['totalAscent'] ?? 0.0;
  }

  // Get total descent (downhill) in meters
  double get totalDescent {
    return slopeMetrics['totalDescent'] ?? 0.0;
  }

  // Get average slope percentage
  double get averageSlope {
    return slopeMetrics['avgSlope'] ?? 0.0;
  }

  // Get maximum slope percentage
  double get maxSlope {
    return slopeMetrics['maxSlope'] ?? 0.0;
  }

  // Get route difficulty based on slope (0.0-1.0)
  double get slopeDifficulty {
    return slopeMetrics['slopeFactor'] ?? 0.0;
  }

  // Get human-readable slope difficulty description
  String get slopeDifficultyDescription {
    final difficulty = slopeDifficulty;

    if (difficulty < 0.2) return 'Very flat terrain';
    if (difficulty < 0.4) return 'Mostly flat with gentle slopes';
    if (difficulty < 0.6) return 'Moderate slopes';
    if (difficulty < 0.8) return 'Steep in some sections';
    return 'Very steep terrain';
  }
}

class RouteStep {
  final String instructions;
  final String distance;
  final String duration;
  final Map<String, dynamic>? startLocation;
  final Map<String, dynamic>? endLocation;
  final String maneuver;
  final String polyline; // Encoded polyline for this step

  RouteStep({
    required this.instructions,
    required this.distance,
    required this.duration,
    this.startLocation,
    this.endLocation,
    this.maneuver = '',
    this.polyline = '',
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    // Extract polyline if available
    String polylineStr = '';
    if (json.containsKey('polyline') && json['polyline'] is Map && json['polyline'].containsKey('points')) {
      polylineStr = json['polyline']['points'] as String;
    } else if (json.containsKey('polyline') && json['polyline'] is String) {
      polylineStr = json['polyline'] as String;
    }

    // Clean HTML from instructions if present
    String cleanInstructions = json['instructions'] ?? '';
    cleanInstructions = cleanInstructions
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' '); // Replace HTML space

    return RouteStep(
      instructions: cleanInstructions,
      distance: json['distance'] ?? '',
      duration: json['duration'] ?? '',
      startLocation: json['start_location'],
      endLocation: json['end_location'],
      maneuver: json['maneuver'] ?? '',
      polyline: polylineStr,
    );
  }

  // Helper to convert raw coordinates to more usable format
  Map<String, double>? get startCoordinates {
    if (startLocation == null) return null;

    return {
      'lat': startLocation!['lat'] as double,
      'lng': startLocation!['lng'] as double,
    };
  }

  Map<String, double>? get endCoordinates {
    if (endLocation == null) return null;

    return {
      'lat': endLocation!['lat'] as double,
      'lng': endLocation!['lng'] as double,
    };
  }

  // Helper to extract meters from distance text
  double get distanceInMeters {
    if (distance.isEmpty) return 0.0;

    try {
      if (distance.contains('km')) {
        // Extract kilometers
        final kmStr = distance.replaceAll('km', '').trim();
        return double.parse(kmStr) * 1000; // Convert km to meters
      } else if (distance.contains('m')) {
        // Extract meters
        final mStr = distance.replaceAll('m', '').trim();
        return double.parse(mStr);
      }
    } catch (e) {
      // If parsing fails, return 0
      print('Error parsing distance: $e');
    }

    return 0.0;
  }

  // Helper to extract seconds from duration text
  int get durationInSeconds {
    if (duration.isEmpty) return 0;

    try {
      if (duration.contains('hour') || duration.contains('min')) {
        int totalSeconds = 0;

        // Extract hours if present
        if (duration.contains('hour')) {
          final hourParts = duration.split('hour');
          final hours = int.parse(hourParts[0].trim());
          totalSeconds += hours * 3600;

          // Look for minutes after hours
          if (hourParts.length > 1 && hourParts[1].contains('min')) {
            final minutesStr = hourParts[1].replaceAll('mins', '').replaceAll('min', '').trim();
            final minutes = int.parse(minutesStr);
            totalSeconds += minutes * 60;
          }
        } else if (duration.contains('min')) {
          // Only minutes
          final minutesStr = duration.replaceAll('mins', '').replaceAll('min', '').trim();
          final minutes = int.parse(minutesStr);
          totalSeconds += minutes * 60;
        }

        return totalSeconds;
      } else if (duration.contains('sec')) {
        // Only seconds
        final secondsStr = duration.replaceAll('secs', '').replaceAll('sec', '').trim();
        return int.parse(secondsStr);
      }
    } catch (e) {
      // If parsing fails, return 0
      print('Error parsing duration: $e');
    }

    return 0;
  }

  // Categorize the maneuver type
  String get maneuverType {
    if (maneuver.isEmpty) return 'straight';

    if (maneuver.contains('right')) return 'right';
    if (maneuver.contains('left')) return 'left';
    if (maneuver.contains('straight')) return 'straight';
    if (maneuver.contains('uturn')) return 'uturn';
    if (maneuver.contains('merge')) return 'merge';
    if (maneuver.contains('fork')) return 'fork';
    if (maneuver.contains('roundabout')) return 'roundabout';

    return maneuver; // Return original if no match
  }

  @override
  String toString() {
    return 'RouteStep(instructions: $instructions, distance: $distance, maneuver: $maneuver)';
  }
}