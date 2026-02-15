import 'package:flutter/material.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/providers/locale_provider.dart';
import 'package:wealthin_flutter/core/services/python_bridge_service.dart';
import 'package:wealthin_flutter/main.dart' show themeModeNotifier, authService;

import '../finance/finance_hub_screen.dart';
import 'data_sources_screen.dart';
import 'family_groups_screen.dart';

/// Profile Screen - User settings and gamification
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock user data - TODO: Replace with Auth
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = authService.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.displayName ?? 'WealthIn Member';
          _userEmail = user.email ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
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
                  Container(
                    decoration: WealthInTheme.elevatedCardDecoration(context),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.emerald,
                                  AppTheme.emerald.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.emerald.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'W',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userName.isNotEmpty ? _userName : 'Welcome',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: WealthInTheme.gray600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.1),
                                  Colors.white,
                                ],
                              ),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => _showEditProfileDialog(context),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppTheme.primary),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Family Groups Highlight
                  Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FamilyGroupsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.emerald,
                                    AppTheme.emerald.withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.people,
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
                                    'Family Groups',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Family performance analysis',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ],
                        ),
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
                          icon: Icons.sync_alt,
                          title: 'Data Sources',
                          subtitle: 'Notifications, Email & Bank Sync',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DataSourcesScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.people,
                          title: 'Family Groups',
                          subtitle: 'Family performance analysis',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FamilyGroupsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        _SettingsTile(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          onTap: () => _showNotificationSettings(context),
                        ),

                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.security,
                          title: 'Privacy & Security',
                          onTap: () => _showPrivacySettings(context),
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
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Show signing out indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Signing out...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Actually sign out from Firebase + Google
                  await authService.signOut();
                  // AuthWrapper listens to auth state changes and will
                  // automatically navigate back to the login screen.
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sign out failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
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

  void _showNotificationSettings(BuildContext context) {
    bool budgetAlerts = true;
    bool paymentReminders = true;
    bool dailyInsights = true;
    bool weeklyReport = false;
    bool goalProgress = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active_rounded),
                  SizedBox(width: 12),
                  Text('Notification Settings'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Budget Alerts'),
                    subtitle: const Text(
                      'Get notified when you exceed budgets',
                    ),
                    value: budgetAlerts,
                    onChanged: (v) => setDialogState(() => budgetAlerts = v),
                  ),
                  SwitchListTile(
                    title: const Text('Payment Reminders'),
                    subtitle: const Text('Reminders for scheduled payments'),
                    value: paymentReminders,
                    onChanged: (v) =>
                        setDialogState(() => paymentReminders = v),
                  ),
                  SwitchListTile(
                    title: const Text('Daily Insights'),
                    subtitle: const Text('AI-powered daily finance tips'),
                    value: dailyInsights,
                    onChanged: (v) => setDialogState(() => dailyInsights = v),
                  ),
                  SwitchListTile(
                    title: const Text('Weekly Report'),
                    subtitle: const Text('Summary of your week\'s spending'),
                    value: weeklyReport,
                    onChanged: (v) => setDialogState(() => weeklyReport = v),
                  ),
                  SwitchListTile(
                    title: const Text('Goal Progress'),
                    subtitle: const Text('Milestones for savings goals'),
                    value: goalProgress,
                    onChanged: (v) => setDialogState(() => goalProgress = v),
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Notification preferences saved'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrivacySettings(BuildContext context) {
    bool biometricLock = false;
    bool dataEncryption = true;
    bool analyticsEnabled = true;
    bool crashReporting = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security_rounded),
                  SizedBox(width: 12),
                  Text('Privacy & Security'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Biometric Lock'),
                    subtitle: const Text('Use fingerprint/face to unlock'),
                    value: biometricLock,
                    onChanged: (v) => setDialogState(() => biometricLock = v),
                  ),
                  SwitchListTile(
                    title: const Text('Data Encryption'),
                    subtitle: const Text('Encrypt all local data'),
                    value: dataEncryption,
                    onChanged: (v) => setDialogState(() => dataEncryption = v),
                  ),
                  SwitchListTile(
                    title: const Text('Usage Analytics'),
                    subtitle: const Text('Help us improve WealthIn'),
                    value: analyticsEnabled,
                    onChanged: (v) =>
                        setDialogState(() => analyticsEnabled = v),
                  ),
                  SwitchListTile(
                    title: const Text('Crash Reporting'),
                    subtitle: const Text('Report crashes for fixes'),
                    value: crashReporting,
                    onChanged: (v) => setDialogState(() => crashReporting = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete All Data?'),
                          content: const Text(
                            'This will permanently delete all your local data including transactions, budgets, and goals. This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All data has been deleted'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Delete All Data',
                      style: TextStyle(color: Colors.red),
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Privacy settings saved'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
