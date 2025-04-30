import 'dart:io';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:eyes_on_the_road/utils/camera_image_converter.dart';

class ScannerController extends GetxController {
  String message = "";

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  ObjectDetector? objectDetector;

  var frameCount = 0;
  var isCameraReady = false.obs;
  var isInitializing = false.obs;
  var errorMessage = ''.obs;

  List<DetectedObject> detectedObjects = <DetectedObject>[];

  @override
  Future<void> onInit() async {
    super.onInit();
    try {
      isInitializing(true);
      // Initialize camera first, then object detector
      await initCamera();
      if (isCameraReady.value) {
        await initObjectDetector();
      }
    } catch (e) {
      errorMessage('Initialization error: $e');
      print('Controller initialization error: $e');
    } finally {
      isInitializing(false);
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (isCameraReady.value) {
      cameraController.dispose();
    }
    objectDetector?.close();
  }

  Future<void> initCamera() async {
    try {
      // Request camera permission with better error handling
      final status = await Permission.camera.request();

      if (status.isGranted) {
        // Permission granted, initialize camera
        cameras = await availableCameras();

        if (cameras.isEmpty) {
          errorMessage('No cameras available on this device');
          return;
        }

        cameraController = CameraController(
          cameras[0],
          ResolutionPreset.max,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );

        await cameraController.initialize();

        // Start image stream after successful initialization
        await cameraController.startImageStream((CameraImage image) async {
          frameCount++;
          if (frameCount % 60 == 0) {
            frameCount = 0;
            await runDetector(cameras[0], cameraController, image);
            update();
          }
        });

        isCameraReady(true);
        update();
      } else if (status.isPermanentlyDenied) {
        errorMessage(
            'Camera permission permanently denied. Please enable in app settings.');
      } else {
        errorMessage('Camera permission denied: $status');
      }
    } catch (e) {
      errorMessage('Camera initialization error: $e');
      print("Camera error: $e");
    }
  }

  Future<void> initObjectDetector() async {
    try {
      final modelPath =
          await getModelPath('assets/models/object_labeler.tflite');

      // Verify model file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        errorMessage('Object detection model not found');
        print('Model file not found at: $modelPath');
        return;
      }

      final options = LocalObjectDetectorOptions(
        mode: DetectionMode.single,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
        maximumLabelsPerObject: 1,
      );

      objectDetector = ObjectDetector(options: options);
    } catch (e) {
      errorMessage('Object detector initialization error: $e');
      print("Object detector error: $e");
    }
  }

  Future<String> getModelPath(String asset) async {
    try {
      final path = '${(await getApplicationSupportDirectory()).path}/$asset';
      await Directory(dirname(path)).create(recursive: true);
      final file = File(path);

      if (!await file.exists()) {
        final byteData = await rootBundle.load(asset);
        await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }

      return file.path;
    } catch (e) {
      errorMessage('Error preparing model file: $e');
      print("Model path error: $e");
      return '';
    }
  }

  // Helper function to calculate object position
  String calculateObjectPosition(double objectCenterX, double imageWidth) {
    final thirdOfWidth = imageWidth / 3;

    if (objectCenterX < thirdOfWidth) {
      return "Left";
    } else if (objectCenterX > 2 * thirdOfWidth) {
      return "Right";
    } else {
      return "Middle";
    }
  }

  // Helper function to determine the message based on detected objects
  void determineMessage(
      List<String> positions, List<String> labels, List<double> areas) {
    String s = "";
    for (int i = 0; i < positions.length; i++) {
      s += "${positions[i]} ${labels[i]} ";
    }
    message = s;
    print("Message: $message");
  }

  runDetector(CameraDescription camera, CameraController controller,
      CameraImage image) async {
    try {
      final inputImage = CameraImageConverter.inputImageFromCameraImage(
        cameras[0],
        cameraController,
        image,
      );

      List<String> positions = [];
      List<String> labels = [];
      List<double> areas = [];

      for (final detectedObject in detectedObjects) {
        print("Bounding box: ${detectedObject.boundingBox}");

        final boundingBox = detectedObject.boundingBox;
        final imageWidth = inputImage!.metadata!.size.width;

        // Calculate the object area
        final objectArea = boundingBox.width * boundingBox.height;
        areas.add(objectArea);
        //print("Object area: $objectArea");

        // Calculate the object position
        if (imageWidth > 0) {
          final objectCenterX = boundingBox.left + (boundingBox.width / 2);
          final position = calculateObjectPosition(objectCenterX, imageWidth);

          positions.add(position);
          //print("Object position: $position");
        } else {
          //print("Unable to determine object position");
        }

        // Get the label of the detected object
        if (detectedObject.labels.isNotEmpty) {
          final label = detectedObject.labels[0].text;
          labels.add(label);
          //print("Detected label: $label");
        } else {
          labels.add("Object");
          //print("No labels detected");

          detectedObjects = await objectDetector!.processImage(inputImage);

          for (final detectedObject in detectedObjects) {
            print("Detected object: ${detectedObject.trackingId}");
            print("Bounding box: ${detectedObject.boundingBox}");

            final boundingBox = detectedObject.boundingBox;
            final imageWidth = inputImage.metadata!.size.width;

            // Calculate the object position
            if (imageWidth > 0) {
              final objectCenterX = boundingBox.left + (boundingBox.width / 2);
              final position =
                  calculateObjectPosition(objectCenterX, imageWidth);

              print("Object position: $position");
            } else {
              print("Unable to determine object position");
            }

            for (final label in detectedObject.labels) {
              print("label: ${label.text}");
            }
          }
        }
      }

      // determine the message based on the detected objects
      determineMessage(positions, labels, areas);
    } catch (e) {
      print("Error running detector: $e");
    }
  }
}
