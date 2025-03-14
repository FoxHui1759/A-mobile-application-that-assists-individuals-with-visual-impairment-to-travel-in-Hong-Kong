import 'package:flutter/material.dart';
import '../services/sst_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final SpeechService _speechService = SpeechService();
  String navigationCue = 'go forward';
  String distance = '100m';
  String destination = 'The University of Hong Kong';
  bool _inputting = false;

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
  }

  void _showMicrophone() {
    setState(() {
      _inputting = true;
      _speechService.startListening();
    });
  }

  void _hideMicrophone() {
    setState(() {
      _inputting = false;
      _speechService.stopListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _showMicrophone();
      },
      onLongPressEnd: (details) {
        _hideMicrophone();
      },
      child: Stack(
        children: <Widget>[
          Image(
              fit: BoxFit.cover,
              width: View.of(context).physicalSize.width,
              height: View.of(context).physicalSize.height,
              image: AssetImage('assets/images/street.jpg')),
          Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  margin: EdgeInsets.only(top: 10.0),
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(navigationCue,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(bottom: 10.0),
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(20)),
                  child: Center(
                    child: Text(distance,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
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
                        Icon(Icons.mic, size: 100, color: Colors.white),
                        Text('Listening...',
                            style: Theme.of(context).textTheme.bodyLarge),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
