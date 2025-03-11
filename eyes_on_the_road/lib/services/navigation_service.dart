// lib/services/navigation_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'google_maps_service.dart';

class NavigationService extends ChangeNotifier {
  final GoogleMapsService _mapsService;

  RouteModel? _currentRoute;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  String _destination = '';
  String _error = '';
  bool _isLoading = false;

  NavigationService(this._mapsService);

  // Getters
  RouteModel? get currentRoute => _currentRoute;
  int get currentStepIndex => _currentStepIndex;
  bool get isNavigating => _isNavigating;
  String get destination => _destination;
  String get error => _error;
  bool get isLoading => _isLoading;

  // Current navigation information
  String get currentNavigationCue {
    if (_currentRoute == null || !_isNavigating) {
      return 'Set destination';
    }

    if (_currentStepIndex < _currentRoute!.steps.length) {
      return _currentRoute!.getCurrentStepInstructions(_currentStepIndex);
    }

    return 'You have arrived';
  }

  String get currentDistance {
    if (_currentRoute == null || !_isNavigating) {
      return '';
    }

    if (_currentStepIndex < _currentRoute!.steps.length) {
      return _currentRoute!.getCurrentStepDistance(_currentStepIndex);
    }

    return '';
  }

  // Start navigation to a destination
  Future<void> startNavigation(String destination) async {
    _isLoading = true;
    _error = '';
    _destination = destination;
    notifyListeners();

    try {
      // Hardcoded starting point - typically this would come from GPS
      String startLocation = "22.2835513,114.1345991"; // HKU coordinates

      // Process locations
      final processedStart = await _mapsService.preprocessCoordinates(startLocation);
      final processedDestination = await _mapsService.preprocessCoordinates(destination);

      // Get navigation path
      final routeData = await _mapsService.getNavigationPath(
          processedStart,
          processedDestination
      );

      // Create route model
      _currentRoute = RouteModel.fromJson(routeData);
      _currentStepIndex = 0;
      _isNavigating = true;

    } catch (e) {
      _error = e.toString();
      _isNavigating = false;
      _currentRoute = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Move to next step in navigation
  void nextStep() {
    if (_currentRoute != null && _currentStepIndex < _currentRoute!.steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    }
  }

  // Move to previous step in navigation
  void previousStep() {
    if (_currentRoute != null && _currentStepIndex > 0) {
      _currentStepIndex--;
      notifyListeners();
    }
  }

  // End current navigation
  void endNavigation() {
    _isNavigating = false;
    _currentRoute = null;
    _currentStepIndex = 0;
    _destination = '';
    notifyListeners();
  }
}