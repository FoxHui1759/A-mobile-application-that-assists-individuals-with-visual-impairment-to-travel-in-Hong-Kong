import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    //initTFLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var frameCount = 0;

  var isCameraReady = false.obs;

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();

      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await cameraController.initialize().then((value) {
        cameraController.startImageStream((CameraImage image) {
          frameCount++;
          if (frameCount % 10 == 0) {
            objectDetector(image);
          }
          update();
        });
      });
      isCameraReady(true);
      update();
    } else {
      print("Permission denied");
    }
  }

  initTFLite() async {}

  objectDetector(CameraImage image) async {}
}
