import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';

/// Application Secrets & API Keys
///
/// SECURITY MODEL:
/// 1. Keys are stored in Android KeyStore / iOS Keychain via flutter_secure_storage
/// 2. Compile-time injection via --dart-define is the ONLY way to set initial keys
/// 3. In production, keys should be set via the Settings screen or initial setup
/// 4. NO hardcoded keys in source code — GitHub secret scanning safe
///
/// For production deployment:
/// 1. Use Settings screen to configure API keys (stored securely)
/// 2. Or use --dart-define for compile-time injection:
///    flutter run --dart-define=SARVAM_API_KEY=sk_xxx --dart-define=GROQ_API_KEY=gsk_xxx
/// 3. Or use dart-define-from-file with a local secrets.json
class AppSecrets {
  // Cached values for synchronous access
  static String? _cachedSarvamKey;
  static String? _cachedGovMsmeKey;
  static String? _cachedGroqKey;
  static bool _initialized = false;

  // Compile-time injection (via --dart-define or --dart-define-from-file)
  // These are empty by default — no secrets in source code
  static const MethodChannel _androidSecretsChannel = MethodChannel(
    'wealthin/secrets',
  );

  static const String _defaultSarvamKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: '',
  );

  static const String _defaultGovMsmeKey = String.fromEnvironment(
    'GOV_MSME_API_KEY',
    defaultValue: '',
  );

  static const String _defaultGroqKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static Future<Map<String, String>> _loadAndroidBuildSecrets() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const {};
    }

    try {
      final payload = await _androidSecretsChannel
          .invokeMapMethod<String, dynamic>('getBuildSecrets');
      if (payload == null || payload.isEmpty) return const {};

      final secrets = <String, String>{};
      for (final key in const [
        'sarvam_api_key',
        'gov_msme_api_key',
        'groq_api_key',
      ]) {
        final value = payload[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          secrets[key] = value;
        }
      }
      return secrets;
    } catch (e) {
      debugPrint('[AppSecrets] Android build secret fetch failed: $e');
      return const {};
    }
  }

  // Zoho Project configuration (non-secret project IDs)
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

      final androidBuildSecrets = await _loadAndroidBuildSecrets();
      final fallbackSarvamKey =
          androidBuildSecrets['sarvam_api_key'] ?? _defaultSarvamKey;
      final fallbackGovMsmeKey =
          androidBuildSecrets['gov_msme_api_key'] ?? _defaultGovMsmeKey;
      final fallbackGroqKey =
          androidBuildSecrets['groq_api_key'] ?? _defaultGroqKey;

      // Migrate compile-time defaults to secure storage on first run
      await secureStorage.migrateFromDefaults(
        defaultSarvamKey: fallbackSarvamKey,
        defaultGovMsmeKey: fallbackGovMsmeKey,
        defaultGroqKey: fallbackGroqKey,
      );

      // Load from secure storage
      _cachedSarvamKey = await secureStorage.getSarvamApiKey();
      _cachedGovMsmeKey = await secureStorage.getGovMsmeApiKey();
      _cachedGroqKey = await secureStorage.getGroqApiKey();

      _initialized = true;
      debugPrint('[AppSecrets] Initialized from secure storage');
    } catch (e) {
      debugPrint('[AppSecrets] Initialization error: $e');
      // Fallback to compile-time defaults
      _cachedSarvamKey = _defaultSarvamKey;
      _cachedGovMsmeKey = _defaultGovMsmeKey;
      _cachedGroqKey = _defaultGroqKey;
      _initialized = true;
    }
  }

  /// Sarvam AI API Key
  static String get sarvamApiKey {
    if (!_initialized) return _defaultSarvamKey;
    return _cachedSarvamKey ?? _defaultSarvamKey;
  }

  /// Government MSME API Key (data.gov.in)
  static String get govMsmeApiKey {
    if (!_initialized) return _defaultGovMsmeKey;
    return _cachedGovMsmeKey ?? _defaultGovMsmeKey;
  }

  /// Groq API Key (for Ideas/Brainstorm - GPT-OSS 20B)
  static String get groqApiKey {
    if (!_initialized) return _defaultGroqKey;
    return _cachedGroqKey ?? _defaultGroqKey;
  }

  /// Async getter for Sarvam key
  static Future<String> getSarvamApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getSarvamApiKey();
    return key ?? _defaultSarvamKey;
  }

  /// Async getter for Gov MSME key
  static Future<String> getGovMsmeApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getGovMsmeApiKey();
    return key ?? _defaultGovMsmeKey;
  }

  /// Async getter for Groq key
  static Future<String> getGroqApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getGroqApiKey();
    return key ?? _defaultGroqKey;
  }

  /// Update Sarvam API key in secure storage
  static Future<bool> setSarvamApiKey(String apiKey) async {
    final success = await secureStorage.setSarvamApiKey(apiKey);
    if (success) _cachedSarvamKey = apiKey;
    return success;
  }

  /// Update Gov MSME API key in secure storage
  static Future<bool> setGovMsmeApiKey(String apiKey) async {
    final success = await secureStorage.setGovMsmeApiKey(apiKey);
    if (success) _cachedGovMsmeKey = apiKey;
    return success;
  }

  /// Update Groq API key in secure storage
  static Future<bool> setGroqApiKey(String apiKey) async {
    final success = await secureStorage.setGroqApiKey(apiKey);
    if (success) _cachedGroqKey = apiKey;
    return success;
  }

  /// Check if using default/development keys
  static bool get isUsingDefaultKeys =>
      sarvamApiKey.isEmpty || groqApiKey.isEmpty;

  /// Check if keys are properly configured
  static bool get areKeysConfigured =>
      sarvamApiKey.isNotEmpty && groqApiKey.isNotEmpty;

  /// Clear all stored keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    await secureStorage.deleteAllKeys();
    _cachedSarvamKey = null;
    _cachedGovMsmeKey = null;
    _cachedGroqKey = null;
    debugPrint('[AppSecrets] All keys cleared');
  }
}
