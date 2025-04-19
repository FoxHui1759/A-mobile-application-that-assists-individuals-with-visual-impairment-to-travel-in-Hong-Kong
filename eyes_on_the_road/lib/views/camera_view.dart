import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:eyes_on_the_road/controller/scan_controller.dart';
import 'package:eyes_on_the_road/widgets/mic_popup.dart';

class CameraView extends StatefulWidget {
  final String title;

  CameraView({required this.title});
  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  String nivagationCue = 'go forward';
  String distance = '100m';
  String destination = 'The University of Hong Kong';

  String message = '';

  bool _inputting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor,
          title: Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: GetBuilder<ScanController>(
            init: ScanController(),
            builder: (controller) {
              return controller.isCameraReady.value
                  ? _LongPressDetector(controller)
                  : const Center(
                      child: Text("Loading Preview..."),
                    );
            }),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 0,
          ),
        ));
  }

  Widget _LongPressDetector(controller) {
    return GestureDetector(
        onLongPressStart: (details) {
          _showMicrophone();
        },
        onLongPressEnd: (details) {
          _hideMicrophone();
        },
        child: Stack(children: <Widget>[
          CameraPreview(controller.cameraController),
          if (_inputting)
            MicPopup(), // Show the microphone popup when inputting
        ]));
  }
}
