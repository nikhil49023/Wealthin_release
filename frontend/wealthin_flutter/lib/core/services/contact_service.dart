import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for resolving contact names from mobile numbers
/// Used to enhance SMS transaction descriptions with real contact names
class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  /// Cache for mobile number to contact name mapping
  final Map<String, String> _contactCache = {};
  
  /// Whether contacts have been loaded
  bool _contactsLoaded = false;

  /// Request contacts permission
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Load all contacts and build mobile number cache
  Future<void> loadContacts() async {
    if (_contactsLoaded) return;

    try {
      if (!await hasPermission()) {
        debugPrint('[ContactService] No contacts permission');
        return;
      }

      debugPrint('[ContactService] Loading contacts...');
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      _contactCache.clear();

      for (final contact in contacts) {
        final name = contact.displayName;
        if (name.isEmpty) continue;

        // Add all phone numbers for this contact
        for (final phone in contact.phones) {
          final normalized = _normalizePhoneNumber(phone.number);
          if (normalized != null && normalized.length == 10) {
            _contactCache[normalized] = name;
          }
        }
      }

      _contactsLoaded = true;
      debugPrint('[ContactService] Loaded ${_contactCache.length} contact numbers');
    } catch (e) {
      debugPrint('[ContactService] Error loading contacts: $e');
    }
  }

  /// Resolve contact name from mobile number
  /// Returns contact name if found, null otherwise
  String? getContactName(String? mobileNumber) {
    if (mobileNumber == null || mobileNumber.isEmpty) return null;

    final normalized = _normalizePhoneNumber(mobileNumber);
    if (normalized == null) return null;

    return _contactCache[normalized];
  }

  /// Resolve contact name from UPI ID
  /// Extracts mobile number from UPI ID (e.g., 9876543210@ybl)
  String? getContactNameFromUpiId(String? upiId) {
    if (upiId == null || upiId.isEmpty) return null;

    // Extract mobile number from UPI ID
    final parts = upiId.split('@');
    if (parts.isEmpty) return null;

    final username = parts[0];
    
    // Check if username is a 10-digit mobile number
    if (RegExp(r'^\d{10}$').hasMatch(username)) {
      return getContactName(username);
    }

    return null;
  }

  /// Normalize phone number to 10-digit format
  /// Removes country code, spaces, dashes, etc.
  String? _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) return null;

    // Handle Indian phone numbers
    // +91 9876543210 -> 9876543210
    // 919876543210 -> 9876543210
    // 09876543210 -> 9876543210
    
    if (digitsOnly.length == 10) {
      return digitsOnly;
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      return digitsOnly.substring(1);
    } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return digitsOnly.substring(2);
    } else if (digitsOnly.length == 13 && digitsOnly.startsWith('091')) {
      return digitsOnly.substring(3);
    }

    return null;
  }

  /// Clear contact cache (useful for logout or refresh)
  void clearCache() {
    _contactCache.clear();
    _contactsLoaded = false;
  }

  /// Get cache size (for debugging)
  int get cacheSize => _contactCache.length;
}

/// Global instance
final contactService = ContactService();
