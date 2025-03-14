import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  Future<bool> initialize() async {
    return await _speech.initialize(
      onStatus: (status) => print('Speech Status: $status'),
      onError: (error) => print('Speech Error: $error'),
    );
  }

  void startListening() async {
    if (!_isListening) {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          print('Recognized Speech: ${result.recognizedWords}');
        },
        listenFor: Duration(seconds: 60),
        pauseFor: Duration(seconds: 3),
        localeId: 'en_US',
      );
    }
  }

  void stopListening() {
    if (_isListening) {
      _isListening = false;
      _speech.stop();
    }
  }

  bool get isListening => _isListening;
}
