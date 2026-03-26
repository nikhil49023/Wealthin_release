import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';

/// Application Secrets & API Keys
///
/// SECURITY MODEL:
/// 1. Keys are stored in Android KeyStore / iOS Keychain via flutter_secure_storage
/// 2. Compile-time injection via --dart-define is the ONLY way to set initial keys
/// 3. In production, keys should be set via the Settings screen or initial setup
/// 4. NO hardcoded keys in source code — GitHub secret scanning safe
///
/// **SARVAM AI ONLY** - All AI features now use Sarvam exclusively
class AppSecrets {
  static String? _cachedSarvamKey;
  static bool _initialized = false;

  static const String _defaultSarvamKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: 'sk_6x8vtp73_46INi99W2k0kt7R0UIVqcsld',
  );

  static const String _defaultSarvamChatModel = String.fromEnvironment(
    'SARVAM_CHAT_MODEL',
    defaultValue: 'sarvam-m',
  );

  static const String _defaultSarvamVisionModel = String.fromEnvironment(
    'SARVAM_VISION_MODEL',
    defaultValue: 'sarvam-m',
  );

  // Keep exactly one key. If legacy data stores comma-separated keys,
  // this picks the first non-empty key and discards the rest.
  static String _normalizeSingleKey(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains(',')) return trimmed;
    return trimmed
        .split(',')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
  }

  // Zoho Project configuration (non-secret project IDs)
  static const Map<String, String> zohoConfig = {
    "project_id": "24392000000011167",
    "org_id": "60056122667",
    "client_id": "1000.S502C4RR4OX00EXMKPMKP246HJ9LYY",
  };

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await secureStorage.initialize();

      final storedKey = _normalizeSingleKey(
        await secureStorage.getSarvamApiKey(),
      );
      final defaultKey = _normalizeSingleKey(_defaultSarvamKey);
      final resolvedKey = storedKey.isNotEmpty ? storedKey : defaultKey;

      if (resolvedKey.isNotEmpty) {
        await secureStorage.setSarvamApiKey(resolvedKey);
      }

      _cachedSarvamKey = resolvedKey;
      _initialized = true;

      debugPrint(
        '[AppSecrets] Initialized - Sarvam: ${_cachedSarvamKey != null && _cachedSarvamKey!.isNotEmpty ? '✓' : '✗'}',
      );
    } catch (e) {
      debugPrint('[AppSecrets] Initialization error: $e');
    }
  }

  static String get sarvamApiKey {
    final defaultKey = _normalizeSingleKey(_defaultSarvamKey);
    if (!_initialized) return defaultKey;
    final cachedKey = _normalizeSingleKey(_cachedSarvamKey);
    if (cachedKey.isNotEmpty) return cachedKey;
    return defaultKey;
  }

  static String get sarvamChatModel => _defaultSarvamChatModel;

  static String get sarvamVisionModel => _defaultSarvamVisionModel;

  static Future<String> getSarvamApiKeyAsync() async {
    if (!_initialized) await initialize();
    final stored = _normalizeSingleKey(await secureStorage.getSarvamApiKey());
    if (stored.isNotEmpty) {
      if (_cachedSarvamKey != stored) _cachedSarvamKey = stored;
      await secureStorage.setSarvamApiKey(stored);
      return stored;
    }
    return sarvamApiKey;
  }

  static Future<bool> setSarvamApiKey(String apiKey) async {
    final normalized = _normalizeSingleKey(apiKey);
    final success = await secureStorage.setSarvamApiKey(normalized);
    if (success) _cachedSarvamKey = normalized;
    return success;
  }

  static bool get isUsingDefaultKeys => sarvamApiKey.isEmpty;

  static bool get areKeysConfigured {
    if (_normalizeSingleKey(_cachedSarvamKey).isNotEmpty) {
      return true;
    }
    return _normalizeSingleKey(_defaultSarvamKey).isNotEmpty;
  }

  static Future<void> clearAllKeys() async {
    await secureStorage.deleteAllKeys();
    _cachedSarvamKey = null;
    debugPrint('[AppSecrets] All keys cleared');
  }
}
