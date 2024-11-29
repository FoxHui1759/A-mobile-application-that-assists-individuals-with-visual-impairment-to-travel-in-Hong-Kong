import 'package:flutter/material.dart';
import 'dart:ui';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image(
          fit: BoxFit.cover,
          width: View.of(context).physicalSize.width,
          height: View.of(context).physicalSize.height,
          image: AssetImage('assets/images/street.jpg')),
    );
  }
}
