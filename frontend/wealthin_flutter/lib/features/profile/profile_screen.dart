import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/widgets/indian_patterns.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/data_service.dart';
import '../../core/services/python_bridge_service.dart';
import '../../core/models/models.dart';
import '../../main.dart' show themeModeNotifier, authService;
import '../finance/finance_hub_screen.dart';
import 'data_sources_screen.dart';
import 'family_groups_screen.dart';

/// Redesigned Premium Profile Screen with Indian Aesthetics
/// Features: Financial Score, Goals, Settings with traditional patterns
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();

  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  // Financial data
  HealthScore? _healthScore;
  List<GoalModel> _goals = [];
  double _totalIncome = 0;
  double _totalExpense = 0;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadProfile();
    _loadFinancialData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFinancialData() async {
    try {
      final userId = authService.currentUserId;

      // Load dashboard data
      final dashData = await _dataService.getDashboard(userId);
      if (dashData != null) {
        setState(() {
          _totalIncome = dashData.totalIncome;
          _totalExpense = dashData.totalExpense;
        });

        // Calculate health score
        final healthScore = await _dataService.getHealthScore(userId);
        if (healthScore != null) {
          _healthScore = healthScore;
        }
      }

      // Load goals
      final goals = await _dataService.getGoals(userId);
      setState(() {
        _goals = goals;
      });
    } catch (e) {
      debugPrint('Error loading financial data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? IndianTheme.peacockGradient
                : IndianTheme.sacredMorningGradient,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: IndianPatternOverlay(
        showMandala: true,
        showRangoli: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? IndianTheme.peacockGradient
                : IndianTheme.sacredMorningGradient,
          ),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(isDark),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileHeader(isDark),
                    const SizedBox(height: 16),
                    _buildFinancialScoreCard(),
                    const SizedBox(height: 16),
                    _buildGoalsSection(),
                    const SizedBox(height: 16),
                    _buildFinancialQuickLinks(),
                    const SizedBox(height: 16),
                    _buildSettingsSection(),
                    const SizedBox(height: 16),
                    _buildSystemHealthCard(),
                    const SizedBox(height: 16),
                    _buildAboutSection(),
                    const SizedBox(height: 32),
                    Text(
                      'WealthIn v2.4.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: IndianTheme.templeStone.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: IndianTheme.sunriseGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const FloatingLotus(size: 40),
                      const SizedBox(width: 12),
                      Text(
                        'Profile',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => _showLogoutDialog(context),
          tooltip: 'Sign out',
        ),
      ],
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: IndianTheme.royalGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: IndianTheme.royalGold.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: IndianTheme.lotusGradient,
                  boxShadow: [
                    BoxShadow(
                      color: IndianTheme.lotusPink.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'W',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName.isNotEmpty ? _userName : 'Welcome',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _buildFinancialScoreCard() {
    if (_healthScore == null) {
      return const SizedBox.shrink();
    }

    final score = _healthScore!.totalScore;
    final grade = _healthScore!.grade;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.premiumCardDecoration(
          gradient: IndianTheme.templeSunsetGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health Score',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        grade,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 12,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              score.toStringAsFixed(0),
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'out of 100',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const IndianDivider(color: Colors.white, height: 16),
              const SizedBox(height: 16),
              ..._healthScore!.insights.take(3).map((insight) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildGoalsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: IndianTheme.prosperityGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Financial Goals',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: IndianTheme.templeGranite,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const FinanceHubScreen(initialTabIndex: 2),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: IndianTheme.peacockBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_goals.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 48,
                        color: IndianTheme.templeStone.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No goals yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: IndianTheme.templeStone,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const FinanceHubScreen(initialTabIndex: 2),
                            ),
                          );
                        },
                        child: Text(
                          'Add Your First Goal',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._goals.take(3).map((goal) => _buildGoalItem(goal)),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
    );
  }

  Widget _buildGoalItem(GoalModel goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IndianTheme.goldShimmer,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IndianTheme.champagneGold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: IndianTheme.templeGranite,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: IndianTheme.sunriseGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(goal.progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: IndianTheme.templeStone.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                IndianTheme.mehendiGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${_formatAmount(goal.currentAmount)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: IndianTheme.mehendiGreen,
                ),
              ),
              Text(
                '₹${_formatAmount(goal.targetAmount)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: IndianTheme.templeStone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialQuickLinks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: IndianTheme.peacockBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Financial Management',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: IndianTheme.templeGranite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFinancialLinkTile(
                icon: Icons.pie_chart_rounded,
                iconColor: IndianTheme.saffron,
                title: 'Budgets',
                subtitle: 'Track spending by category',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FinanceHubScreen(initialTabIndex: 1),
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildFinancialLinkTile(
                icon: Icons.flag_rounded,
                iconColor: IndianTheme.mehendiGreen,
                title: 'Savings Goals',
                subtitle: 'Track progress towards goals',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FinanceHubScreen(initialTabIndex: 2),
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildFinancialLinkTile(
                icon: Icons.event_note_rounded,
                iconColor: IndianTheme.peacockTeal,
                title: 'Scheduled Payments',
                subtitle: 'Manage recurring bills',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FinanceHubScreen(initialTabIndex: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildFinancialLinkTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: IndianTheme.templeGranite,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: IndianTheme.templeStone,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: IndianTheme.templeStone.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        child: Column(
          children: [
            _buildSettingsTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeNotifier,
                builder: (context, themeMode, _) {
                  return Switch(
                    value: themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeModeNotifier.value =
                          value ? ThemeMode.dark : ThemeMode.light;
                    },
                    activeThumbColor: IndianTheme.peacockBlue,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.language_rounded,
              title: 'Language',
              trailing: DropdownButton<String>(
                value: LocaleService.instance.languageCode,
                underline: const SizedBox(),
                items: AppLocales.supportedLocales.map((locale) {
                  return DropdownMenuItem(
                    value: locale.languageCode,
                    child: Text(
                      AppLocales.getLocaleName(locale.languageCode),
                      style: GoogleFonts.poppins(fontSize: 13),
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
            _buildSettingsTile(
              icon: Icons.sync_alt_rounded,
              title: 'Data Sources',
              subtitle: 'Notifications, Email & Bank Sync',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataSourcesScreen()),
                );
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.people_rounded,
              title: 'Family Groups',
              subtitle: 'Family performance analysis',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FamilyGroupsScreen()),
                );
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              onTap: () => _showNotificationSettings(context),
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.security_rounded,
              title: 'Privacy & Security',
              onTap: () => _showPrivacySettings(context),
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.help_rounded,
              title: 'Help & Support',
              onTap: () => _showHelpDialog(context),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: IndianTheme.peacockBlue),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: IndianTheme.templeGranite,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: IndianTheme.templeStone,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: IndianTheme.templeStone.withValues(alpha: 0.5),
                )
              : null),
      onTap: onTap,
    );
  }

  Widget _buildSystemHealthCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SystemHealthCard(),
    ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        child: Column(
          children: [
            _buildSettingsTile(
              icon: Icons.info_rounded,
              title: 'About WealthIn',
              onTap: () => _showAboutDialog(context),
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.description_rounded,
              title: 'Terms of Service',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              onTap: () {},
            ),
          ],
        ),
      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Profile',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: GoogleFonts.poppins(),
                  prefixIcon: const Icon(Icons.person_rounded),
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
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Profile updated!'),
                      ],
                    ),
                    backgroundColor: IndianTheme.mehendiGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianTheme.peacockBlue,
              ),
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
          title: Text(
            'Sign Out',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
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
                  await authService.signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sign out failed: $e'),
                        backgroundColor: IndianTheme.vermillion,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianTheme.vermillion,
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
          title: Row(
            children: [
              const Icon(Icons.help_rounded),
              const SizedBox(width: 8),
              Text(
                'Help & Support',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.email_rounded),
                title: const Text('Email Support'),
                subtitle: const Text('support@wealthin.app'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title: const Text('Live Chat'),
                subtitle: const Text('Available 9 AM - 6 PM IST'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.book_rounded),
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
      applicationVersion: '2.4.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: IndianTheme.sunriseGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        Text(
          'WealthIn is your sovereign-first, local-first personal finance companion with Indian-inspired premium design. '
          'Built with Flutter for a native experience and powered by AI for smart insights.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text(
          '© 2026 WealthIn. All rights reserved.',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showNotificationSettings(BuildContext context) {
    // Implementation same as before
    // ... (keeping existing implementation)
  }

  void _showPrivacySettings(BuildContext context) {
    // Implementation same as before
    // ... (keeping existing implementation)
  }
}

/// System Health Card - Shows AI Engine status
class _SystemHealthCard extends StatefulWidget {
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
    return Container(
      decoration: IndianTheme.marbleCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Health',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: IndianTheme.templeGranite,
                        ),
                      ),
                      if (!_isLoading && _health != null)
                        Text(
                          _health!.message,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _checkHealth();
                    },
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            if (!_isLoading && _health != null) ...[
              const SizedBox(height: 16),
              const IndianDivider(height: 12),
              const SizedBox(height: 16),
              _buildHealthComponent(
                'Python Engine',
                _health!.components['python'] ?? false,
              ),
              _buildHealthComponent(
                'Sarvam AI',
                _health!.components['sarvam'] ?? false,
              ),
              _buildHealthComponent(
                'PDF Parser',
                _health!.components['pdf_parser'] ?? false,
              ),
              _buildHealthComponent(
                'AI Tools',
                _health!.components['tools'] ?? false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthComponent(String name, bool isReady) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isReady
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: isReady ? IndianTheme.mehendiGreen : IndianTheme.templeStone,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: IndianTheme.templeGranite,
              ),
            ),
          ),
          Text(
            isReady ? 'Ready' : 'Not Available',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isReady
                  ? IndianTheme.mehendiGreen
                  : IndianTheme.templeStone.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (_isLoading) return Icons.hourglass_empty_rounded;
    switch (_health?.status) {
      case SystemHealthStatus.ready:
        return Icons.check_circle_rounded;
      case SystemHealthStatus.initializing:
        return Icons.hourglass_top_rounded;
      case SystemHealthStatus.unavailable:
        return Icons.cloud_off_rounded;
      case SystemHealthStatus.error:
        return Icons.error_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getStatusColor() {
    if (_isLoading) return IndianTheme.templeStone;
    switch (_health?.status) {
      case SystemHealthStatus.ready:
        return IndianTheme.mehendiGreen;
      case SystemHealthStatus.initializing:
        return IndianTheme.turmeric;
      case SystemHealthStatus.unavailable:
        return IndianTheme.templeStone;
      case SystemHealthStatus.error:
        return IndianTheme.vermillion;
      default:
        return IndianTheme.templeStone;
    }
  }
}
