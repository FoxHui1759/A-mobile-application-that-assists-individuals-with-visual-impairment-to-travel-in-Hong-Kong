import 'package:socket_io_client/socket_io_client.dart' as IO;

class ApiService {
  final IO.Socket socket = IO.io('http://10.0.2.2:5000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });
}
