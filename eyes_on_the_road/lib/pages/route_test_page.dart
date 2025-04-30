// lib/pages/route_test_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/google_maps_service.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import '../models/route_model.dart';

class RouteTestPage extends StatefulWidget {
  // Add GoogleMapsService as a required parameter
  final GoogleMapsService googleMapsService;

  const RouteTestPage({
    super.key,
    required this.googleMapsService
  });

  @override
  _RouteTestPageState createState() => _RouteTestPageState();
}

class _RouteTestPageState extends State<RouteTestPage> {
  final TextEditingController _destinationController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  RouteModel? _routeResult;
  Map<String, dynamic> _rawRouteData = {};
  final List<String> _predefinedDestinations = [
    "Centennial Campus, The University of Hong Kong",
    "Chong Yuet Ming Physics Building, The University of Hong Kong",
    "Graduate House, The University of Hong Kong",
    "Main Building, The University of Hong Kong",
    "Exit A2, HKU Station",
    "Exit C, HKU Station"
  ];
  bool _useCurrentLocation = true;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _testRoute(String destination) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _routeResult = null;
      _rawRouteData = {};
    });

    try {
      // Use widget.googleMapsService instead of Provider.of
      final googleMapsService = widget.googleMapsService;
      final locationService = Provider.of<LocationService>(context, listen: false);

      // Determine starting point
      String startLocation;

      if (_useCurrentLocation && locationService.hasLocation) {
        // Use actual user location
        startLocation = locationService.currentLocationString;
      } else {
        // Fallback to default location
        startLocation = "22.2835513,114.1345991"; // HKU coordinates
      }

      // Process locations
      final processedStart = await googleMapsService.preprocessCoordinates(startLocation);
      final processedDestination = await googleMapsService.preprocessCoordinates(destination);

      // Get navigation path
      final routeData = await googleMapsService.getNavigationPath(
          processedStart,
          processedDestination
      );

      // Create route model and store raw data
      setState(() {
        _routeResult = RouteModel.fromJson(routeData);
        _rawRouteData = routeData;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startNavigation() {
    if (_routeResult != null) {
      Provider.of<NavigationService>(context, listen: false)
          .startNavigation(_destinationController.text);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation started! Go to Camera page to view.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Test', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Route Recommendations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current location card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _useCurrentLocation,
                          onChanged: (value) {
                            setState(() {
                              _useCurrentLocation = value;
                            });

                            // If switching to use current location but we don't have it yet
                            if (_useCurrentLocation && !locationService.hasLocation) {
                              locationService.getCurrentPosition();
                            }
                          },
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),

                    // Location status and info
                    Row(
                      children: [
                        Icon(
                          locationService.hasLocation
                              ? Icons.location_on
                              : Icons.location_off,
                          color: locationService.hasLocation
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationService.hasLocation
                                ? 'Using your current location: ${locationService.currentPosition!.latitude.toStringAsFixed(6)}, '
                                '${locationService.currentPosition!.longitude.toStringAsFixed(6)}'
                                : _useCurrentLocation
                                ? 'Location not available. Using default HKU coordinates.'
                                : 'Using default HKU coordinates.',
                            style: TextStyle(
                              color: locationService.hasLocation || !_useCurrentLocation
                                  ? Colors.black87
                                  : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Get location button
                    if (_useCurrentLocation && !locationService.hasLocation)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () => locationService.getCurrentPosition(),
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                          label: const Text('Get my location', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Destination input
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                hintText: 'Enter a location in Hong Kong',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_destinationController.text.isNotEmpty) {
                      _testRoute(_destinationController.text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Predefined destinations
            const Text(
              'Predefined Destinations:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedDestinations.map((dest) =>
                  ElevatedButton(
                    onPressed: () {
                      _destinationController.text = dest;
                      _testRoute(dest);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: Text(dest, style: const TextStyle(color: Colors.white)),
                  )
              ).toList(),
            ),
            const SizedBox(height: 24),

            // Loading indicator
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            // Error message
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red[100],
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red[900]),
                ),
              ),

            // Route result
            if (_routeResult != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Route Found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: const Text('Start Navigation', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                    onPressed: _startNavigation,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Route summary
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Route Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      _buildInfoRow('From', _routeResult!.startAddress),
                      _buildInfoRow('To', _routeResult!.endAddress),
                      _buildInfoRow('Distance', _routeResult!.totalDistance),
                      _buildInfoRow('Duration', _routeResult!.totalDuration),
                      _buildInfoRow('Steps', '${_routeResult!.steps.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Step-by-step instructions
              const Text(
                'Navigation Steps:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _routeResult!.steps.length,
                itemBuilder: (context, index) {
                  final step = _routeResult!.steps[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(step.instructions),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${step.distance} • ${step.duration}'),
                          if (step.maneuver.isNotEmpty)
                            Text(
                              'Maneuver: ${step.maneuver}',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue[700]),
                            ),
                          if (locationService.hasLocation && step.endLocation != null)
                            Text(
                              'Distance from you: ${_getDistanceFromUser(locationService, step.endLocation!).round()} meters',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),

              // Technical details (expandable)
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Technical Details', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Raw Route Data (first 500 chars):'),
                        const SizedBox(height: 8),
                        Text('${_rawRouteData.toString().substring(0,
                            _rawRouteData.toString().length > 500 ? 500 : _rawRouteData.toString().length)}...'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // Helper method to calculate distance from user to a waypoint
  double _getDistanceFromUser(LocationService locationService, Map<String, dynamic> waypoint) {
    if (!locationService.hasLocation) return 0.0;

    final waypointLat = waypoint['lat'] as double;
    final waypointLng = waypoint['lng'] as double;

    return locationService.getDistanceBetween(
        locationService.currentPosition!.latitude,
        locationService.currentPosition!.longitude,
        waypointLat,
        waypointLng
    );
  }
}