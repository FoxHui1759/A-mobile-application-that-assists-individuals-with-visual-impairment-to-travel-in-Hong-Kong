import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image/image.dart' as imglib;

class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.camera, required this.socket});

  final CameraDescription camera;
  final IO.Socket socket;
  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  String nivagationCue = 'go forward';
  String distance = '100m';
  String destination = 'The University of Hong Kong';

  String message = '';

  bool _inputting = false;

  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    //initialize the camera controller
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) async {
      if (!mounted) {
        return;
      }

      setState(() {
        message = 'start streaming';
      });
      widget.socket.emit("message", message);
      await _controller.startImageStream((CameraImage cameraImage) {
        //send the image to the server");
        if (widget.socket.connected) {
          imglib.Image image = convertYUV420ToImage(cameraImage);
          String base64Image = base64Encode(imglib.encodeJpg(image));

          widget.socket.emit("image", base64Image);
        }
      });
    });
  }

  imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    // Create the image with swapped width and height to account for rotation
    final image = imglib.Image(width: imageHeight, height: imageWidth);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        final int y = yBuffer[yIndex];

        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        // Set the pixel with rotated coordinates
        image.setPixelRgb(imageHeight - h - 1, w, r, g, b);
      }
    }

    return image;
  }

  @override
  void dispose() {
    _controller.dispose();
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
    return GestureDetector(
      onLongPressStart: (details) {
        _showMicrophone();
      },
      onLongPressEnd: (details) {
        _hideMicrophone();
      },
      child: Container(
        color: Theme.of(context).primaryColor,
        child: Stack(
          children: <Widget>[
            /* Image(
                fit: BoxFit.cover,
                width: View.of(context).physicalSize.width,
                height: View.of(context).physicalSize.height,
                image: AssetImage('assets/images/street.jpg')), */
            Center(
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller);
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
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
                      child: Text(nivagationCue,
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
      ),
    );
  }
}
