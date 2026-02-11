import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';

/// Application Secrets & API Keys
///
/// SECURITY MODEL:
/// 1. Keys are stored in Android KeyStore / iOS Keychain via flutter_secure_storage
/// 2. Compile-time defaults are used as fallback for development only
/// 3. In production, keys should be set via the Settings screen or initial setup
///
/// For production deployment:
/// 1. Use Settings screen to configure API keys (stored securely)
/// 2. Or use --dart-define for compile-time injection
/// 3. Or use dart-define-from-file with a local secrets.json
class AppSecrets {
  // Cached values for synchronous access
  static String? _cachedSarvamKey;
  static String? _cachedScrapingDogKey;
  static bool _initialized = false;

  // Compile-time defaults (development only)
  // These are fallbacks when secure storage is empty
  static const String _defaultSarvamKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: "sk_j78ytxdk_VT7tOOTGMvuZD43XDcLoQKpm",
  );

  static const String _defaultScrapingDogKey = String.fromEnvironment(
    'SCRAPINGDOG_API_KEY',
    defaultValue: "69414673ebeb2d23522c1f04",
  );

  // Zoho Project configuration (for task/project management)
  static const Map<String, String> zohoConfig = {
    "project_id": "24392000000011167",
    "org_id": "60056122667",
    "client_id": "1000.S502C4RR4OX00EXMKPMKP246HJ9LYY",
  };

  /// Initialize secrets from secure storage
  /// Call this during app startup
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await secureStorage.initialize();

      // Migrate defaults to secure storage on first run
      await secureStorage.migrateFromDefaults(
        defaultSarvamKey: _defaultSarvamKey,
        defaultScrapingDogKey: _defaultScrapingDogKey,
      );

      // Load from secure storage
      _cachedSarvamKey = await secureStorage.getSarvamApiKey();
      _cachedScrapingDogKey = await secureStorage.getScrapingDogApiKey();

      _initialized = true;
      debugPrint('[AppSecrets] Initialized from secure storage');
    } catch (e) {
      debugPrint('[AppSecrets] Initialization error: $e');
      // Fallback to defaults
      _cachedSarvamKey = _defaultSarvamKey;
      _cachedScrapingDogKey = _defaultScrapingDogKey;
      _initialized = true;
    }
  }

  /// Sarvam AI API Key
  /// Priority: Secure storage > Environment variable > Default
  static String get sarvamApiKey {
    if (!_initialized) {
      // Return default if not initialized (synchronous fallback)
      return _defaultSarvamKey;
    }
    return _cachedSarvamKey ?? _defaultSarvamKey;
  }

  /// ScrapingDog API Key
  /// Priority: Secure storage > Environment variable > Default
  static String get scrapingDogApiKey {
    if (!_initialized) {
      return _defaultScrapingDogKey;
    }
    return _cachedScrapingDogKey ?? _defaultScrapingDogKey;
  }

  /// Async getter for Sarvam key (use when you need fresh value)
  static Future<String> getSarvamApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getSarvamApiKey();
    return key ?? _defaultSarvamKey;
  }

  /// Async getter for ScrapingDog key (use when you need fresh value)
  static Future<String> getScrapingDogApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getScrapingDogApiKey();
    return key ?? _defaultScrapingDogKey;
  }

  /// Update Sarvam API key in secure storage
  static Future<bool> setSarvamApiKey(String apiKey) async {
    final success = await secureStorage.setSarvamApiKey(apiKey);
    if (success) {
      _cachedSarvamKey = apiKey;
    }
    return success;
  }

  /// Update ScrapingDog API key in secure storage
  static Future<bool> setScrapingDogApiKey(String apiKey) async {
    final success = await secureStorage.setScrapingDogApiKey(apiKey);
    if (success) {
      _cachedScrapingDogKey = apiKey;
    }
    return success;
  }

  /// Check if using default/development keys
  static bool get isUsingDefaultKeys =>
      sarvamApiKey.contains("sk_vqh8cfif") ||
      scrapingDogApiKey == "69414673ebeb2d23522c1f04";

  /// Check if keys are properly configured
  static bool get areKeysConfigured =>
      sarvamApiKey.isNotEmpty && scrapingDogApiKey.isNotEmpty;

  /// Clear all stored keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    await secureStorage.deleteAllKeys();
    _cachedSarvamKey = null;
    _cachedScrapingDogKey = null;
    debugPrint('[AppSecrets] All keys cleared');
  }
}
