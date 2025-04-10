import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class STTService {
  static final STTService _instance = STTService._internal();
  factory STTService() => _instance;
  STTService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool isInitialized = false;

  Future<void> initialize() async {
    final status = await Permission.microphone.request();

    if (!status.isGranted) {
      throw Exception("Microphone permission not granted");
    }

    isInitialized = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );

    if (!isInitialized) {
      throw Exception("Speech recognition not available");
    }
  }

  Future<void> startListening(Function(String recognizedText) onResultCallback) async {
    if (!isInitialized) {
      throw Exception("Speech recognition is not initialized");
    }

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          onResultCallback(result.recognizedWords);
        }
      },
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
