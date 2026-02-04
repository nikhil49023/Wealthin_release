import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported locales in WealthIn
class AppLocales {
  static const Locale english = Locale('en');
  static const Locale hindi = Locale('hi');
  static const Locale tamil = Locale('ta');
  static const Locale telugu = Locale('te');

  static const List<Locale> supportedLocales = [
    english,
    hindi,
    tamil,
    telugu,
  ];

  static const Map<String, String> localeNames = {
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
  };

  static String getLocaleName(String code) {
    return localeNames[code] ?? code;
  }
}

/// Provider for managing app locale/language
class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _locale = AppLocales.english;
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;
  String get languageCode => _locale.languageCode;

  LocaleProvider() {
    _loadSavedLocale();
  }

  /// Load saved locale from preferences
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_localeKey);

      if (savedCode != null) {
        final savedLocale = AppLocales.supportedLocales.firstWhere(
          (l) => l.languageCode == savedCode,
          orElse: () => AppLocales.english,
        );
        _locale = savedLocale;
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Change the app locale
  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;

    if (!AppLocales.supportedLocales.contains(newLocale)) {
      debugPrint('Unsupported locale: $newLocale');
      return;
    }

    _locale = newLocale;
    notifyListeners();

    // Persist the choice
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, newLocale.languageCode);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  /// Set locale by language code
  Future<void> setLocaleByCode(String code) async {
    final locale = AppLocales.supportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppLocales.english,
    );
    await setLocale(locale);
  }

  /// Get the display name for current locale
  String get currentLocaleName =>
      AppLocales.getLocaleName(_locale.languageCode);
}

/// Singleton instance for global access
class LocaleService {
  static final LocaleProvider _instance = LocaleProvider();
  static LocaleProvider get instance => _instance;
}
