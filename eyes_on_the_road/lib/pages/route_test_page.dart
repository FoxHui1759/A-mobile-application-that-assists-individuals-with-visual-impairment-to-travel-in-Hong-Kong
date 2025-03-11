// lib/pages/route_test_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/google_maps_service.dart';
import '../services/navigation_service.dart';
import '../models/route_model.dart';

class RouteTestPage extends StatefulWidget {
  const RouteTestPage({Key? key}) : super(key: key);

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
      // Get Google Maps Service
      final googleMapsService = Provider.of<GoogleMapsService>(context, listen: false);

      // Hardcoded starting point - typically this would come from GPS
      String startLocation = "22.2835513,114.1345991"; // HKU coordinates

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
          SnackBar(content: Text('Navigation started! Go to Camera page to view.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route Test', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Route Recommendations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Destination input
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                hintText: 'Enter a location in Hong Kong',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    if (_destinationController.text.isNotEmpty) {
                      _testRoute(_destinationController.text);
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 16),

            // Predefined destinations
            Text(
              'Predefined Destinations:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
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
                    child: Text(dest, style: TextStyle(color: Colors.white)),
                  )
              ).toList(),
            ),
            SizedBox(height: 24),

            // Loading indicator
            if (_isLoading)
              Center(child: CircularProgressIndicator()),

            // Error message
            if (_error.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
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
                    icon: Icon(Icons.navigation, color: Colors.white),
                    label: Text('Start Navigation', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                    onPressed: _startNavigation,
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Route summary
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Divider(),
                      _buildInfoRow('From', _routeResult!.startAddress),
                      _buildInfoRow('To', _routeResult!.endAddress),
                      _buildInfoRow('Distance', _routeResult!.totalDistance),
                      _buildInfoRow('Duration', _routeResult!.totalDuration),
                      _buildInfoRow('Steps', '${_routeResult!.steps.length}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Step-by-step instructions
              Text(
                'Navigation Steps:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _routeResult!.steps.length,
                itemBuilder: (context, index) {
                  final step = _routeResult!.steps[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text('${index + 1}', style: TextStyle(color: Colors.white)),
                      ),
                      title: Text(step.instructions),
                      subtitle: Text('${step.distance} • ${step.duration}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),

              // Technical details (expandable)
              SizedBox(height: 24),
              ExpansionTile(
                title: Text('Technical Details', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Raw Route Data (first 500 chars):'),
                        SizedBox(height: 8),
                        Text(_rawRouteData.toString().substring(0,
                            _rawRouteData.toString().length > 500 ? 500 : _rawRouteData.toString().length) + '...'),
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
              label + ':',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}