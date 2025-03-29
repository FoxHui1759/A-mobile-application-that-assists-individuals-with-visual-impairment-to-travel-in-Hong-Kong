// lib/services/app_language_service.dart
import 'package:flutter/foundation.dart';

class AppLanguageService extends ChangeNotifier {
  // Language codes
  static const String englishCode = 'en-US';
  static const String chineseCode = 'zh-HK';

  // Default to English
  String _currentLanguageCode = englishCode;
  final bool _isInitialized = true;

  // Getters
  String get currentLanguageCode => _currentLanguageCode;
  bool get isEnglish => _currentLanguageCode == englishCode;
  bool get isChinese => _currentLanguageCode == chineseCode;
  bool get isInitialized => _isInitialized;

  // Constructor
  AppLanguageService();

  // Switch to English
  void useEnglish() {
    if (_currentLanguageCode != englishCode) {
      _currentLanguageCode = englishCode;
      notifyListeners();
    }
  }

  // Switch to Chinese
  void useChinese() {
    if (_currentLanguageCode != chineseCode) {
      _currentLanguageCode = chineseCode;
      notifyListeners();
    }
  }

  // Toggle between English and Chinese
  void toggleLanguage() {
    if (isEnglish) {
      useChinese();
    } else {
      useEnglish();
    }
  }

  // Get human-readable language name
  String get currentLanguageName {
    return isEnglish ? 'English' : '中文';
  }
}