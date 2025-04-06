// lib/pages/camera_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import '../utils/connectivity_checker.dart';
import '../widgets/error_banner.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String _destination = '';
  bool _inputting = false;
  bool _showDestinationInput = false;

  void _showMicrophone() {
    setState(() {
      _inputting = true;
    });
  }

  void _hideMicrophone() {
    setState(() {
      _inputting = false;
    });
  }

  void _toggleDestinationInput() {
    setState(() {
      _showDestinationInput = !_showDestinationInput;
    });
  }

  void _startNavigation(BuildContext context) async {
    if (_destination.isNotEmpty) {
      // Check connectivity first
      final connectivityChecker = ConnectivityChecker();
      final isConnected = await connectivityChecker.isConnected();

      if (!isConnected) {
        if (context.mounted) {
          await connectivityChecker.showNoInternetDialog(context);
        }
        return;
      }

      try {
        Provider.of<NavigationService>(context, listen: false)
            .startNavigation(_destination);

        setState(() {
          _showDestinationInput = false;
          _destination = '';
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting navigation: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _recalculateRoute(BuildContext context) async {
    // Check connectivity first
    final connectivityChecker = ConnectivityChecker();
    final isConnected = await connectivityChecker.isConnected();

    if (!isConnected) {
      if (context.mounted) {
        await connectivityChecker.showNoInternetDialog(context);
      }
      return;
    }

    Provider.of<NavigationService>(context, listen: false).recalculateRoute();
  }

  void _useAlternativeRoute(BuildContext context) async {
    // Check connectivity first
    final connectivityChecker = ConnectivityChecker();
    final isConnected = await connectivityChecker.isConnected();

    if (!isConnected) {
      if (context.mounted) {
        await connectivityChecker.showNoInternetDialog(context);
      }
      return;
    }

    try {
      await Provider.of<NavigationService>(context, listen: false).useAlternativeRoute();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching routes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NavigationService, LocationService>(
      builder: (context, navigationService, locationService, child) {
        // Enable auto-advance by default for navigation
        if (navigationService.isNavigating && !navigationService.autoAdvance) {
          navigationService.toggleAutoAdvance();
        }

        return GestureDetector(
          onLongPressStart: (details) {
            _showMicrophone();
          },
          onLongPressEnd: (details) {
            _hideMicrophone();
          },
          child: Stack(
            children: <Widget>[
              // Background image, replace with black background
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.black,
              ),
              // Image(
              //     fit: BoxFit.cover,
              //     width: View.of(context).physicalSize.width,
              //     height: View.of(context).physicalSize.height,
              //     image: const AssetImage('assets/images/street.jpg')
              // ),

              // Navigation info
              Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Destination and Navigation cue (top)
                    Container(
                      margin: const EdgeInsets.only(top: 10.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: navigationService.isOffRoute
                            ? Colors.red[800]
                            : Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Destination display
                          if (navigationService.isNavigating)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'To: ${navigationService.destination}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                                ),
                              ),
                            ),

                          // Current navigation instruction
                          Text(
                            navigationService.currentNavigationCue,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                    // // Current position (only shown when navigating)
                    // if (navigationService.isNavigating && locationService.hasLocation)
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    //     child: Container(
                    //       padding: const EdgeInsets.all(10.0),
                    //       decoration: BoxDecoration(
                    //         color: Theme.of(context).primaryColor.withOpacity(0.8),
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //       child: Text(
                    //         'Your position: ${locationService.currentPosition!.latitude.toStringAsFixed(5)}, '
                    //             '${locationService.currentPosition!.longitude.toStringAsFixed(5)}',
                    //         style: const TextStyle(color: Colors.white, fontSize: 12),
                    //         textAlign: TextAlign.center,
                    //       ),
                    //     ),
                    //   ),

                    // Distance and minimal controls (bottom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      width: double.infinity,
                      child: Column(
                        children: [
                          // Distance display
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                borderRadius: BorderRadius.circular(20)),
                            child: Center(
                              child: Text(
                                navigationService.currentDistance,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),

                          // Minimal navigation controls
                          if (navigationService.isNavigating)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // End navigation
                                  ElevatedButton.icon(
                                    onPressed: navigationService.endNavigation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.cancel, color: Colors.white),
                                    label: const Text(
                                      'End Navigation',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Set destination button
                          if (!navigationService.isNavigating && !_showDestinationInput)
                            Column(
                              children: [
                                // Current location status
                                if (locationService.hasLocation)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
                                    child: Text(
                                      'Ready to navigate',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (locationService.errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
                                    child: Text(
                                      'Location error: ${locationService.errorMessage}',
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
                                    child: Text(
                                      'Getting your location...',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),

                                // Set destination button
                                Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: ElevatedButton(
                                    onPressed: _toggleDestinationInput,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    ),
                                    child: const Text(
                                      'Set Destination',
                                      style: TextStyle(color: Colors.white, fontSize: 18),
                                    ),
                                  ),
                                ),

                                // Initialize location button (if not initialized)
                                if (!locationService.isInitialized)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await locationService.initialize();
                                        if (locationService.isInitialized) {
                                          await locationService.getCurrentPosition();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      child: const Text(
                                        'Enable Location',
                                        style: TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Microphone overlay
              if (_inputting)
                Container(
                  alignment: Alignment.center,
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.mic, size: 100, color: Colors.white),
                            Text('Listening...',
                                style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Destination input overlay
              if (_showDestinationInput)
                Container(
                  alignment: Alignment.center,
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 300,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Enter Destination',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'e.g., The University of Hong Kong',
                                hintStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.indigo[700],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _destination = value;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: _toggleDestinationInput,
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _startNavigation(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Start',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (navigationService.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),

              // Error message
              if (navigationService.error.isNotEmpty)
                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: navigationService.error.toLowerCase().contains('api key') ||
                        navigationService.error.toLowerCase().contains('maps.googleapis.com')
                        ? ApiKeyErrorBanner(
                      onRetry: () {
                        if (navigationService.isNavigating) {
                          _recalculateRoute(context);
                        } else if (_destination.isNotEmpty) {
                          _startNavigation(context);
                        }
                      },
                    )
                        : navigationService.error.toLowerCase().contains('internet') ||
                        navigationService.error.toLowerCase().contains('network') ||
                        navigationService.error.toLowerCase().contains('connection')
                        ? NetworkErrorBanner(
                      onRetry: () async {
                        final connectivityChecker = ConnectivityChecker();
                        final isConnected = await connectivityChecker.isConnected();

                        if (!isConnected && context.mounted) {
                          await connectivityChecker.showNoInternetDialog(context);
                        } else if (navigationService.isNavigating) {
                          _recalculateRoute(context);
                        } else if (_destination.isNotEmpty) {
                          _startNavigation(context);
                        }
                      },
                    )
                        : ErrorBanner(
                      errorMessage: navigationService.error,
                      onRetry: navigationService.isNavigating
                          ? () => _recalculateRoute(context)
                          : null,
                    ),
                  ),
                ),

              // Route information indicator
              if (navigationService.isNavigating && navigationService.hasAlternativeRoutes)
                Positioned(
                  top: 65,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Route ${navigationService.currentRouteIndex + 1}/${navigationService.alternativeRouteCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}