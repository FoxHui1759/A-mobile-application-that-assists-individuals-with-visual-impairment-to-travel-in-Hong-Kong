import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String message = 'Watiting for message from the server...';
  IO.Socket socket = IO.io('http://10.0.2.2:5000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });

  @override
  Widget build(BuildContext context) {
    socket.connect();

    socket.onConnect((_) {
      print('connect');
    });

    socket.on('message', (data) {
      setState(() {
        message = data;
      });
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Settings Page',
            style: TextStyle(fontSize: 20),
          ),
          Text(
            message,
            style: TextStyle(fontSize: 20),
          )
        ],
      ),
    );
  }
}
