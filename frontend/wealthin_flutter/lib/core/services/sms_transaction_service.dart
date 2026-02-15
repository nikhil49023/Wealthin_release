import 'package:flutter/foundation.dart';

/// SMS Transaction Service - DISABLED (static stub)
///
/// SMS-based transaction extraction has been removed.
/// All transaction detection now happens via Notification Listener Service.
/// This file is kept as a stub to avoid breaking any remaining imports.
class SmsTransactionService {
  static final SmsTransactionService _instance =
      SmsTransactionService._internal();
  factory SmsTransactionService() => _instance;
  SmsTransactionService._internal();

  /// Always returns false — SMS permission is no longer requested.
  Future<bool> hasPermission() async => false;

  /// No-op — SMS permission is no longer requested.
  Future<bool> requestPermission() async {
    debugPrint('[SmsTransactionService] SMS scanning is disabled. Use notification listener instead.');
    return false;
  }

  /// No-op — returns 0.
  Future<int> scanAllSms({Function(int, int)? onProgress}) async {
    debugPrint('[SmsTransactionService] SMS scanning is disabled.');
    return 0;
  }

  /// No-op — returns 0.
  Future<int> scanHistoricSms({
    required DateTime fromDate,
    DateTime? toDate,
    Function(int, int)? onProgress,
  }) async {
    debugPrint('[SmsTransactionService] Historic SMS scanning is disabled.');
    return 0;
  }

  /// Returns empty stats.
  Future<Map<String, dynamic>> getScanStats() async {
    return {
      'total': 0,
      'last_date': null,
      'scan_count': 0,
    };
  }
}
