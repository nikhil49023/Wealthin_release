import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/services/database_helper.dart';
import 'package:wealthin_flutter/core/services/sms_transaction_service.dart';

/// Data Sources Screen - Configure SMS, Email, and Bank integrations
class DataSourcesScreen extends StatefulWidget {
  const DataSourcesScreen({super.key});

  @override
  State<DataSourcesScreen> createState() => _DataSourcesScreenState();
}

class _DataSourcesScreenState extends State<DataSourcesScreen> {
  bool _smsParsingEnabled = false;
  bool _emailParsingEnabled = false;
  bool _bankSyncEnabled = false;
  bool _isLoading = true;
  
  PermissionStatus? _smsPermissionStatus;
  DateTime? _lastSmsScanDate;
  int _totalSmsParsed = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Check SMS permission status
      _smsPermissionStatus = await Permission.sms.status;
      
      // Load from database
      final db = await DatabaseHelper().database;
      final settings = await db.query('app_settings', limit: 1);
      
      if (settings.isNotEmpty) {
        setState(() {
          _smsParsingEnabled = settings.first['sms_parsing_enabled'] == 1;
          _emailParsingEnabled = settings.first['email_parsing_enabled'] == 1;
          _bankSyncEnabled = settings.first['bank_sync_enabled'] == 1;
        });
      }
      
      // Load SMS parsing stats from SmsTransactionService
      final smsService = SmsTransactionService();
      final stats = await smsService.getScanStats();
      
      setState(() {
        _totalSmsParsed = stats['total'] as int;
        final lastScan = stats['last_date'];
        if (lastScan != null) {
          _lastSmsScanDate = DateTime.parse(lastScan as String);
        }
      });
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data source settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSmsParsingEnabled(bool value) async {
    if (value) {
      // Request permission first
      final status = await Permission.sms.request();
      
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission is required for automatic transaction detection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      setState(() {
        _smsPermissionStatus = status;
        _smsParsingEnabled = true;
      });
      
      // Start initial SMS scan
      _scanSmsTransactions();
    } else {
      setState(() => _smsParsingEnabled = false);
    }
    
    // Save to database
    await _saveSetting('sms_parsing_enabled', value ? 1 : 0);
  }

  Future<void> _scanSmsTransactions() async {
    final smsService = SmsTransactionService();
    
    // Check permission first
    if (!await smsService.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    int scanned = 0;
    int total = 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  total > 0
                      ? 'Scanning SMS for transactions...\n$scanned / $total messages'
                      : 'Scanning SMS for transactions...',
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a minute',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      // Scan all SMS
      final transactionsFound = await smsService.scanAllSms(
        onProgress: (processed, totalMessages) {
          scanned = processed;
          total = totalMessages;
        },
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('SMS scan completed! Found $transactionsFound new transactions'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        await _loadSettings(); // Refresh stats
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

                  // SMS Parsing Card
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _smsParsingEnabled,
                          onChanged: _toggleSmsParsingEnabled,
                          title: const Row(
                            children: [
                              Icon(Icons.sms, color: AppTheme.emerald),
                              SizedBox(width: 12),
                              Text('SMS Transaction Detection'),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(left: 36, top: 4),
                            child: Text(
                              'Automatically detect bank transactions from SMS',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        if (_smsParsingEnabled) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.message,
                                        label: 'SMS Parsed',
                                        value: _totalSmsParsed.toString(),
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.schedule,
                                        label: 'Last Scan',
                                        value: _lastSmsScanDate != null
                                            ? _formatDate(_lastSmsScanDate!)
                                            : 'Never',
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _scanSmsTransactions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Scan SMS Now'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
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
                                'All data is processed locally on your device. SMS and email parsing happens entirely offline without sending data to external servers.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
