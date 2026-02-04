import 'package:flutter/material.dart';
import '../ai_advisor/chat_screen.dart';
import '../brainstorm/brainstorm_screen.dart';

/// AI Hub - Consolidated screen for all AI-powered features
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_AiTab> _tabs = const [
    _AiTab(
      label: 'Advisor',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    _AiTab(
      label: 'Brainstorm',
      icon: Icons.lightbulb_outline,
      selectedIcon: Icons.lightbulb,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(tab.label),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // AI Advisor tab - Chat with invoice generation
          ChatScreen(),
          // Brainstorm tab
          BrainstormScreenBody(),
        ],
      ),
    );
  }
}

class _AiTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _AiTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
