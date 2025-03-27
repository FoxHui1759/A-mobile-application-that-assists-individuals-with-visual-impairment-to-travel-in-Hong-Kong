import 'package:text_to_speech/text_to_speech.dart';

class TtsService {
  final TextToSpeech _tts = TextToSpeech();

  TtsService() {
    _tts.setVolume(1.0); // Default: 1.0 (max volume)
    _tts.setRate(1.0); // Default: 1.0 (normal speed)
    _tts.setPitch(1.0); // Default: 1.0 (normal tone)
    _tts.setLanguage('zh-HK'); // Set default language to Cantonese
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
    _tts.setRate(rate);
  }

  void setPitch(double pitch) {
    _tts.setPitch(pitch);
  }

  void setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

}
