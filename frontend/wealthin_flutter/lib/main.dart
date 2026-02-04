import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/wealthin_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/backend_config.dart';
import 'core/services/sidecar_manager.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/finance/finance_hub_screen.dart';
import 'features/ai_hub/ai_hub_screen.dart';
import 'features/profile/profile_screen.dart';
import 'core/services/ai_agent_service.dart';
import 'core/services/llm_inference_router.dart';

/// Global auth service for Firebase authentication
late final AuthService authService;

/// Whether Firebase is available on this platform
bool isFirebaseAvailable = false;

/// Global theme mode notifier
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (not available on Linux desktop)
  if (defaultTargetPlatform != TargetPlatform.linux) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseAvailable = true;
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      isFirebaseAvailable = false;
    }
  } else {
    debugPrint(
      'Running on Linux - Firebase not supported, using local-only mode',
    );
    isFirebaseAvailable = false;
  }

  // Initialize auth service
  authService = AuthService();

  // Start Python backend sidecar (desktop/mobile only, not web)
  if (!kIsWeb) {
    debugPrint('[App] Starting Python backend sidecar...');
    final sidecarStarted = await sidecarManager.start();
    if (sidecarStarted) {
      debugPrint('[App] Sidecar started successfully');
    } else {
      debugPrint('[App] Sidecar failed to start - will try to connect to existing backend');
    }
  }

  // Initialize backend connection (find active port)
  final connected = await backendConfig.initialize();
  debugPrint(
    connected
        ? '[Backend] Connected on port ${backendConfig.activePort}'
        : '[Backend] No backend found - some features may be limited',
  );

  // Initialize AI Agent Service with Cloud preference (Production Setup)
  await aiAgentService.initialize(
    preferredMode: InferenceMode.cloud,
    allowFallback: true,
  );

  runApp(const WealthInApp());
}

class WealthInApp extends StatelessWidget {
  const WealthInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'WealthIn',
          debugShowCheckedModeBanner: false,
          theme: WealthInTheme.lightTheme,
          darkTheme: WealthInTheme.darkTheme,
          themeMode: themeMode,
          home: const AuthWrapper(
            child: MainNavigationShell(),
          ),
        );
      },
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
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Desktop Layout with NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Finance'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome),
                      label: Text('AI Tools'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: Container(
                      key: ValueKey(_selectedIndex),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout with NavigationBar
          return Scaffold(
            body: AnimatedSwitcher(
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
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Finance',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'AI Tools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
