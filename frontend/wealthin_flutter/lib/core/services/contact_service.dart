import 'package:flutter/foundation.dart';

/// Service for resolving contact names from mobile numbers
/// Contact loading is disabled — READ_CONTACTS permission was removed.
/// UPI name resolution uses the database-cached mapping instead.
class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  /// No-op — permissions are no longer requested at runtime.
  Future<bool> requestPermission() async => true;

  /// Always returns true — no runtime permission check needed.
  Future<bool> hasPermission() async => true;

  /// No-op — contacts are not loaded without READ_CONTACTS permission.
  Future<void> loadContacts() async {
    debugPrint('[ContactService] Contact loading disabled (no READ_CONTACTS permission)');
  }

  /// Always returns null — contact cache is empty.
  String? getContactName(String? mobileNumber) => null;

  /// Always returns null — contact cache is empty.
  String? getContactNameFromUpiId(String? upiId) => null;

  /// No-op
  void clearCache() {}

  /// Always returns 0.
  int get cacheSize => 0;
}

/// Global instance
final contactService = ContactService();
