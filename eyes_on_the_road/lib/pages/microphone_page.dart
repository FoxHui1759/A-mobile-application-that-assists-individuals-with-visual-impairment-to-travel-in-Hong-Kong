// microphone_page.dart
import 'package:flutter/material.dart';

class MicrophonePage extends StatefulWidget {
  const MicrophonePage({super.key});

  @override
  _MicrophonePageState createState() => _MicrophonePageState();
}

class _MicrophonePageState extends State<MicrophonePage> {
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mic,
          size: 300,
          color: Colors.white,
        ),
        Text(
          'Listening...',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ],
    ));
  }
}
