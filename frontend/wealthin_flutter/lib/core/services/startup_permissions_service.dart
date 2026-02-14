import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Startup Permissions Service - Request critical permissions on app launch
class StartupPermissionsService {
  static final StartupPermissionsService _instance = StartupPermissionsService._internal();
  factory StartupPermissionsService() => _instance;
  StartupPermissionsService._internal();

  bool _hasRequestedPermissions = false;

  /// Request all critical permissions on app startup
  Future<void> requestStartupPermissions(BuildContext context) async {
    if (_hasRequestedPermissions) return;
    _hasRequestedPermissions = true;

    debugPrint('[Permissions] Requesting startup permissions...');

    // Check which permissions are needed
    final contactsStatus = await Permission.contacts.status;

    final permissionsNeeded = <Permission>[];

    if (!contactsStatus.isGranted) {
      permissionsNeeded.add(Permission.contacts);
    }

    if (permissionsNeeded.isEmpty) {
      debugPrint('[Permissions] All permissions already granted');
      return;
    }

    // Show explanation dialog
    if (context.mounted) {
      final shouldProceed = await _showPermissionExplanation(context, permissionsNeeded);
      
      if (!shouldProceed) {
        debugPrint('[Permissions] User declined permission request');
        return;
      }
    }

    // Request permissions
    for (final permission in permissionsNeeded) {
      try {
        final status = await permission.request();
        debugPrint('[Permissions] ${permission.toString()}: ${status.toString()}');
      } catch (e) {
        debugPrint('[Permissions] Error requesting ${permission.toString()}: $e');
      }
    }

    debugPrint('[Permissions] Startup permissions request complete');
  }

  /// Show explanation dialog for why we need permissions
  Future<bool> _showPermissionExplanation(
    BuildContext context,
    List<Permission> permissions,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 12),
            Text('Enable Smart Features'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WealthIn needs these permissions to provide you with powerful features:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              
              if (permissions.contains(Permission.contacts)) ...[
                _buildPermissionItem(
                  icon: Icons.contacts,
                  title: 'Contacts Access',
                  description: 'Share budgets with family members and invite them to groups.',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
              ],
              
              const Divider(),
              const SizedBox(height: 8),
              
              const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your privacy is protected. All data stays on your device.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable Features'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Build permission item widget
  static Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Check if a specific permission is granted
  Future<bool> hasPermission(Permission permission) async {
    return await permission.isGranted;
  }

  /// Check if all critical permissions are granted
  Future<bool> hasAllCriticalPermissions() async {
    final contactsGranted = await Permission.contacts.isGranted;
    return contactsGranted;
  }
}

/// Global instance
final startupPermissions = StartupPermissionsService();
