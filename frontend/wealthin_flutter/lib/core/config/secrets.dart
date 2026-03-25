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
///    flutter run --dart-define=SARVAM_API_KEY=sk_xxx
/// 3. Or use dart-define-from-file with a local secrets.json
///
/// **SARVAM AI ONLY** - All AI features now use Sarvam exclusively
class AppSecrets {
  // Cached values for synchronous access
  static String? _cachedSarvamKey;
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

  static const String _defaultSarvamChatModel = String.fromEnvironment(
    'SARVAM_CHAT_MODEL',
    defaultValue: 'sarvam-m',
  );

  static const String _defaultSarvamVisionModel = String.fromEnvironment(
    'SARVAM_VISION_MODEL',
    defaultValue: 'sarvam-m',
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
      for (final key in const ['sarvam_api_key']) {
        final value = payload[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          secrets[key] = value;
        }
      }
      return secrets;
    } catch (e) {
      debugPrint('[AppSecrets] Error loading Android build secrets: $e');
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

      // Migrate compile-time defaults to secure storage on first run
      await secureStorage.migrateFromDefaults(
        defaultSarvamKey: fallbackSarvamKey,
      );

      // Load from secure storage
      _cachedSarvamKey = await secureStorage.getSarvamApiKey();
      _initialized = true;

      debugPrint('[AppSecrets] Initialized - Sarvam: ${_cachedSarvamKey != null ? '✓' : '✗'}');
    } catch (e) {
      debugPrint('[AppSecrets] Initialization error: $e');
    }
  }

  /// Sarvam AI API Key (only AI provider now)
  static String get sarvamApiKey {
    if (!_initialized) return _defaultSarvamKey;
    return _cachedSarvamKey ?? _defaultSarvamKey;
  }

  /// Sarvam chat model identifier (can be overridden via --dart-define).
  static String get sarvamChatModel => _defaultSarvamChatModel;

  /// Sarvam vision model identifier (can be overridden via --dart-define).
  static String get sarvamVisionModel => _defaultSarvamVisionModel;

  /// Async getter for Sarvam key
  static Future<String> getSarvamApiKeyAsync() async {
    if (!_initialized) await initialize();
    final key = await secureStorage.getSarvamApiKey();
    return key ?? _defaultSarvamKey;
  }

  /// Update Sarvam API key in secure storage
  static Future<bool> setSarvamApiKey(String apiKey) async {
    final success = await secureStorage.setSarvamApiKey(apiKey);
    if (success) _cachedSarvamKey = apiKey;
    return success;
  }

  /// Check if using default/development keys
  static bool get isUsingDefaultKeys => sarvamApiKey.isEmpty;

  /// Check if keys are properly configured
  static bool get areKeysConfigured => sarvamApiKey.isNotEmpty;

  /// Clear all stored keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    await secureStorage.deleteAllKeys();
    _cachedSarvamKey = null;
    debugPrint('[AppSecrets] All keys cleared');
  }
}
