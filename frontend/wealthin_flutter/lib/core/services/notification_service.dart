import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight Notification Service
/// Provides in-app notifications for budget alerts and daily reminders.
/// Note: For native push notifications, add flutter_local_notifications package.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  // In-app notification stream for UI consumption
  final ValueNotifier<NotificationData?> currentNotification = ValueNotifier(null);
  
  /// Show a budget alert notification
  void showBudgetAlert({
    required String category,
    required double percentage,
    required String message,
    required String alertLevel, // 'caution', 'warning', 'critical'
  }) {
    currentNotification.value = NotificationData(
      type: NotificationType.budgetAlert,
      title: 'Budget Alert: $category',
      message: message,
      alertLevel: alertLevel,
      timestamp: DateTime.now(),
    );
    
    debugPrint('[Notification] Budget alert: $message');
  }
  
  /// Show a daily reminder notification (called from app lifecycle)
  Future<void> checkDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReminderDate = prefs.getString('last_reminder_date');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Only show once per day
    if (lastReminderDate != today) {
      await prefs.setString('last_reminder_date', today);
      
      currentNotification.value = NotificationData(
        type: NotificationType.dailyReminder,
        title: 'Daily Check-in 🔥',
        message: 'Keep your streak alive! Log your transactions today.',
        alertLevel: 'info',
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Clear the current notification
  void dismissNotification() {
    currentNotification.value = null;
  }
  
  /// Schedule daily reminder time (stored preference)
  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', time.hour);
    await prefs.setInt('reminder_minute', time.minute);
    debugPrint('[Notification] Reminder time set to ${time.hour}:${time.minute}');
  }
  
  /// Get scheduled reminder time
  Future<TimeOfDay?> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('reminder_hour');
    final minute = prefs.getInt('reminder_minute');
    
    if (hour != null && minute != null) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }
}

/// Notification types
enum NotificationType {
  budgetAlert,
  dailyReminder,
  goalProgress,
  achievement,
}

/// Notification data model
class NotificationData {
  final NotificationType type;
  final String title;
  final String message;
  final String alertLevel; // 'info', 'caution', 'warning', 'critical'
  final DateTime timestamp;
  
  NotificationData({
    required this.type,
    required this.title,
    required this.message,
    required this.alertLevel,
    required this.timestamp,
  });
  
  Color get color {
    switch (alertLevel) {
      case 'critical':
        return const Color(0xFFE53935); // Red
      case 'warning':
        return const Color(0xFFFFA726); // Orange
      case 'caution':
        return const Color(0xFFFFEB3B); // Yellow
      default:
        return const Color(0xFF42A5F5); // Blue
    }
  }
  
  IconData get icon {
    switch (type) {
      case NotificationType.budgetAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.dailyReminder:
        return Icons.local_fire_department;
      case NotificationType.goalProgress:
        return Icons.flag;
      case NotificationType.achievement:
        return Icons.emoji_events;
    }
  }
}

/// Global singleton instance
final notificationService = NotificationService();
