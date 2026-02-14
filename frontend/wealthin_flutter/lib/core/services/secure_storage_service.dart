import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service for API Keys
/// Uses Android KeyStore / iOS Keychain for encrypted storage
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Storage keys
  static const String _openaiKeyKey = 'openai_api_key';
  static const String _sarvamKeyKey = 'sarvam_api_key';
  static const String _govMsmeKeyKey = 'gov_msme_api_key';
  static const String _groqKeyKey = 'groq_api_key';
  static const String _zohoClientIdKey = 'zoho_client_id';
  static const String _zohoClientSecretKey = 'zoho_client_secret';
  static const String _zohoRefreshTokenKey = 'zoho_refresh_token';

  // Android-specific secure storage options
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _initialized = false;

  // Cached values for performance
  String? _cachedOpenaiKey;
  String? _cachedSarvamKey;
  String? _cachedGovMsmeKey;
  String? _cachedGroqKey;

  /// Initialize the secure storage service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Pre-load cached values
      _cachedOpenaiKey = await _storage.read(key: _openaiKeyKey);
      _cachedSarvamKey = await _storage.read(key: _sarvamKeyKey);
      _cachedGovMsmeKey = await _storage.read(key: _govMsmeKeyKey);
      _cachedGroqKey = await _storage.read(key: _groqKeyKey);

      _initialized = true;
      debugPrint('[SecureStorage] Initialized successfully');
    } catch (e) {
      debugPrint('[SecureStorage] Initialization error: $e');
      _initialized = true; // Still mark as initialized to allow fallbacks
    }
  }

  // ==================== OPENAI ====================

  /// Get OpenAI API key from secure storage
  Future<String?> getOpenaiApiKey() async {
    if (!_initialized) await initialize();

    if (_cachedOpenaiKey != null) return _cachedOpenaiKey;

    try {
      final key = await _storage.read(key: _openaiKeyKey);
      _cachedOpenaiKey = key;
      return key;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading OpenAI key: $e');
      return null;
    }
  }

  /// Store OpenAI API key securely
  Future<bool> setOpenaiApiKey(String apiKey) async {
    if (!_initialized) await initialize();

    try {
      await _storage.write(key: _openaiKeyKey, value: apiKey);
      _cachedOpenaiKey = apiKey;
      debugPrint('[SecureStorage] OpenAI key stored securely');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error storing OpenAI key: $e');
      return false;
    }
  }

  // ==================== SARVAM AI ====================

  /// Get Sarvam API key from secure storage
  Future<String?> getSarvamApiKey() async {
    if (!_initialized) await initialize();

    if (_cachedSarvamKey != null) return _cachedSarvamKey;

    try {
      final key = await _storage.read(key: _sarvamKeyKey);
      _cachedSarvamKey = key;
      return key;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading Sarvam key: $e');
      return null;
    }
  }

  /// Store Sarvam API key securely
  Future<bool> setSarvamApiKey(String apiKey) async {
    if (!_initialized) await initialize();

    try {
      await _storage.write(key: _sarvamKeyKey, value: apiKey);
      _cachedSarvamKey = apiKey;
      debugPrint('[SecureStorage] Sarvam key stored securely');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error storing Sarvam key: $e');
      return false;
    }
  }

  // ==================== GOV MSME API ====================

  /// Get Government MSME API key from secure storage
  Future<String?> getGovMsmeApiKey() async {
    if (!_initialized) await initialize();

    if (_cachedGovMsmeKey != null) return _cachedGovMsmeKey;

    try {
      final key = await _storage.read(key: _govMsmeKeyKey);
      _cachedGovMsmeKey = key;
      return key;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading Gov MSME key: $e');
      return null;
    }
  }

  /// Store Government MSME API key securely
  Future<bool> setGovMsmeApiKey(String apiKey) async {
    if (!_initialized) await initialize();

    try {
      await _storage.write(key: _govMsmeKeyKey, value: apiKey);
      _cachedGovMsmeKey = apiKey;
      debugPrint('[SecureStorage] Gov MSME key stored securely');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error storing Gov MSME key: $e');
      return false;
    }
  }

  // ==================== GROQ ====================

  /// Get Groq API key from secure storage
  Future<String?> getGroqApiKey() async {
    if (!_initialized) await initialize();
    if (_cachedGroqKey != null) return _cachedGroqKey;
    try {
      final key = await _storage.read(key: _groqKeyKey);
      _cachedGroqKey = key;
      return key;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading Groq key: $e');
      return null;
    }
  }

  /// Store Groq API key securely
  Future<bool> setGroqApiKey(String apiKey) async {
    if (!_initialized) await initialize();
    try {
      await _storage.write(key: _groqKeyKey, value: apiKey);
      _cachedGroqKey = apiKey;
      debugPrint('[SecureStorage] Groq key stored securely');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error storing Groq key: $e');
      return false;
    }
  }

  // ==================== ZOHO ====================

  /// Get Zoho credentials from secure storage
  Future<Map<String, String?>> getZohoCredentials() async {
    if (!_initialized) await initialize();

    try {
      return {
        'client_id': await _storage.read(key: _zohoClientIdKey),
        'client_secret': await _storage.read(key: _zohoClientSecretKey),
        'refresh_token': await _storage.read(key: _zohoRefreshTokenKey),
      };
    } catch (e) {
      debugPrint('[SecureStorage] Error reading Zoho credentials: $e');
      return {'client_id': null, 'client_secret': null, 'refresh_token': null};
    }
  }

  /// Store Zoho credentials securely
  Future<bool> setZohoCredentials({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    if (!_initialized) await initialize();

    try {
      await _storage.write(key: _zohoClientIdKey, value: clientId);
      await _storage.write(key: _zohoClientSecretKey, value: clientSecret);
      await _storage.write(key: _zohoRefreshTokenKey, value: refreshToken);
      debugPrint('[SecureStorage] Zoho credentials stored securely');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error storing Zoho credentials: $e');
      return false;
    }
  }

  // ==================== UTILITY ====================

  /// Check if any API keys are stored
  Future<bool> hasStoredKeys() async {
    if (!_initialized) await initialize();

    try {
      final keys = await _storage.readAll();
      return keys.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Delete a specific key
  Future<bool> deleteKey(String keyName) async {
    if (!_initialized) await initialize();

    try {
      await _storage.delete(key: keyName);

      // Clear cache
      if (keyName == _openaiKeyKey) _cachedOpenaiKey = null;
      if (keyName == _sarvamKeyKey) _cachedSarvamKey = null;
      if (keyName == _govMsmeKeyKey) _cachedGovMsmeKey = null;
      if (keyName == _groqKeyKey) _cachedGroqKey = null;

      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting key: $e');
      return false;
    }
  }

  /// Delete all stored keys
  Future<bool> deleteAllKeys() async {
    if (!_initialized) await initialize();

    try {
      await _storage.deleteAll();

      // Clear all caches
      _cachedOpenaiKey = null;
      _cachedSarvamKey = null;
      _cachedGovMsmeKey = null;
      _cachedGroqKey = null;

      debugPrint('[SecureStorage] All keys deleted');
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting all keys: $e');
      return false;
    }
  }

  /// Migrate existing hardcoded keys to secure storage
  /// Call this once during app startup to move keys from compile-time to secure storage
  Future<void> migrateFromDefaults({
    String? defaultSarvamKey,
    String? defaultGovMsmeKey,
    String? defaultGroqKey,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Only migrate if not already stored
      if (defaultSarvamKey != null &&
          defaultSarvamKey.isNotEmpty &&
          (_cachedSarvamKey == null || _cachedSarvamKey!.isEmpty)) {
        final existing = await _storage.read(key: _sarvamKeyKey);
        if (existing == null || existing.isEmpty) {
          await setSarvamApiKey(defaultSarvamKey);
          debugPrint('[SecureStorage] Migrated Sarvam key to secure storage');
        }
      }

      if (defaultGovMsmeKey != null &&
          defaultGovMsmeKey.isNotEmpty &&
          (_cachedGovMsmeKey == null || _cachedGovMsmeKey!.isEmpty)) {
        final existing = await _storage.read(key: _govMsmeKeyKey);
        if (existing == null || existing.isEmpty) {
          await setGovMsmeApiKey(defaultGovMsmeKey);
          debugPrint('[SecureStorage] Migrated Gov MSME key to secure storage');
        }
      }

      if (defaultGroqKey != null &&
          defaultGroqKey.isNotEmpty &&
          (_cachedGroqKey == null || _cachedGroqKey!.isEmpty)) {
        final existing = await _storage.read(key: _groqKeyKey);
        if (existing == null || existing.isEmpty) {
          await setGroqApiKey(defaultGroqKey);
          debugPrint('[SecureStorage] Migrated Groq key to secure storage');
        }
      }
    } catch (e) {
      debugPrint('[SecureStorage] Migration error: $e');
    }
  }
}

/// Global instance
final secureStorage = SecureStorageService();
