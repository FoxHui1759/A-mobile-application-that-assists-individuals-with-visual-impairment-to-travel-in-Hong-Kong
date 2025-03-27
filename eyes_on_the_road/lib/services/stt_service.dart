import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'tts_service.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _tts = TtsService();

  String recognizedWords = '';
  bool _isListening = false;
  String _localeId = 'zh_HK';

  // Initialize with optional locale parameter
  Future<bool> initialize({String? localeId}) async {
    if (localeId != null) {
      _localeId = localeId;
    }
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
          recognizedWords = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,
      );
    }
  }

  void stopListening() {
    if (_isListening) {
      _isListening = false;
      _speech.stop();
    }
  }

  void setLocale(String localeId) {
    _localeId = localeId;
  }

  bool get isListening => _isListening;
  String get localeId => _localeId;
}
