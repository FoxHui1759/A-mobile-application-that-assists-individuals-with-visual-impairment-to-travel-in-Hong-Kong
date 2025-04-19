import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:eyes_on_the_road/controller/scanner_controller.dart';
import 'package:eyes_on_the_road/widgets/mic_popup.dart';
import 'package:eyes_on_the_road/widgets/message_box.dart';

class ScannerView extends StatefulWidget {
  final String title;

  ScannerView({required this.title});
  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<ScannerView> {
  String navigationCue = 'go forward';
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
        body: GetBuilder<ScannerController>(
            init: ScannerController(),
            builder: (controller) {
              return controller.isCameraReady.value
                  ? _longPressDetector(context, controller)
                  : const Center(
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    );
            }),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 0,
          ),
        ));
  }

  Widget _longPressDetector(context, controller) {
    return GestureDetector(
        onLongPressStart: (details) {
          _showMicrophone();
        },
        onLongPressEnd: (details) {
          _hideMicrophone();
        },
        child: _scannerPreview(context, controller));
  }

  Widget _scannerPreview(context, controller) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Stack(
        children: <Widget>[
          Center(
            child: CameraPreview(controller.cameraController),
          ),
          Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                MessageBox(
                  message: navigationCue,
                ),
                MessageBox(message: distance),
              ],
            ),
          ),
          if (_inputting) MicPopup(),
        ],
      ),
    );
  }
}
