import 'package:flutter/material.dart';
// TODO: Firebase migration - removed wealthin_client import
// import 'package:wealthin_client/wealthin_client.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/providers/locale_provider.dart';
import 'package:wealthin_flutter/core/services/python_bridge_service.dart';
import 'package:wealthin_flutter/main.dart' show themeModeNotifier, authService;

import '../finance/finance_hub_screen.dart';

/// Profile Screen - User settings and gamification
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock user data - TODO: Replace with Auth
  String _userName = 'Nikhil';
  final String _userEmail = 'nikhil@wealthin.app';
  int _credits = 0;
  bool _isLoading = true;
  
  final List<_CreditTransaction> _creditHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // TODO: Firebase migration - replace with Firebase Auth and Firestore
    try {
      // Use real user data if available via Auth
      if (authService.currentUser != null) {
        final user = authService.currentUser!;
        final metadata = user.userMetadata;
        _userName = metadata?['display_name'] ?? metadata?['full_name'] ?? 'User';
        // _userEmail is final, so we can't update it easily here without removing final or using setState aggressively differently
        // But the error was about displayName getter.
      }

      // Mock profile data
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _credits = 25; // Mock credits
        _isLoading = false;

        // Mock history for now
        if (_creditHistory.isEmpty) {
          _creditHistory.addAll([
            _CreditTransaction(
              description: 'Account Created',
              amount: 5,
              date: DateTime.now().subtract(const Duration(days: 30)),
            ),
            _CreditTransaction(
              description: 'First Budget Created',
              amount: 10,
              date: DateTime.now().subtract(const Duration(days: 20)),
            ),
            _CreditTransaction(
              description: 'Weekly Check-in',
              amount: 10,
              date: DateTime.now().subtract(const Duration(days: 7)),
            ),
          ]);
        }
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              _userName[0].toUpperCase(),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _userEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showEditProfileDialog(context),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credits Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.navy,
                                      AppTheme.navyLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.stars,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WealthIn Credits',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Earn rewards for good habits!',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_credits',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.navy,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Recent Rewards',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          ..._creditHistory
                              .take(3)
                              .map((tx) => _CreditHistoryTile(transaction: tx)),
                          TextButton(
                            onPressed: () => _showCreditHistory(context),
                            child: const Text('View All History'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Management Quick Links
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Financial Management',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FinancialLinkTile(
                            icon: Icons.pie_chart_rounded,
                            iconColor: AppTheme.secondary,
                            title: 'Budgets',
                            subtitle: 'Track spending by category',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FinanceHubScreen(initialTabIndex: 1),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _FinancialLinkTile(
                            icon: Icons.flag_rounded,
                            iconColor: AppTheme.incomeGreen,
                            title: 'Savings Goals',
                            subtitle: 'Track progress towards goals',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FinanceHubScreen(initialTabIndex: 2),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _FinancialLinkTile(
                            icon: Icons.event_note_rounded,
                            iconColor: const Color(0xFF2DD4BF), // Teal
                            title: 'Scheduled Payments',
                            subtitle: 'Manage recurring bills',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FinanceHubScreen(initialTabIndex: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Settings
                  Card(
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.dark_mode,
                          title: 'Dark Mode',
                          trailing: ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeModeNotifier,
                            builder: (context, themeMode, _) {
                              return Switch(
                                value: themeMode == ThemeMode.dark,
                                onChanged: (value) {
                                  themeModeNotifier.value = value
                                      ? ThemeMode.dark
                                      : ThemeMode.light;
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.language,
                          title: 'Language',
                          trailing: DropdownButton<String>(
                            value: LocaleService.instance.languageCode,
                            underline: const SizedBox(),
                            items: AppLocales.supportedLocales.map((locale) {
                              return DropdownMenuItem(
                                value: locale.languageCode,
                                child: Text(
                                  AppLocales.getLocaleName(locale.languageCode),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                LocaleService.instance.setLocaleByCode(value);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),

                        _SettingsTile(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notification settings coming soon!',
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.security,
                          title: 'Privacy & Security',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Privacy settings coming soon!'),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.help,
                          title: 'Help & Support',
                          onTap: () {
                            _showHelpDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System Health Card
                  const _SystemHealthCard(),
                  const SizedBox(height: 16),

                  // About
                  Card(
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.info,
                          title: 'About WealthIn',
                          onTap: () => _showAboutDialog(context),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.description,
                          title: 'Terms of Service',
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),


                  Text(
                    'WealthIn v2.0.0 (Flutter)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _userName = nameController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated!')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCreditHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      Text(
                        'Credit History',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total: $_credits',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _creditHistory.length,
                      itemBuilder: (context, index) {
                        return _CreditHistoryTile(
                          transaction: _creditHistory[index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement Serverpod sign out
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseRed,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help),
              SizedBox(width: 8),
              Text('Help & Support'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email Support'),
                subtitle: const Text('support@wealthin.app'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Live Chat'),
                subtitle: const Text('Available 9 AM - 6 PM IST'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('FAQs'),
                subtitle: const Text('Common questions answered'),
                onTap: () {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'WealthIn',
      applicationVersion: '2.0.0 (Flutter)',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.account_balance_wallet,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'WealthIn is your sovereign-first, local-first personal finance companion. '
          'Built with Flutter for a native experience and powered by AI for smart insights.',
        ),
        const SizedBox(height: 16),
        const Text(
          '© 2026 WealthIn. All rights reserved.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _CreditTransaction {
  final String description;
  final int amount;
  final DateTime date;

  _CreditTransaction({
    required this.description,
    required this.amount,
    required this.date,
  });
}

class _CreditHistoryTile extends StatelessWidget {
  final _CreditTransaction transaction;

  const _CreditHistoryTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.stars, color: AppTheme.navy),
      ),
      title: Text(transaction.description),
      subtitle: Text(_formatDate(transaction.date)),
      trailing: Text(
        '+${transaction.amount}',
        style: TextStyle(
          color: AppTheme.incomeGreen,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

class _FinancialLinkTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FinancialLinkTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}

/// System Health Card - Shows AI Engine status
class _SystemHealthCard extends StatefulWidget {
  const _SystemHealthCard();

  @override
  State<_SystemHealthCard> createState() => _SystemHealthCardState();
}

class _SystemHealthCardState extends State<_SystemHealthCard> {
  SystemHealth? _health;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    final health = await PythonBridgeService().checkSystemHealth();
    if (mounted) {
      setState(() {
        _health = health;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Health',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isLoading && _health != null)
                        Text(
                          _health!.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getStatusColor(),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _checkHealth();
                    },
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            if (!_isLoading && _health != null) ...[
              const Divider(height: 24),
              _HealthComponentTile(
                name: 'Python Engine',
                isReady: _health!.components['python'] ?? false,
              ),
              _HealthComponentTile(
                name: 'Sarvam AI',
                isReady: _health!.components['sarvam'] ?? false,
              ),
              _HealthComponentTile(
                name: 'PDF Parser',
                isReady: _health!.components['pdf_parser'] ?? false,
              ),
              _HealthComponentTile(
                name: 'AI Tools',
                isReady: _health!.components['tools'] ?? false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (_isLoading) return Icons.hourglass_empty;
    switch (_health?.status) {
      case SystemHealthStatus.ready:
        return Icons.check_circle;
      case SystemHealthStatus.initializing:
        return Icons.hourglass_top;
      case SystemHealthStatus.unavailable:
        return Icons.cloud_off;
      case SystemHealthStatus.error:
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor() {
    if (_isLoading) return Colors.grey;
    switch (_health?.status) {
      case SystemHealthStatus.ready:
        return AppTheme.incomeGreen;
      case SystemHealthStatus.initializing:
        return Colors.orange;
      case SystemHealthStatus.unavailable:
        return Colors.grey;
      case SystemHealthStatus.error:
        return AppTheme.expenseRed;
      default:
        return Colors.grey;
    }
  }
}

class _HealthComponentTile extends StatelessWidget {
  final String name;
  final bool isReady;

  const _HealthComponentTile({
    required this.name,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 18,
            color: isReady ? AppTheme.incomeGreen : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            isReady ? 'Ready' : 'Not Available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isReady ? AppTheme.incomeGreen : Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}
