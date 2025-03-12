import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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

  final IO.Socket socket = IO.io('http://10.0.2.2:5000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });

  @override
  void initState() {
    _initializeSocket();
    _initializeCamera();

    super.initState();
  }

  void _initializeSocket() {
    socket.connect();
    socket.onConnect((_) {
      setState(() {
        message = 'Connected';
      });
    });
    socket.onDisconnect((_) {
      setState(() {
        message = 'Disconnected';
      });
    });
    socket.onConnectError((data) {
      setState(() {
        message = 'Error: $data';
      });
    });
    socket.onError((data) {
      setState(() {
        message = 'Error: $data';
      });
    });
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
          child: CameraView(camera: firstCamera!, socket: socket),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 0,
          ),
        ));
  }
}
