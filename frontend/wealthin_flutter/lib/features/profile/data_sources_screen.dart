import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/services/database_helper.dart';
import 'package:wealthin_flutter/core/services/notification_transaction_service.dart';

/// Data Sources Screen - Configure notification, email, and bank integrations
class DataSourcesScreen extends StatefulWidget {
  const DataSourcesScreen({super.key});

  @override
  State<DataSourcesScreen> createState() => _DataSourcesScreenState();
}

class _DataSourcesScreenState extends State<DataSourcesScreen>
    with WidgetsBindingObserver {
  bool _notificationParsingEnabled = false;
  bool _emailParsingEnabled = false;
  bool _bankSyncEnabled = false;
  bool _isLoading = true;

  bool _listenerEnabled = false;
  DateTime? _lastScanDate;
  int _totalParsed = 0;

  final _notifService = NotificationTransactionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check listener status when user returns from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshListenerStatus();
    }
  }

  Future<void> _refreshListenerStatus() async {
    final enabled = await _notifService.isListenerEnabled();
    if (mounted && enabled != _listenerEnabled) {
      setState(() => _listenerEnabled = enabled);

      // If user just turned it on, start listening and save setting
      if (enabled && !_notificationParsingEnabled) {
        setState(() => _notificationParsingEnabled = true);
        await _saveSetting('notification_parsing_enabled', 1);
        _notifService.startListening();
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      _listenerEnabled = await _notifService.isListenerEnabled();

      // Load from database (defensive — table may not exist on older DBs)
      try {
        final db = await DatabaseHelper().database;
        final settings = await db.query(
          'app_settings',
          where: 'key IN (?, ?, ?, ?)',
          whereArgs: [
            'notification_parsing_enabled',
            'sms_parsing_enabled',    // backward compat read
            'email_parsing_enabled',
            'bank_sync_enabled',
          ],
        );

        for (final row in settings) {
          final key = row['key'] as String?;
          final value = row['value']?.toString();
          if (key == 'notification_parsing_enabled') {
            _notificationParsingEnabled = value == '1';
          } else if (key == 'sms_parsing_enabled' &&
              !_notificationParsingEnabled) {
            // Migrate old key: treat old "sms_parsing_enabled" as notification
            _notificationParsingEnabled = value == '1';
          } else if (key == 'email_parsing_enabled') {
            _emailParsingEnabled = value == '1';
          } else if (key == 'bank_sync_enabled') {
            _bankSyncEnabled = value == '1';
          }
        }
      } catch (e) {
        debugPrint('Error loading app_settings (table may not exist yet): $e');
      }

      // Load detection stats
      try {
        final stats = await _notifService.getScanStats();
        _totalParsed = (stats['total'] as int?) ?? 0;
        final lastDate = stats['last_date'];
        if (lastDate != null && lastDate.toString().isNotEmpty) {
          _lastScanDate = DateTime.tryParse(lastDate.toString());
        }
      } catch (e) {
        debugPrint('Error loading stats: $e');
      }

      // Auto-start listener if enabled
      if (_notificationParsingEnabled && _listenerEnabled) {
        _notifService.startListening();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data source settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotificationParsing(bool value) async {
    if (value) {
      if (!_listenerEnabled) {
        // Guide user to Settings
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange),
                  SizedBox(width: 12),
                  Flexible(child: Text('Enable Notification Access')),
                ],
              ),
              content: const Text(
                'To automatically detect bank transactions, Wealthin needs notification access.\n\n'
                '1. Tap "Open Settings" below\n'
                '2. Find "Wealthin" in the list\n'
                '3. Toggle it ON\n'
                '4. Come back to this screen\n\n'
                'This is NOT an SMS permission — only notification content is read.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await _notifService.openListenerSettings();
            // Status will be re-checked in didChangeAppLifecycleState
          }
        }
        return;
      }

      setState(() => _notificationParsingEnabled = true);
      _notifService.startListening();
    } else {
      setState(() => _notificationParsingEnabled = false);
      _notifService.stopListening();
    }

    await _saveSetting('notification_parsing_enabled', value ? 1 : 0);
  }

  Future<void> _saveSetting(String key, int value) async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'app_settings',
        {
          'key': key,
          'value': value.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic Transaction Detection',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable automatic detection of financial transactions from various sources',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Notification Parsing Card ──────────────────────
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _notificationParsingEnabled,
                          onChanged: _toggleNotificationParsing,
                          title: const Row(
                            children: [
                              Icon(Icons.notifications_active,
                                  color: AppTheme.emerald),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text('Bank Notification Detection'),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(left: 36, top: 4),
                            child: Text(
                              'Automatically detect transactions from banking app notifications',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        if (_notificationParsingEnabled) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Listener status banner
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _listenerEnabled
                                        ? AppTheme.emerald.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _listenerEnabled
                                            ? Icons.check_circle
                                            : Icons.warning_amber,
                                        color: _listenerEnabled
                                            ? AppTheme.emerald
                                            : Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _listenerEnabled
                                              ? 'Notification access active — transactions will be detected automatically'
                                              : 'Notification access not granted — tap below to enable',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_listenerEnabled) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _notifService.openListenerSettings(),
                                    icon: const Icon(Icons.settings),
                                    label:
                                        const Text('Open Notification Settings'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.notifications,
                                        label: 'Transactions Detected',
                                        value: _totalParsed.toString(),
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.schedule,
                                        label: 'Last Detected',
                                        value: _lastScanDate != null
                                            ? _formatDate(_lastScanDate!)
                                            : 'Waiting…',
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Parsing Card (Coming Soon)
                  Card(
                    child: Opacity(
                      opacity: 0.6,
                      child: SwitchListTile(
                        value: _emailParsingEnabled,
                        onChanged: null, // Disabled for now
                        title: const Row(
                          children: [
                            Icon(Icons.email, color: AppTheme.secondary),
                            SizedBox(width: 12),
                            Text('Email Transaction Detection'),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 36, top: 4),
                          child: Row(
                            children: [
                              Text(
                                'Extract transactions from email statements',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'COMING SOON',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.navy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bank Sync Card (Coming Soon)
                  Card(
                    child: Opacity(
                      opacity: 0.6,
                      child: SwitchListTile(
                        value: _bankSyncEnabled,
                        onChanged: null, // Disabled for now
                        title: const Row(
                          children: [
                            Icon(Icons.account_balance, color: AppTheme.navy),
                            SizedBox(width: 12),
                            Text('Direct Bank Sync'),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 36, top: 4),
                          child: Row(
                            children: [
                              Text(
                                'Connect directly to your bank account',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'COMING SOON',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.navy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.emerald,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Privacy & Security',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.emerald,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All data is processed locally on your device. '
                                'Notification content is parsed entirely offline '
                                'without sending data to external servers. '
                                'No SMS permission is required.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
