import 'package:flutter/material.dart';

/// Startup Permissions Service - DISABLED (no-op)
///
/// The app no longer requests any permissions at startup.
/// All transaction detection uses the Notification Listener Service
/// which is toggled from Data Sources settings (no runtime permission needed).
class StartupPermissionsService {
  static final StartupPermissionsService _instance =
      StartupPermissionsService._internal();
  factory StartupPermissionsService() => _instance;
  StartupPermissionsService._internal();

  bool _hasRequestedPermissions = false;

  /// No-op — no permissions are requested at startup.
  Future<void> requestStartupPermissions(BuildContext context) async {
    if (_hasRequestedPermissions) return;
    _hasRequestedPermissions = true;
    debugPrint('[Permissions] No startup permissions needed — all features work without runtime permissions.');
  }

  /// Always returns true — no permissions are checked.
  Future<bool> hasPermission(dynamic permission) async => true;

  /// Always returns true — no critical permissions exist.
  Future<bool> hasAllCriticalPermissions() async => true;
}

/// Global instance
final startupPermissions = StartupPermissionsService();
