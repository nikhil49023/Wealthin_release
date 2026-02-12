import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/data_service.dart';
import '../../core/services/database_helper.dart';
import '../../core/theme/wealthin_theme.dart';

/// Enhanced Brainstorming Screen with Chat + Canvas Interface
/// Psychology Framework: Input (Chat) → Refinery (Critique) → Anchor (Canvas)
class EnhancedBrainstormScreen extends StatefulWidget {
  const EnhancedBrainstormScreen({super.key});

  @override
  State<EnhancedBrainstormScreen> createState() =>
      _EnhancedBrainstormScreenState();
}

class _EnhancedBrainstormScreenState extends State<EnhancedBrainstormScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Session state
  int? _currentSessionId;
  String _sessionTitle = 'New Brainstorm Session';
  String _currentPersona = 'neutral';
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _canvasItems = [];
  bool _isLoading = false;
  bool _isCritiqueMode = false;
  String _activeWorkflowMode = 'input';
  String _activeIdeasMode = 'market_research';
  List<Map<String, dynamic>> _ideasModes = const [
    {
      'id': 'financial_planner',
      'label': 'Financial Planner',
      'description': 'Cashflow and tax-aware planning',
    },
    {
      'id': 'market_research',
      'label': 'Market Research',
      'description': 'Demand, competition, and viability',
    },
    {
      'id': 'career_advisor',
      'label': 'Career Advisor',
      'description': 'CV critique and role-fit strategy',
    },
    {
      'id': 'investment_analyst',
      'label': 'Investment Analyst',
      'description': 'Risk-return and allocation insights',
    },
    {
      'id': 'life_planning',
      'label': 'Life Planning',
      'description': 'Goals, milestones, and timelines',
    },
  ];
  Map<String, dynamic>? _lastVisualization;
  bool _isGeneratingDpr = false;

  // Personas (Thinking Hats)
  final Map<String, Map<String, dynamic>> _personas = {
    'neutral': {
      'name': 'Neutral Consultant',
      'icon': Icons.psychology,
      'color': Colors.blue,
      'description': 'Balanced, practical advice',
    },
    'cynical_vc': {
      'name': 'Cynical VC',
      'icon': Icons.trending_down,
      'color': Colors.red,
      'description': 'Find every way this could fail',
    },
    'enthusiastic_entrepreneur': {
      'name': 'Creative Entrepreneur',
      'icon': Icons.lightbulb,
      'color': Colors.amber,
      'description': 'See opportunities everywhere',
    },
    'risk_manager': {
      'name': 'Risk Manager',
      'icon': Icons.shield,
      'color': Colors.orange,
      'description': 'Legal & financial safety',
    },
    'customer_advocate': {
      'name': 'Customer Advocate',
      'icon': Icons.people,
      'color': Colors.purple,
      'description': 'User-centric perspective',
    },
    'financial_analyst': {
      'name': 'Financial Analyst',
      'icon': Icons.calculate,
      'color': Colors.green,
      'description': 'Run the numbers',
    },
    'systems_thinker': {
      'name': 'Systems Thinker',
      'icon': Icons.account_tree,
      'color': Colors.teal,
      'description': 'Big picture ecosystem view',
    },
  };

  final Map<String, Map<String, dynamic>> _workflowModes = const {
    'input': {
      'label': 'INPUT: Explore Ideas',
      'subtitle': 'Expand and structure raw thoughts',
      'icon': Icons.chat_bubble_outline,
      'color': Colors.blue,
    },
    'refinery': {
      'label': 'REFINERY: Stress Test',
      'subtitle': 'Challenge assumptions and find weak links',
      'icon': Icons.psychology,
      'color': Colors.red,
    },
    'anchor': {
      'label': 'ANCHOR: Capture Survivors',
      'subtitle': 'Pin strongest ideas to canvas',
      'icon': Icons.push_pin,
      'color': Colors.teal,
    },
  };

  final List<String> _starterPrompts = const [
    'Validate this business idea for Indian market demand',
    'What are the top 3 risks and how do I mitigate them?',
    'Propose an MVP scope and first-week action plan',
  ];

  IconData _modeIcon(String modeId) {
    switch (modeId) {
      case 'financial_planner':
        return Icons.account_balance_wallet_outlined;
      case 'career_advisor':
        return Icons.badge_outlined;
      case 'investment_analyst':
        return Icons.show_chart;
      case 'life_planning':
        return Icons.route_outlined;
      default:
        return Icons.insights_outlined;
    }
  }

  Color _modeColor(String modeId) {
    switch (modeId) {
      case 'financial_planner':
        return Colors.green;
      case 'career_advisor':
        return Colors.indigo;
      case 'investment_analyst':
        return Colors.deepPurple;
      case 'life_planning':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String _modeLabel(String modeId) {
    final mode = _ideasModes.firstWhere(
      (m) => (m['id']?.toString() ?? '') == modeId,
      orElse: () => const {'label': 'Market Research'},
    );
    return mode['label']?.toString() ?? 'Market Research';
  }

  // UI state
  bool _isCanvasVisible = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Android-first: start with chat view
    _isCanvasVisible = !(_isMobileLayout);
    _loadOrCreateSession();
    _loadIdeasModes();
    _showProTipOnFirstLaunch();
  }

  // Helper to check if we're on a mobile-sized screen
  bool get _isMobileLayout {
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = window.physicalSize.width / window.devicePixelRatio;
    return width < 600;
  }

  Future<void> _showProTipOnFirstLaunch() async {
    // Check if user has seen the pro-tip before
    final prefs = await SharedPreferences.getInstance();
    final hasSeenProTip = prefs.getBool('brainstorm_protip_shown') ?? false;

    if (!hasSeenProTip && mounted) {
      // Wait a bit for UI to settle
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text('💡 PRO-TIP'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Use REFINE when you want a strict, investor-style critique.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('• Finds weak assumptions quickly'),
                  Text('• Highlights financial and execution risks'),
                  Text('• Suggests stronger alternatives'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  prefs.setBool('brainstorm_protip_shown', true);
                  Navigator.pop(context);
                },
                child: const Text('Got it! 🚀'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrCreateSession() async {
    // Load most recent session or create new one
    final sessions = await _dbHelper.getBrainstormSessions();
    if (sessions.isNotEmpty && sessions.first['is_archived'] == 0) {
      final session = sessions.first;
      _currentSessionId = session['id'] as int;
      _sessionTitle = session['title'] as String;
      _currentPersona = session['persona'] as String? ?? 'neutral';

      // Load messages and canvas items
      final messages = await _dbHelper.getBrainstormMessages(
        _currentSessionId!,
      );
      final canvasItems = await _dbHelper.getCanvasItems(_currentSessionId!);

      setState(() {
        _messages = messages;
        _canvasItems = canvasItems;
      });
    } else {
      // Create new session
      await _createNewSession();
    }
  }

  Future<void> _loadIdeasModes() async {
    try {
      final modes = await _dataService.getBrainstormModes();
      if (!mounted || modes.isEmpty) return;

      final normalized = modes
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => (m['id']?.toString().isNotEmpty ?? false))
          .toList();
      if (normalized.isEmpty) return;

      setState(() {
        _ideasModes = normalized;
        final exists = _ideasModes.any(
          (m) => (m['id']?.toString() ?? '') == _activeIdeasMode,
        );
        if (!exists) {
          _activeIdeasMode = _ideasModes.first['id']?.toString() ?? 'market_research';
        }
      });
    } catch (e) {
      debugPrint('[Brainstorm] Failed to load modes: $e');
    }
  }

  Future<void> _createNewSession() async {
    final sessionId = await _dbHelper.createBrainstormSession(
      'Brainstorm ${DateTime.now().day}/${DateTime.now().month}',
      persona: _currentPersona,
    );

    setState(() {
      _currentSessionId = sessionId;
      _sessionTitle =
          'Brainstorm ${DateTime.now().day}/${DateTime.now().month}';
      _messages = [];
      _canvasItems = [];
      _lastVisualization = null;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentSessionId == null) return;

    setState(() {
      _isLoading = true;
      _isCritiqueMode = false;
      _activeWorkflowMode = 'input';
    });

    // Add user message to DB and UI
    await _dbHelper.addBrainstormMessage(
      sessionId: _currentSessionId!,
      role: 'user',
      content: message,
    );

    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
        'persona': null,
        'is_critique': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Call backend with persona
      final response = await _dataService.brainstormChat(
        userId: 'user_1',
        message: message,
        conversationHistory: _messages
            .map(
              (m) => {
                'role': m['role'],
                'content': m['content'],
              },
            )
            .toList(),
        persona: _currentPersona,
        mode: _activeIdeasMode,
        workflowMode: 'input',
      );

      if (response['success'] == true) {
        // Add assistant message to DB and UI
        await _dbHelper.addBrainstormMessage(
          sessionId: _currentSessionId!,
          role: 'assistant',
          content: response['content'],
          persona: _currentPersona,
          isCritique: _isCritiqueMode,
        );

        setState(() {
          _lastVisualization = response['visualization'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(response['visualization'])
              : null;
          _messages.add({
            'role': 'assistant',
            'content': response['content'],
            'persona': _currentPersona,
            'is_critique': _isCritiqueMode ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
            'sources': response['sources'],
            'mode': response['mode'] ?? _activeIdeasMode,
          });
        });

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[Brainstorm] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runCritique() async {
    if (_messages.isEmpty || _currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start brainstorming first before critiquing!'),
        ),
      );
      return;
    }

    // PRO-TIP: Automatically switch to Cynical VC for brutal critique
    setState(() {
      _currentPersona = 'cynical_vc';
      _isLoading = true;
      _isCritiqueMode = true;
      _activeWorkflowMode = 'refinery';
    });

    // Show visual feedback about persona switch
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _personas['cynical_vc']!['icon'] as IconData,
                color: _personas['cynical_vc']!['color'] as Color,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '💡 PRO-TIP: Switched to Cynical VC for brutal honesty',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: (_personas['cynical_vc']!['color'] as Color)
              .withOpacity(0.9),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      // Extract user ideas from chat
      final userIdeas = _messages
          .where((m) => m['role'] == 'user')
          .map((m) => m['content'] as String)
          .toList();

      final response = await _dataService.reverseBrainstorm(
        ideas: userIdeas,
        conversationHistory: _messages
            .map(
              (m) => {
                'role': m['role'],
                'content': m['content'],
              },
            )
            .toList(),
        mode: _activeIdeasMode,
      );

      if (response['success'] == true) {
        // Add critique to DB and UI
        await _dbHelper.addBrainstormMessage(
          sessionId: _currentSessionId!,
          role: 'assistant',
          content: response['critique'],
          persona: 'cynical_vc',
          isCritique: true,
        );

        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response['critique'],
            'persona': 'cynical_vc',
            'is_critique': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        });

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[Critique] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Critique error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isCritiqueMode = false;
        // Keep Cynical VC active - user can manually switch back if desired
        // This reinforces the "critique mindset" for follow-up questions
      });

      // Show completion message with next step hint
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ Critique complete!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Review the weaknesses, then click ANCHOR to save survivors.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _extractToCanvas() async {
    if (_messages.isEmpty || _currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to extract from!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeWorkflowMode = 'anchor';
    });

    try {
      final response = await _dataService.extractCanvasItems(
        conversationHistory: _messages
            .map(
              (m) => {
                'role': m['role'],
                'content': m['content'],
              },
            )
            .toList(),
        mode: _activeIdeasMode,
      );

      if (response['success'] == true && response['ideas'] != null) {
        final ideas = response['ideas'] as List;

        // Add to canvas items in DB
        for (var idea in ideas) {
          final colorHex = _getCategoryColor(idea['category']).toARGB32();
          await _dbHelper.addCanvasItem(
            sessionId: _currentSessionId!,
            title: idea['title'],
            content: idea['content'],
            category: idea['category'],
            colorHex: colorHex,
          );
        }

        // Reload canvas items
        final canvasItems = await _dbHelper.getCanvasItems(_currentSessionId!);
        setState(() {
          _canvasItems = canvasItems;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extracted ${ideas.length} ideas to canvas!')),
        );
      }
    } catch (e) {
      debugPrint('[Extract Canvas] Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extract error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateDprFromCanvas({
    List<Map<String, dynamic>>? canvasItems,
  }) async {
    final sourceItems = canvasItems ?? _canvasItems;
    if (sourceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anchor ideas to canvas before generating DPR')),
      );
      return;
    }

    setState(() => _isGeneratingDpr = true);
    try {
      final response = await _dataService.generateDprFromCanvas(
        userId: 'user_1',
        canvasItems: sourceItems
            .map(
              (item) => {
                'id': item['id'],
                'title': item['title'],
                'content': item['content'],
                'category': item['category'],
              },
            )
            .toList(),
        userData: {
          'persona': _currentPersona,
          'mode': _activeIdeasMode,
          'session_title': _sessionTitle,
        },
        mode: _activeIdeasMode,
        businessIdea: sourceItems.first['title']?.toString(),
      );

      if (response['success'] == true || response['status'] == 'success') {
        await _showDprPreview(response);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DPR generation failed: ${response['error'] ?? 'Unknown error'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('DPR generation error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingDpr = false);
      }
    }
  }

  Future<void> _showDprPreview(Map<String, dynamic> result) async {
    final dpr = result['dpr'];
    final modelUsed = result['model_used']?.toString();
    String preview;

    try {
      preview = const JsonEncoder.withIndent('  ').convert(dpr);
    } catch (_) {
      preview = dpr?.toString() ?? 'No DPR content returned.';
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Generated DPR Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (modelUsed != null && modelUsed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Model: $modelUsed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        preview,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'feature':
        return Colors.blue;
      case 'risk':
        return Colors.red;
      case 'opportunity':
        return Colors.green;
      case 'insight':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E0F) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ideas'),
        backgroundColor: WealthInColors.primary,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(_modeIcon(_activeIdeasMode), color: Colors.white),
            tooltip: 'Ideas mode',
            onSelected: (modeId) {
              setState(() {
                _activeIdeasMode = modeId;
                _lastVisualization = null;
              });
            },
            itemBuilder: (context) => _ideasModes.map((mode) {
              final id = mode['id']?.toString() ?? 'market_research';
              final label = mode['label']?.toString() ?? id;
              final description = mode['description']?.toString() ?? '';
              final selected = id == _activeIdeasMode;
              return PopupMenuItem<String>(
                value: id,
                child: Row(
                  children: [
                    Icon(
                      _modeIcon(id),
                      color: selected ? _modeColor(id) : null,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          // Persona selector
          PopupMenuButton<String>(
            icon: Icon(
              _personas[_currentPersona]!['icon'] as IconData,
              color: Colors.white,
            ),
            onSelected: (persona) {
              setState(() => _currentPersona = persona);
              if (_currentSessionId != null) {
                _dbHelper.updateBrainstormSession(
                  _currentSessionId!,
                  persona: persona,
                );
              }
            },
            itemBuilder: (context) => _personas.entries.map((entry) {
              return PopupMenuItem(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(
                      entry.value['icon'] as IconData,
                      color: entry.value['color'] as Color,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          entry.value['description'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          // New session button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewSession,
            tooltip: 'New Session',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            // MOBILE: Show one panel at a time with toggle FAB
            return Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: _isCanvasVisible
                                  ? const Offset(0.1, 0)
                                  : const Offset(-0.1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  child: _isCanvasVisible
                      ? KeyedSubtree(
                          key: const ValueKey('canvas'),
                          child: _buildCanvasPanel(isDark),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('chat'),
                          child: _buildChatPanel(isDark),
                        ),
                ),
                // Toggle FAB
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FloatingActionButton.small(
                      heroTag: 'brainstorm_toggle',
                      backgroundColor: _isCanvasVisible
                          ? WealthInColors.primary
                          : const Color(0xFF2D9CDB),
                      onPressed: () {
                        setState(() => _isCanvasVisible = !_isCanvasVisible);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isCanvasVisible
                              ? Icons.chat_bubble_outline
                              : Icons.dashboard_customize,
                          key: ValueKey(_isCanvasVisible),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // DESKTOP/TABLET: Side-by-side layout
          return Row(
            children: [
              // CHAT SIDE (Left)
              Expanded(
                flex: _isCanvasVisible ? 1 : 2,
                child: _buildChatPanel(isDark),
              ),

              // CANVAS SIDE (Right)
              if (_isCanvasVisible)
                Expanded(
                  flex: 1,
                  child: _buildCanvasPanel(isDark),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatPanel(bool isDark) {
    final modeMeta =
        _workflowModes[_activeWorkflowMode] ?? _workflowModes['input']!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12171A) : Colors.white,
        border: Border(
          right: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _modeIcon(_activeIdeasMode),
                      color: _modeColor(_activeIdeasMode),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ideas • ${_modeLabel(_activeIdeasMode)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _modeColor(_activeIdeasMode),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            modeMeta['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isCritiqueMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: const Text(
                          'Refine active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _runCritique,
                      icon: const Icon(Icons.content_cut, size: 16),
                      label: const Text('Refine'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _extractToCanvas,
                      icon: const Icon(Icons.push_pin_outlined, size: 16),
                      label: const Text('Anchor'),
                    ),
                  ],
                ),
                if (_lastVisualization != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ((_lastVisualization?['score_label']?.toString() ?? '')
                            .isNotEmpty)
                          _buildVizChip(
                            _lastVisualization!['score_label'].toString(),
                            Icons.insights,
                            isDark,
                          ),
                        ...((_lastVisualization?['metrics'] is List)
                            ? (_lastVisualization!['metrics'] as List)
                                .take(3)
                                .map(
                                  (metric) => _buildVizChip(
                                    metric.toString(),
                                    Icons.circle,
                                    isDark,
                                    tinyDot: true,
                                  ),
                                )
                                .toList()
                            : const <Widget>[]),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index], isDark);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        WealthInColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Thinking...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F23) : Colors.grey[100],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _activeWorkflowMode == 'refinery'
                              ? 'Ask for stricter critique, assumptions, and failure points...'
                              : _activeWorkflowMode == 'anchor'
                              ? 'Ask what should be pinned to canvas as key decisions...'
                              : 'Type your raw thoughts here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                        ),
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: const Icon(Icons.send),
                      color: WealthInColors.primary,
                    ),
                  ],
                ),
                if (_messages.isEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _starterPrompts.map((prompt) {
                      return ActionChip(
                        label: Text(
                          prompt,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          _messageController.text = prompt;
                          _messageController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _messageController.text.length,
                                ),
                              );
                          setState(() => _activeWorkflowMode = 'input');
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPanel(bool isDark) {
    final showItemCount = MediaQuery.of(context).size.width > 460;
    return Container(
      color: isDark ? const Color(0xFF0F1419) : const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Canvas header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_customize,
                          color: WealthInColors.cyanGlow,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Canvas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!compact && showItemCount)
                          Text(
                            '${_canvasItems.length} items',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (compact && showItemCount)
                          Text(
                            '${_canvasItems.length} items',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ElevatedButton.icon(
                          onPressed: (_isGeneratingDpr || _canvasItems.isEmpty)
                              ? null
                              : () => _generateDprFromCanvas(),
                          icon: _isGeneratingDpr
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.description_outlined, size: 14),
                          label: const Text(
                            'Generate DPR',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            backgroundColor: WealthInColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Canvas items
          Expanded(
            child: _canvasItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 64,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No ideas pinned yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click ANCHOR to extract survivors',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _canvasItems.length,
                    itemBuilder: (context, index) {
                      return _buildCanvasCard(_canvasItems[index], isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVizChip(
    String text,
    IconData icon,
    bool isDark, {
    bool tinyDot = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tinyDot ? 9 : 12,
            color: tinyDot ? Colors.grey : WealthInColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            text.replaceAll('_', ' '),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark) {
    final isUser = message['role'] == 'user';
    final isCritique = (message['is_critique'] ?? 0) == 1;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 700
              ? MediaQuery.of(context).size.width * 0.82
              : MediaQuery.of(context).size.width * 0.4,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? WealthInColors.primary.withOpacity(0.2)
              : (isCritique
                    ? Colors.red.withOpacity(0.1)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[100])),
          borderRadius: BorderRadius.circular(12),
          border: isCritique ? Border.all(color: Colors.red, width: 2) : null,
          boxShadow: isCritique
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Critique warning banner
            if (isCritique)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'BRUTAL CRITIQUE MODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && message['persona'] != null)
              Row(
                children: [
                  Icon(
                    _personas[message['persona']]?['icon'] as IconData? ??
                        Icons.psychology,
                    size: 14,
                    color:
                        _personas[message['persona']]?['color'] as Color? ??
                        Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _personas[message['persona']]?['name'] ?? 'Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          _personas[message['persona']]?['color'] as Color? ??
                          Colors.blue,
                    ),
                  ),
                ],
              ),
            if (!isUser && message['persona'] != null)
              const SizedBox(height: 6),
            Text(
              message['content'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCritique ? FontWeight.w500 : FontWeight.normal,
                color: isCritique
                    ? Colors.red.shade900
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasCard(Map<String, dynamic> item, bool isDark) {
    final colorHex = item['color_hex'] as int?;
    final category = item['category'] as String? ?? 'idea';
    final cardColor = colorHex != null
        ? Color(colorHex)
        : _getCategoryColor(category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? cardColor.withOpacity(0.15)
            : cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cardColor,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.description_outlined, size: 16),
                tooltip: 'Generate DPR from this card',
                onPressed: _isGeneratingDpr
                    ? null
                    : () => _generateDprFromCanvas(canvasItems: [item]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () async {
                  await _dbHelper.deleteCanvasItem(item['id'] as int);
                  final canvasItems = await _dbHelper.getCanvasItems(
                    _currentSessionId!,
                  );
                  setState(() => _canvasItems = canvasItems);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? 'Untitled',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              item['content'] ?? '',
              style: const TextStyle(fontSize: 11),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _personas[_currentPersona]!['icon'] as IconData,
            size: 64,
            color: (_personas[_currentPersona]!['color'] as Color).withOpacity(
              0.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start brainstorming with ${_personas[_currentPersona]!['name']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _personas[_currentPersona]!['description'] as String,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            'Mode: ${_modeLabel(_activeIdeasMode)}',
            style: TextStyle(
              fontSize: 11,
              color: _modeColor(_activeIdeasMode),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Input → Refine → Anchor',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
