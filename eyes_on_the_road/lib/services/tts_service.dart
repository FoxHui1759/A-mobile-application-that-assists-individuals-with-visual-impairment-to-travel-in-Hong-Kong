// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _tts.setVolume(1.0); // Default: 1.0 (max volume)
    _tts.setSpeechRate(1.0); // Default: 1.0 (normal speed)
    _tts.setPitch(1.0); // Default: 1.0 (normal tone)
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _tts.speak(text);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void setVolume(double volume) {
    _tts.setVolume(volume);
  }

  void setRate(double rate) {
    _tts.setSpeechRate(rate);
  }

  void setPitch(double pitch) {
    _tts.setPitch(pitch);
  }

  void setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

}
