<<<<<<< Updated upstream
import 'package:socket_io_client/socket_io_client.dart' as IO;
=======
// api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
>>>>>>> Stashed changes

class ApiService {
  final IO.Socket socket = IO.io('http://10.0.2.2:5000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });
}
