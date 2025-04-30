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

  late ObjectDetector objectDetector;

  var frameCount = 0;
  var isCameraReady = false.obs;

  List<DetectedObject> detectedObjects = <DetectedObject>[];

  @override
  void onInit() {
    super.onInit();
    initCamera();
    initObjectDectector();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
    objectDetector.close();
  }

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();

      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await cameraController.initialize().then((value) {
        cameraController.startImageStream((CameraImage image) async {
          frameCount++;
          if (frameCount % 60 == 0) {
            frameCount = 0;
            await runDetector(cameras[0], cameraController, image);
            update();
          }
        });
      });
      isCameraReady(true);
      update();
    } else {
      print("Permission denied");
    }
  }

  initObjectDectector() async {
    final modelPath = await getModelPath('assets/models/object_labeler.tflite');
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.single,
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
      maximumLabelsPerObject: 1,
    );
    objectDetector = ObjectDetector(options: options);
  }

  Future<String> getModelPath(String asset) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$asset';
    await Directory(dirname(path)).create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(asset);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
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
  determineMessage(
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
    final inputImage = CameraImageConverter.inputImageFromCameraImage(
      cameras[0],
      cameraController,
      image,
    );
    if (inputImage == null) {
      throw Exception("inputImage is null");
    }
    detectedObjects = await objectDetector.processImage(inputImage);
    print("New Detecttion");

    List<String> positions = [];
    List<String> labels = [];
    List<double> areas = [];

    for (final detectedObject in detectedObjects) {
      print("Bounding box: ${detectedObject.boundingBox}");

      final boundingBox = detectedObject.boundingBox;
      final imageWidth = inputImage.metadata!.size.width;

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
      }
    }

    // determine the message based on the detected objects
    determineMessage(positions, labels, areas);
  }
}
