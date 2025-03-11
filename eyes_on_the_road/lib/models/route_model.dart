// lib/models/route_model.dart
class RouteStep {
  final String instructions;
  final String distance;
  final String duration;
  final Map<String, dynamic>? startLocation;
  final Map<String, dynamic>? endLocation;
  final String maneuver;

  RouteStep({
    required this.instructions,
    required this.distance,
    required this.duration,
    this.startLocation,
    this.endLocation,
    this.maneuver = '',
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instructions: json['instructions'] ?? '',
      distance: json['distance'] ?? '',
      duration: json['duration'] ?? '',
      startLocation: json['start_location'],
      endLocation: json['end_location'],
      maneuver: json['maneuver'] ?? '',
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

  RouteModel({
    required this.totalDistance,
    required this.totalDuration,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.rawRoute,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    List<RouteStep> stepsList = [];
    if (json.containsKey('steps') && json['steps'] is List) {
      for (var stepJson in json['steps']) {
        stepsList.add(RouteStep.fromJson(stepJson));
      }
    }

    return RouteModel(
      totalDistance: json['total_distance'] ?? '',
      totalDuration: json['total_duration'] ?? '',
      startAddress: json['start_address'] ?? '',
      endAddress: json['end_address'] ?? '',
      steps: stepsList,
      rawRoute: json['route'] ?? {},
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