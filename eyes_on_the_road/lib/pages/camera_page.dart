// lib/pages/camera_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../utils/connectivity_checker.dart';
import '../widgets/error_banner.dart';
import '../controller/scanner_controller.dart';
import 'dart:async';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String _destination = '';
  bool _inputting = false;
  bool _showDestinationInput = false;
  String _recognizedSpeech = '';
  bool _speechEnabled = false;

  // Services
  final STTService _sttService = STTService();
  final TtsService _ttsService = TtsService();
  bool _isSpeaking = false;

  String _objectDetectionResult = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Initialize speech recognition
    _initializeSpeechServices();
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_objectDetectionResult.isNotEmpty && !_inputting) {
        _speakNavigationInstructions(_objectDetectionResult);
      }
    });
  }

  Future<void> _initializeSpeechServices() async {
    try {
      await _sttService.initialize();
      setState(() {
        _speechEnabled = _sttService.isInitialized;
      });
    } catch (e) {
      print('Speech recognition initialization error: $e');
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    if (_sttService.isListening) {
      _sttService.stopListening();
    }
    super.dispose();
    _timer?.cancel();
  }

  void _showMicrophone() {
    setState(() {
      _inputting = true;
      _recognizedSpeech = '';
    });

    // Start listening for speech
    if (_sttService.isInitialized) {
      _sttService.startListening((recognizedText) {
        setState(() {
          _recognizedSpeech = recognizedText;

          // If recognition is stable enough, use it
          if (recognizedText.split(' ').length > 2) {
            _destination = recognizedText;

            // If we have something substantial, use it
            if (_destination.length > 10) {
              _hideMicrophone();
              // Automatically start navigation if we got a destination
              if (_destination.isNotEmpty) {
                _startNavigation(context);
              }
            }
          }
        });
      });
    } else {
      // Try to initialize if not already
      _initializeSpeechServices().then((_) {
        if (_sttService.isInitialized) {
          _showMicrophone();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Speech recognition is not available. Please check microphone permissions.'),
              backgroundColor: Colors.red,
            ),
          );
          _hideMicrophone();
        }
      });
    }
  }

  void _hideMicrophone() {
    setState(() {
      _inputting = false;
    });

    // Stop listening for speech
    if (_sttService.isListening) {
      _sttService.stopListening();
    }
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

        // Speak out that navigation has started
        _speakNavigationInstructions("Starting navigation to $_destination");

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

    // Speak out that route is being recalculated
    _speakNavigationInstructions("Recalculating route");
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
      await Provider.of<NavigationService>(context, listen: false)
          .useAlternativeRoute();

      // Speak out that alternative route is being used
      _speakNavigationInstructions("Using alternative route");
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

  // Method to speak out navigation instructions
  Future<void> _speakNavigationInstructions(String instructions) async {
    // Don't interrupt current speech
    if (_inputting) {
      return;
    }

    if (_isSpeaking) {
      await _ttsService.stop();
    }
    _isSpeaking = true;
    await _ttsService.speak(instructions);
    _isSpeaking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NavigationService, LocationService>(
      builder: (context, navigationService, locationService, child) {
        // Enable auto-advance by default for navigation
        if (navigationService.isNavigating && !navigationService.autoAdvance) {
          navigationService.toggleAutoAdvance();
        }

        // Speak out navigation instructions when they change
        if (navigationService.isNavigating && !_isSpeaking) {
          _speakNavigationInstructions(navigationService.currentNavigationCue);
        }

        return GestureDetector(
          onLongPressStart: (details) {
            _showMicrophone();
          },
          onLongPressEnd: (details) {
            _hideMicrophone();
          },
          child: Container(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                // Camera preview as background
                GetBuilder<ScannerController>(
                    init: ScannerController(),
                    builder: (controller) {
                      // get the object detection result every update
                      if (controller.isCameraReady.value) {
                        _objectDetectionResult = controller.message;
                      }
                      return controller.isCameraReady.value
                          ? Center(
                              child: CameraPreview(controller.cameraController))
                          : const Center(
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            );
                    }),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
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
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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
                                      onPressed:
                                          navigationService.endNavigation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[700],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.white),
                                      label: const Text(
                                        'End Navigation',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    // Route switching button (if alternative routes are available)
                                    if (navigationService.hasAlternativeRoutes)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 10.0),
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _useAlternativeRoute(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700],
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                          ),
                                          icon: const Icon(Icons.swap_horiz,
                                              color: Colors.white),
                                          label: const Text(
                                            'Switch Route',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            // Set destination button
                            if (!navigationService.isNavigating &&
                                !_showDestinationInput)
                              Column(
                                children: [
                                  // Current location status
                                  if (locationService.hasLocation)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 10.0, bottom: 5.0),
                                      child: Text(
                                        'Ready to navigate',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (locationService
                                      .errorMessage.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 10.0, bottom: 5.0),
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
                                      padding: const EdgeInsets.only(
                                          top: 10.0, bottom: 5.0),
                                      child: Text(
                                        'Getting your location...',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontStyle: FontStyle.italic,
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
                                            await locationService
                                                .getCurrentPosition();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                        ),
                                        child: const Text(
                                          'Enable Location',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14),
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

                // Microphone overlay - Enhanced for speech recognition
                if (_inputting)
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
                              const Icon(Icons.mic,
                                  size: 100, color: Colors.white),
                              Text('Listening...',
                                  style: Theme.of(context).textTheme.bodyLarge),
                              const SizedBox(height: 20),
                              Text(
                                'Say your destination...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white70,
                                    ),
                              ),
                              // Display recognized text
                              if (_recognizedSpeech.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    'Recognized: $_recognizedSpeech',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                'Release to confirm',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
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
                                  hintStyle:
                                      const TextStyle(color: Colors.white70),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: _toggleDestinationInput,
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey[700],
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
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
                      child: navigationService.error
                                  .toLowerCase()
                                  .contains('api key') ||
                              navigationService.error
                                  .toLowerCase()
                                  .contains('maps.googleapis.com')
                          ? ApiKeyErrorBanner(
                              onRetry: () {
                                if (navigationService.isNavigating) {
                                  _recalculateRoute(context);
                                } else if (_destination.isNotEmpty) {
                                  _startNavigation(context);
                                }
                              },
                            )
                          : navigationService.error
                                      .toLowerCase()
                                      .contains('internet') ||
                                  navigationService.error
                                      .toLowerCase()
                                      .contains('network') ||
                                  navigationService.error
                                      .toLowerCase()
                                      .contains('connection')
                              ? NetworkErrorBanner(
                                  onRetry: () async {
                                    final connectivityChecker =
                                        ConnectivityChecker();
                                    final isConnected =
                                        await connectivityChecker.isConnected();

                                    if (!isConnected && context.mounted) {
                                      await connectivityChecker
                                          .showNoInternetDialog(context);
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
                if (navigationService.isNavigating &&
                    navigationService.hasAlternativeRoutes)
                  Positioned(
                    top: 65,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Route ${navigationService.currentRouteIndex + 1}/${navigationService.alternativeRouteCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),

                // Speaking indicator (when TTS is active)
                if (_isSpeaking)
                  Positioned(
                    bottom: 150,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Speaking',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
