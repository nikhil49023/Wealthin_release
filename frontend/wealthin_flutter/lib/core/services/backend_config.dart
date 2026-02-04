import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

/// Backend Configuration Service
/// Manages backend connectivity with dynamic port discovery and health checks
class BackendConfig {
  BackendConfig._internal();
  static final BackendConfig _instance = BackendConfig._internal();
  factory BackendConfig() => _instance;

  // Port scanning configuration
  static const List<int> _portRange = [8000, 8001, 8002, 8003, 8004, 8005];
  static const Duration _timeout = Duration(seconds: 5);

  // Cached active port
  int? _activePort;
  bool _isInitialized = false;
  DateTime? _lastHealthCheck;

  /// Get the backend host based on platform
  String get _host {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }

  /// Get the backend URL (platform-aware)
  String get baseUrl {
    final port = _activePort ?? 8000;
    return 'http://$_host:$port';
  }

  /// Get the active port
  int get activePort => _activePort ?? 8000;

  /// Check if backend is connected
  bool get isConnected => _activePort != null;

  /// Initialize backend connection (find active port)
  Future<bool> initialize({int retries = 3}) async {
    if (_isInitialized && _activePort != null) {
      // Re-verify connection if last check was > 30 seconds ago
      final now = DateTime.now();
      if (_lastHealthCheck != null &&
          now.difference(_lastHealthCheck!).inSeconds < 30) {
        return true;
      }
    }

    // Retry logic for initial connection
    for (int attempt = 0; attempt < retries; attempt++) {
      // Scan ports to find active backend
      for (final port in _portRange) {
        if (await _checkPort(port)) {
          _activePort = port;
          _isInitialized = true;
          _lastHealthCheck = DateTime.now();
          debugPrint('[Backend] Connected on port $port');
          return true;
        }
      }

      // Wait before retry
      if (attempt < retries - 1) {
        debugPrint('[Backend] Retry ${attempt + 1}/$retries...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    debugPrint('[Backend] No active backend found on ports $_portRange');
    // Set default port for fallback
    _activePort = 8000;
    return false;
  }

  /// Check if a specific port has the backend running
  Future<bool> _checkPort(int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$_host:$port/health'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        // Verify it's our backend
        return body.contains('wealthin') || body.contains('active') || body.contains('healthy');
      }
    } catch (e) {
      // Port not responding - silent fail
    }
    return false;
  }

  /// Health check the current connection
  Future<bool> healthCheck() async {
    if (_activePort == null) return false;
    final healthy = await _checkPort(_activePort!);
    if (healthy) {
      _lastHealthCheck = DateTime.now();
    } else {
      // Try to find a new port
      _activePort = null;
      _isInitialized = false;
    }
    return healthy;
  }

  /// Get backend status information
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'connected': true,
          'port': _activePort,
          'response': response.body,
        };
      }
    } catch (e) {
      // Connection failed
    }
    return {
      'connected': false,
      'port': _activePort,
      'error': 'Backend not responding',
    };
  }

  /// Get LLM service status
  Future<Map<String, dynamic>> getLLMStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/llm/status'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.body};
      }
    } catch (e) {
      // LLM status endpoint not available
    }
    return {'success': false, 'error': 'LLM status unavailable'};
  }

  /// Force reconnect (scan for new port)
  Future<bool> reconnect() async {
    _activePort = null;
    _isInitialized = false;
    return initialize();
  }
}

/// Global backend config instance
final backendConfig = BackendConfig();
