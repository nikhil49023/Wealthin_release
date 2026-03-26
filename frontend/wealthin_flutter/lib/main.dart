import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/widgets/wealthin_logo.dart';
import 'core/services/python_bridge_service.dart';
import 'core/services/startup_permissions_service.dart';

import 'features/auth/auth_wrapper.dart';
import 'features/splash/splash_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/finance/finance_hub_screen.dart';
import 'features/ai_hub/ai_hub_screen.dart';
import 'core/services/hybrid_ai_service.dart';
import 'core/services/data_service.dart';
import 'core/config/secrets.dart';
import 'core/utils/responsive_utils.dart';
import 'features/analysis/analysis_screen_redesign.dart';
import 'features/profile/profile_screen.dart';

/// Global auth service for Firebase authentication
late final AuthService authService;

/// Global theme mode notifier — AMOLED dark by default
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.dark,
);

/// Global data service for convenience
final dataService = DataService();
const Duration _deferredStartupDelay = Duration(milliseconds: 1200);
bool _hasInitializedDeferredServices = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error boundary - catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
    // TODO: Send to analytics/backend logging
  };

  // Catch errors outside Flutter (async errors, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Platform Error: $error');
    debugPrint('Stack trace: $stack');
    // TODO: Send to analytics/backend logging
    return true;
  };

  await _initializeFirebase();

  // Initialize auth service
  authService = AuthService();

  runApp(const WealthInApp());

  // Schedule non-critical startup work after the first frame.
  _scheduleDeferredServicesInitialization();
}

void _scheduleDeferredServicesInitialization() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>.delayed(_deferredStartupDelay, () async {
        if (_hasInitializedDeferredServices) return;
        _hasInitializedDeferredServices = true;
        await _initializeDeferredServices();
      }),
    );
  });
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    debugPrint('[App] ✓ Firebase initialized');
  } on TimeoutException {
    debugPrint('[App] ⚠ Firebase initialization timed out.');
  } catch (error, stackTrace) {
    debugPrint('[App] ⚠ Firebase initialization failed: $error');
    debugPrint('$stackTrace');
  }
}

Future<void> _initializeDeferredServices() async {
  final dataTasks = Future.wait<void>([
    _runStartupTask('credits', () async {
      await dataService.initCredits();
      debugPrint(
        '[App] User Credits Initialized: ${dataService.userCredits.value}',
      );
    }),
    _runStartupTask('daily streak', () async {
      final streakData = await dataService.initStreak();
      debugPrint('[App] Daily Streak: ${streakData['current_streak']} days');
    }),
  ]);

  final secureStorageTask = _runStartupTask('secure storage', () async {
    await AppSecrets.initialize();
    debugPrint('[App] Secure storage initialized');
    if (AppSecrets.isUsingDefaultKeys) {
      debugPrint(
        '[App] Warning: Using default API keys. Configure in Settings for production.',
      );
    }
  });

  final pythonTask = _runStartupTask('python backend', () async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('[App] Initializing embedded Python backend...');
      final available = await pythonBridge.initialize();
      debugPrint(
        available
            ? '[App] ✓ Python backend initialized (embedded mode)'
            : '[App] ⚠ Python unavailable - using Dart fallbacks',
      );
      return;
    }

    debugPrint(
      '[App] Android-only runtime: skipping non-Android backend setup.',
    );
  });

  await Future.wait<void>([dataTasks, secureStorageTask, pythonTask]);

  await _runStartupTask('Hybrid AI service (Sarvam)', () async {
    await hybridAI.initialize();
  });

  debugPrint('[App] ✓ All startup services initialized');
}

Future<void> _runStartupTask(
  String taskName,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await task().timeout(timeout);
  } on TimeoutException {
    debugPrint('[App] ⚠ Startup task timed out: $taskName');
  } catch (error, stackTrace) {
    debugPrint('[App] ⚠ Startup task failed: $taskName ($error)');
    debugPrint('$stackTrace');
  }
}

class WealthInApp extends StatefulWidget {
  const WealthInApp({super.key});

  @override
  State<WealthInApp> createState() => _WealthInAppState();
}

class _WealthInAppState extends State<WealthInApp> {
  bool _showSplash = true;

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Wealthin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final currentScale = mediaQuery.textScaler.scale(1.0);
            final clampedScale = currentScale.clamp(0.9, 1.15).toDouble();
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // AuthWrapper handles: Login → Onboarding (if needed) → Main App
    return const AuthWrapper(
      child: MainNavigationShell(),
    );
  }
}

/// Main navigation shell with bottom navigation
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    FinanceHubScreen(),
    AiHubScreen(),
    AnalysisScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Request permissions after a short delay (allow UI to settle)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        startupPermissions.requestStartupPermissions(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout =
        MediaQuery.of(context).size.width >= ResponsiveUtils.tabletBreakpoint;

    if (isWideLayout) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: _buildPremiumNavigationRail(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildAnimatedBody()),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: _buildAnimatedBody(),
      bottomNavigationBar: _buildGlassNavigationBar(),
    );
  }

  Widget _buildPremiumNavigationRail() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark ? AppTheme.richNavy : AppTheme.lightCard;
    final railBorder =
        isDark ? AppTheme.royalGold.withValues(alpha: 0.18) : AppTheme.lightBorder;

    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: railBg,
        border: Border(
          right: BorderSide(
            color: railBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const WealthInLogo(size: 44, showGlow: true),
          const SizedBox(height: 32),
          ..._buildRailItems(),
        ],
      ),
    );
  }

  List<Widget> _buildRailItems() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedText = isDark ? AppTheme.champagneGold : AppTheme.peacockTeal;
    final unselectedText = isDark ? AppTheme.silverMist : AppTheme.lightTextSecondary;

    final items = [
      _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
      _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Finance'),
      _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'AI'),
      _NavItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Analysis'),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return List.generate(items.length, (index) {
      final item = items[index];
      final isSelected = _selectedIndex == index;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.peacockTeal.withValues(alpha: 0.20) : null,
              border: isSelected ? Border.all(color: AppTheme.royalGold.withValues(alpha: 0.30), width: 1) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? selectedText : unselectedText,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? selectedText : unselectedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildGlassNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compactMode = screenWidth < 390;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppTheme.inkSlate : AppTheme.lightCard;
    final navBorder =
        isDark ? AppTheme.royalGold.withValues(alpha: 0.20) : AppTheme.lightBorder;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: navBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', compactMode),
            _buildNavItem(1, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Finance', compactMode),
            _buildNavItem(2, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'AI', compactMode),
            _buildNavItem(3, Icons.analytics_outlined, Icons.analytics_rounded, 'Analysis', compactMode),
            _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', compactMode),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    bool compactMode,
  ) {
    final isSelected = _selectedIndex == index;
    final showLabel = isSelected && !compactMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedText = isDark ? AppTheme.champagneGold : AppTheme.peacockTeal;
    final unselectedText = isDark ? AppTheme.silverMist : AppTheme.lightTextSecondary;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 12 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
            ? (isDark
              ? AppTheme.peacockTeal.withValues(alpha: 0.18)
              : AppTheme.peacockTeal.withValues(alpha: 0.12))
            : null,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
            ? Border.all(
              color: isDark
                ? AppTheme.royalGold.withValues(alpha: 0.30)
                : AppTheme.peacockTeal.withValues(alpha: 0.25),
              width: 1,
            )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? selectedText : unselectedText,
              size: compactMode ? 21 : 22,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: selectedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_selectedIndex),
        child: _screens[_selectedIndex],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavItem(this.icon, this.selectedIcon, this.label);
}
