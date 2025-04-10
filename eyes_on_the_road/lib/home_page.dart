import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'views/camera_view.dart';

class HomePage extends StatefulWidget {
  final String title;

  HomePage({required this.title});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CameraDescription>? cameras;
  CameraDescription? firstCamera;

  String message = '';

  @override
  void initState() {
    _initializeCamera();
    super.initState();
  }

  void _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      firstCamera = cameras![0];
      setState(() {}); // Trigger a rebuild after setting the camera
    }
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        body: Center(
            child: firstCamera != null
                ? CameraView(camera: firstCamera!)
                : const CircularProgressIndicator()),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 0,
          ),
        ));
  }
}
