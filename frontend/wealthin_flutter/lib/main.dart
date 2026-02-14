import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/python_bridge_service.dart';
import 'core/services/startup_permissions_service.dart';
import 'core/services/contact_service.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/splash/splash_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/finance/finance_hub_screen.dart';
import 'features/ai_hub/ai_hub_screen.dart';
import 'features/brainstorm/enhanced_brainstorm_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/services/ai_agent_service.dart';
import 'core/services/data_service.dart';
import 'core/config/secrets.dart';
import 'core/utils/responsive_utils.dart';
import 'features/analysis/analysis_screen.dart';

/// Global auth service for Supabase authentication
late final AuthService authService;

/// Global theme mode notifier
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
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

  await _initializeSupabase();

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

Future<void> _initializeSupabase() async {
  try {
    await Supabase.initialize(
      url: 'https://sguzpnegfmeuczgsmtgl.supabase.co',
      anonKey: 'sb_publishable_ee1UuOOs0ruoqtmdqbRCEg__ls-kja4',
    ).timeout(const Duration(seconds: 8));
  } on TimeoutException {
    debugPrint('[App] ⚠ Supabase initialization timed out.');
  } catch (error, stackTrace) {
    debugPrint('[App] ⚠ Supabase initialization failed: $error');
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

  await _runStartupTask('AI agent service', () async {
    await aiAgentService.initialize();
  });

  // Load contacts in background (non-blocking)
  await _runStartupTask('contacts', () async {
    final contactService = ContactService();
    final hasPermission = await contactService.hasPermission();
    if (hasPermission) {
      await contactService.loadContacts();
      debugPrint('[App] Contacts loaded: ${contactService.cacheSize} entries');
    } else {
      debugPrint('[App] Contacts permission not granted');
    }
  });
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
  bool _showOnboarding = false;
  bool _checkingOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    var onboardingComplete = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    } catch (error) {
      debugPrint('[App] Failed to read onboarding status: $error');
    }

    if (mounted) {
      setState(() {
        _showOnboarding = !onboardingComplete;
        _checkingOnboarding = false;
      });
    }
  }

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  void _onOnboardingComplete() {
    if (!mounted) return;
    setState(() => _showOnboarding = false);
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

    // Still checking onboarding status
    if (_checkingOnboarding) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show onboarding for first-time users
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

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
    EnhancedBrainstormScreen(),
    // ProfileScreen removed - accessible from dashboard header
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
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                    label: Text('Finance'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: Text('AI'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.analytics_outlined),
                    selectedIcon: Icon(Icons.analytics_rounded),
                    label: Text('Analysis'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.lightbulb_outline),
                    selectedIcon: Icon(Icons.lightbulb_rounded),
                    label: Text('Ideas'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildAnimatedBody()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _buildAnimatedBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'Ideas',
          ),
        ],
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
              begin: const Offset(0.1, 0),
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
