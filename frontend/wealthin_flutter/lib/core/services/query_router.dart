import 'package:flutter/foundation.dart';

/// Query Router for API-only inference.
///
/// This app now routes all requests to the API provider.
class QueryRouter {
  static final QueryRouter _instance = QueryRouter._internal();
  factory QueryRouter() => _instance;
  QueryRouter._internal();

  // Device capability detection
  bool _deviceCapable = true;
  final int _deviceRAM = 0;
  final String _chipset = 'unknown';

  /// Routing mode is fixed to API-only.
  static RoutingMode routingMode = RoutingMode.apiOnly;

  /// Initialize and detect device capabilities
  Future<void> initialize() async {
    _deviceCapable = false;
    debugPrint('[QueryRouter] Device capable: $_deviceCapable');
    debugPrint('[QueryRouter] Routing mode: $routingMode');
  }

  /// Local inference is disabled.
  Future<bool> _detectDeviceCapability() async {
    return false;
  }

  /// Route all queries to API.
  InferenceStrategy routeQuery(String query, {QueryContext? context}) {
    return InferenceStrategy.api;
  }

  /// Get routing statistics
  Map<String, dynamic> getStats() {
    return {
      'device_capable': _deviceCapable,
      'device_ram': _deviceRAM,
      'chipset': _chipset,
      'routing_mode': routingMode.toString(),
    };
  }

  /// Set routing mode
  static void setRoutingMode(RoutingMode mode) {
    routingMode = mode;
    debugPrint('[QueryRouter] Routing mode changed to: $mode');
  }
}

/// Routing mode - determines how queries are routed
enum RoutingMode {
  localFirst,
  localOnly,
  apiOnly, // Sarvam AI only, no local
  hybrid,
  apiFirst,
}

/// Inference strategy decision
enum InferenceStrategy {
  local,
  api, // Use Sarvam API only
  localWithFallback,
}

/// Query complexity analysis
class QueryContext {
  final bool forceAPI;
  final bool forceLocal;
  final bool requiresWebAccess;
  final bool requiresAccuracy;
  final bool isAgenticLoop;
  final bool isInnerQuery;

  QueryContext({
    this.forceAPI = false,
    this.forceLocal = false,
    this.requiresWebAccess = false,
    this.requiresAccuracy = false,
    this.isAgenticLoop = false,
    this.isInnerQuery = false,
  });
}

/// Global instance
final queryRouter = QueryRouter();
