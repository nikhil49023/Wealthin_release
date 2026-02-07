import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/wealthin_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/backend_config.dart';
import 'core/services/sidecar_manager.dart';
import 'core/services/python_bridge_service.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/finance/finance_hub_screen.dart';
import 'features/ai_hub/ai_hub_screen.dart';
import 'features/profile/profile_screen.dart';
import 'core/services/ai_agent_service.dart';
import 'core/services/data_service.dart';


/// Global auth service for Supabase authentication
late final AuthService authService;


/// Global theme mode notifier
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

/// Global data service for convenience
final dataService = DataService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sguzpnegfmeuczgsmtgl.supabase.co',
    anonKey: 'sb_publishable_ee1UuOOs0ruoqtmdqbRCEg__ls-kja4',
  );

  // Initialize auth service
  authService = AuthService();

  // Initialize credit system
  await dataService.initCredits();
  debugPrint('[App] User Credits Initialized: ${dataService.userCredits.value}');

  // Initialize daily streak
  final streakData = await dataService.initStreak();
  debugPrint('[App] Daily Streak: ${streakData['current_streak']} days');

  // Initialize backend based on platform
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // On Android, use EMBEDDED Python via Chaquopy (no HTTP backend needed)
      debugPrint('[App] Initializing embedded Python backend...');
      final available = await pythonBridge.initialize();
      debugPrint(available
          ? '[App] ✓ Python backend initialized - Full embedded mode'
          : '[App] ⚠ Python unavailable - using Dart fallbacks');
      
      // No HTTP backend needed on Android - everything runs locally
      debugPrint('[App] Mode: Embedded Python (no external backend)');
    } else {
      // On desktop (Linux/Windows/macOS), try sidecar + HTTP backend
      debugPrint('[App] Starting Python backend sidecar...');
      final sidecarStarted = await sidecarManager.start();
      if (sidecarStarted) {
        debugPrint('[App] Sidecar started successfully');
      } else {
        debugPrint('[App] Sidecar failed - trying existing backend');
      }
      
      // Initialize HTTP backend connection for desktop
      backendConfig.initialize().then((connected) {
        debugPrint(connected
            ? '[Backend] Connected on port ${backendConfig.activePort}'
            : '[Backend] No HTTP backend - using local calculations');
      });
    }
  }

  // Initialize AI Agent Service with Cloud preference for LLM
  await aiAgentService.initialize();

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
