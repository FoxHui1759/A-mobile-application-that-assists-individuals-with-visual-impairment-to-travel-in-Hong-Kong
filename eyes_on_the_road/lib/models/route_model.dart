// lib/models/route_model.dart
class RouteStep {
  final String instructions;
  final String distance;
  final String duration;
  final Map<String, dynamic>? startLocation;
  final Map<String, dynamic>? endLocation;
  final String maneuver;
  final String polyline; // Added polyline field

  RouteStep({
    required this.instructions,
    required this.distance,
    required this.duration,
    this.startLocation,
    this.endLocation,
    this.maneuver = '',
    this.polyline = '', // Default to empty string
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    // Extract polyline if available
    String polylineStr = '';
    if (json.containsKey('polyline') && json['polyline'] is Map && json['polyline'].containsKey('points')) {
      polylineStr = json['polyline']['points'] as String;
    }

    return RouteStep(
      instructions: json['instructions'] ?? '',
      distance: json['distance'] ?? '',
      duration: json['duration'] ?? '',
      startLocation: json['start_location'],
      endLocation: json['end_location'],
      maneuver: json['maneuver'] ?? '',
      polyline: polylineStr,
    );
  }
}

class RouteModel {
  final String totalDistance;
  final String totalDuration;
  final String startAddress;
  final String endAddress;
  final List<RouteStep> steps;
  final Map<String, dynamic> rawRoute;
  final String overviewPolyline; // Added overview polyline field

  RouteModel({
    required this.totalDistance,
    required this.totalDuration,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.rawRoute,
    this.overviewPolyline = '', // Default to empty string
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

    return RouteModel(
      totalDistance: json['total_distance'] ?? '',
      totalDuration: json['total_duration'] ?? '',
      startAddress: json['start_address'] ?? '',
      endAddress: json['end_address'] ?? '',
      steps: stepsList,
      rawRoute: json['route'] ?? {},
      overviewPolyline: overviewLine,
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
}