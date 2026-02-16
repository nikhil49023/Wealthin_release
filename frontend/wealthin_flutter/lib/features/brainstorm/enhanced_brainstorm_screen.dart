import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  String _activeIdeasMode = 'wealth_planner';
  List<Map<String, dynamic>> _ideasModes = const [
    {
      'id': 'wealth_planner',
      'label': 'Wealth Planner',
      'icon': '💰',
      'description': 'Smart budgets, investments, savings & financial growth',
    },
  ];
  Map<String, dynamic>? _lastVisualization;
  bool _isGeneratingDpr = false;

  // Location for Government API enrichment
  String? _userLocation;
  String? _userBusinessSector;
  bool _hasPromptedLocation = false;

  // Language preference for AI responses
  String _preferredLanguage = 'English';
  static const Map<String, String> _languageOptions = {
    'English': '🇬🇧',
    'Hindi': '🇮🇳',
    'Hinglish': '🗣️',
    'Tamil': '🏛️',
    'Telugu': '🌾',
    'Kannada': '🏞️',
    'Malayalam': '🌴',
    'Bengali': '🎭',
    'Marathi': '⛰️',
    'Gujarati': '🏭',
  };

  // Indian states list for location picker
  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana',
    'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan',
    'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Chandigarh', 'Puducherry', 'Jammu & Kashmir', 'Ladakh',
  ];

  // Personas (simplified to 3 essential perspectives)
  final Map<String, Map<String, dynamic>> _personas = {
    'neutral': {
      'name': 'Wealth Advisor',
      'icon': Icons.auto_awesome,
      'color': Colors.blue,
      'description': 'Balanced, practical financial advice',
    },
    'cynical_vc': {
      'name': 'Risk Analyst',
      'icon': Icons.shield_outlined,
      'color': Colors.red,
      'description': 'Find financial risks & gaps',
    },
    'financial_analyst': {
      'name': 'Investment Analyst',
      'icon': Icons.trending_up,
      'color': Colors.green,
      'description': 'Optimize returns & growth',
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
    '💰 Help me create a monthly savings plan',
    '📈 What are the best investment options for me?',
    '🏠 Plan my finances for buying a home',
    '📊 Analyze my spending and find savings',
    '🎯 Build an emergency fund strategy',
    '🌱 How can I start investing with ₹1,000/month?',
  ];

  // Wealth creation facts shown in empty state for encouragement
  static const List<String> _msmeFacts = [
    '🇮🇳 India\'s \$5T GDP vision requires 140Cr financially literate citizens — be one!',
    '💰 Starting a ₹5,000/month SIP at 25 can grow to ₹1 Crore by 50!',
    '📈 73% of Indians lack basic financial literacy (RBI, 2023) — WealthIn is changing that',
    '🌟 The Rule of 72: Divide 72 by your return rate to know when your money doubles',
    '🏆 Even ₹500/month invested consistently beats keeping money in a savings account by 3x',
    '📋 A solid budget frees up 20-30% more money than you think you have!',
  ];

  IconData _modeIcon(String modeId) {
    switch (modeId) {
      case 'wealth_planner':
        return Icons.auto_awesome;
      case 'financial_planner':
        return Icons.account_balance_wallet_outlined;
      case 'strategic_planner':
        return Icons.track_changes;
      case 'financial_architect':
        return Icons.architecture;
      case 'execution_coach':
        return Icons.rocket_launch;
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
      case 'wealth_planner':
        return Colors.deepPurple;
      case 'strategic_planner':
        return Colors.orange;
      case 'financial_architect':
        return Colors.green;
      case 'execution_coach':
        return Colors.blue;
      case 'financial_planner':
        return Colors.green;
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
      orElse: () => const {'label': 'Wealth Planner'},
    );
    return mode['label']?.toString() ?? 'Wealth Planner';
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
    _loadSavedLocation();
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

      if (mounted) {
        setState(() {
          _messages = messages.map((m) => Map<String, dynamic>.from(m)).toList();
          _canvasItems = canvasItems.map((c) => Map<String, dynamic>.from(c)).toList();
        });
      }
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
          _activeIdeasMode =
              _ideasModes.first['id']?.toString() ?? 'wealth_planner';
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

    if (!mounted) return;
    setState(() {
      _currentSessionId = sessionId;
      _sessionTitle =
          'Brainstorm ${DateTime.now().day}/${DateTime.now().month}';
      _messages = [];
      _canvasItems = [];
      _lastVisualization = null;
    });
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('ideas_user_location');
    final savedSector = prefs.getString('ideas_user_sector');
    if (mounted && savedLocation != null) {
      setState(() {
        _userLocation = savedLocation;
        _userBusinessSector = savedSector;
        _hasPromptedLocation = true;
      });
    }
  }

  Future<void> _saveLocation(String location, {String? sector}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ideas_user_location', location);
    if (sector != null) {
      await prefs.setString('ideas_user_sector', sector);
    }
    if (mounted) {
      setState(() {
        _userLocation = location;
        if (sector != null) _userBusinessSector = sector;
        _hasPromptedLocation = true;
      });
    }
  }

  Future<void> _showLocationPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.deepPurple, size: 28),
            SizedBox(width: 12),
            Text('\ud83d\udccd Your Location'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your state to get local financial data,\n'
                'supplier recommendations, and state-wise insights.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _indianStates.length,
                  itemBuilder: (context, index) {
                    final state = _indianStates[index];
                    final isSelected = state == _userLocation;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.deepPurple : Colors.grey,
                        size: 20,
                      ),
                      title: Text(
                        state,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurple : null,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(state),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _saveLocation(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\ud83d\udccd Location set to $result \u2014 AI will now personalize financial insights for your state!'),
            backgroundColor: Colors.deepPurple,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (_isLoading || message.isEmpty || _currentSessionId == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isCritiqueMode = false;
      // Keep current workflow mode - AI stays interactive in all modes
    });

    // Add user message to DB and UI
    await _dbHelper.addBrainstormMessage(
      sessionId: _currentSessionId!,
      role: 'user',
      content: message,
    );

    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'user',
          'content': message,
          'persona': null,
          'is_critique': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
    }

    _messageController.clear();
    _scrollToBottom();

    try {
      final userProfileHint = await _buildUserProfileHint(message);

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
        workflowMode: _activeWorkflowMode,
        userProfile: {
          ...userProfileHint,
          'preferred_language': _preferredLanguage,
        },
        userLocation: _userLocation,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _buildUserProfileHint(String message) async {
    final lower = message.toLowerCase();
    final profile = <String, dynamic>{};

    if (lower.contains('expand') ||
        lower.contains('expansion') ||
        lower.contains('existing business') ||
        lower.contains('scale')) {
      profile['business_stage'] = 'expansion';
    } else if (lower.contains('start') ||
        lower.contains('startup') ||
        lower.contains('new venture') ||
        lower.contains('launch')) {
      profile['business_stage'] = 'startup';
    }

    if (lower.contains('rural') || lower.contains('village')) {
      profile['location_type'] = 'rural';
    } else if (lower.contains('urban') || lower.contains('city')) {
      profile['location_type'] = 'urban';
    }

    // Inject aggregated financial context from local DB
    try {
      final now = DateTime.now();
      final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final summary = await _dbHelper.getTransactionSummary(startDate: monthStart);
      if (summary != null) {
        final income = (summary['total_income'] as num?)?.toDouble() ?? 0;
        final expenses = (summary['total_expenses'] as num?)?.toDouble() ?? 0;
        if (income > 0 || expenses > 0) {
          profile['monthly_income'] = income;
          profile['monthly_expenses'] = expenses;
          profile['savings_rate'] = income > 0
              ? '${(((income - expenses) / income) * 100).toStringAsFixed(1)}%'
              : 'N/A';
        }
      }
      // Top spending categories
      final categories = await _dbHelper.getCategoryBreakdown(startDate: monthStart);
      if (categories.isNotEmpty) {
        final sorted = categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        profile['top_spending'] = sorted.take(5).map(
          (e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}',
        ).toList();
      }
    } catch (e) {
      debugPrint('[Brainstorm] Could not load financial context: $e');
    }

    // Include saved location for state-wise financial data enrichment
    if (_userLocation != null) {
      profile['location'] = _userLocation!;
      profile['state'] = _userLocation!;
    }
    if (_userBusinessSector != null) {
      profile['business_sector'] = _userBusinessSector!;
    }

    return profile;
  }

  Future<void> _runCritique() async {
    if (_isLoading) return;
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
              .withValues(alpha: 0.9),
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
    if (_isLoading) return;
    if (_messages.isEmpty || _currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to extract from!')),
      );
      return;
    }

    if (!mounted) return;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateDprFromCanvas({
    List<Map<String, dynamic>>? canvasItems,
  }) async {
    if (_isGeneratingDpr) return;
    final sourceItems = canvasItems ?? _canvasItems;
    if (sourceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anchor ideas to canvas before generating DPR'),
        ),
      );
      return;
    }

    if (!mounted) return;
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
        SnackBar(
          content: Text(
            'DPR generation failed: ${response['error'] ?? 'Unknown error'}',
          ),
        ),
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

    // Extract sections from the DPR structure
    List<Map<String, dynamic>> sections = [];
    Map<String, dynamic> metadata = {};

    if (dpr is Map<String, dynamic>) {
      metadata = (dpr['metadata'] as Map<String, dynamic>?) ?? {};
      final rawSections = dpr['sections'];
      if (rawSections is List) {
        for (final s in rawSections) {
          if (s is Map<String, dynamic>) {
            sections.add(Map<String, dynamic>.from(s));
          }
        }
      }
      // If no sections key, treat the top-level keys as sections
      if (sections.isEmpty) {
        for (final entry in dpr.entries) {
          if (entry.key == 'metadata') continue;
          if (entry.value is Map) {
            sections.add({
              'title': entry.key.replaceAll('_', ' ').toUpperCase(),
              'content': Map<String, dynamic>.from(entry.value as Map),
            });
          } else if (entry.value is String) {
            sections.add({
              'title': entry.key.replaceAll('_', ' ').toUpperCase(),
              'content': {'text': entry.value},
            });
          }
        }
      }
    }

    if (!mounted) return;

    // Navigate to full-screen document editor
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DprDocumentEditor(
          sections: sections,
          metadata: metadata,
          modelUsed: modelUsed,
          sessionTitle: _sessionTitle,
        ),
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ideas'),
        backgroundColor: isDark
            ? theme.appBarTheme.backgroundColor
            : theme.colorScheme.primary,
        foregroundColor: isDark ? null : Colors.white,
        actions: [
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
          // Language selector (text only, no icons)
          PopupMenuButton<String>(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                _preferredLanguage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
            tooltip: 'Response Language',
            onSelected: (lang) => setState(() => _preferredLanguage = lang),
            itemBuilder: (context) => _languageOptions.keys.map((lang) {
              final isActive = _preferredLanguage == lang;
              return PopupMenuItem(
                value: lang,
                child: Row(
                  children: [
                    Text(
                      lang,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? WealthInColors.primary : null,
                      ),
                    ),
                    if (isActive) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 16, color: WealthInColors.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          // Location selector for Gov API enrichment
          IconButton(
            icon: _userLocation != null
                ? const Icon(Icons.location_on, color: Colors.amberAccent)
                : const Icon(Icons.location_off_outlined),
            onPressed: _showLocationPicker,
            tooltip: _userLocation != null
                ? 'Location: $_userLocation'
                : 'Set your state for local data',
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
    final theme = Theme.of(context);
    final modeMeta =
        _workflowModes[_activeWorkflowMode] ?? _workflowModes['input']!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Compact chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _modeIcon(_activeIdeasMode),
                  color: _modeColor(_activeIdeasMode),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ideas • ${_modeLabel(_activeIdeasMode)} ${modeMeta['label']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _modeColor(_activeIdeasMode),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isCritiqueMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Refining',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                  ),
                if (_messages.isNotEmpty) ...[
                  _buildCompactActionBtn(
                    icon: Icons.psychology,
                    tooltip: 'Stress Test',
                    color: Colors.red,
                    isActive: _isCritiqueMode,
                    onTap: _isLoading ? null : _runCritique,
                  ),
                  const SizedBox(width: 4),
                  _buildCompactActionBtn(
                    icon: Icons.push_pin,
                    tooltip: 'Save Ideas',
                    color: Colors.teal,
                    isActive: _activeWorkflowMode == 'anchor',
                    onTap: _isLoading ? null : _extractToCanvas,
                  ),
                ],
              ],
            ),
          ),

          // Messages list — full space for reading
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index], isDark);
                    },
                  ),
          ),

          // Loading indicator with varied messages
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  Text(
                    _activeWorkflowMode == 'refinery'
                        ? '🔬 Stress-testing your idea...'
                        : _activeWorkflowMode == 'anchor'
                            ? '📌 Extracting best ideas...'
                            : '🧠 Researching & thinking...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom > 0 ? 4 : 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F23) : Colors.grey[100],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location prompt (only when empty and not prompted)
                  if (_userLocation == null && !_hasPromptedLocation && _messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: _showLocationPicker,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tips_and_updates, size: 14, color: Colors.amber),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Set your state for local financial insights',
                                  style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 10, color: Colors.amber),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Location chip (compact, above input)
                  if (_userLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: _showLocationPicker,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Colors.deepPurple),
                                const SizedBox(width: 3),
                                Text(
                                  _userLocation!.length > 12 ? '${_userLocation!.substring(0, 12)}...' : _userLocation!,
                                  style: const TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: _messages.isEmpty
                                ? 'Share your business idea...'
                                : 'Ask a follow-up...',
                            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            isDense: true,
                          ),
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: WealthInColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : _sendMessage,
                          icon: Icon(
                            Icons.arrow_upward_rounded,
                            color: _isLoading ? Colors.grey : Colors.white,
                            size: 20,
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                    ],
                  ),
                  if (_messages.isEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemCount: _starterPrompts.length,
                        itemBuilder: (context, index) {
                          final prompt = _starterPrompts[index];
                          return ActionChip(
                            label: Text(prompt, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: () {
                              _messageController.text = prompt;
                              _messageController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _messageController.text.length),
                              );
                              setState(() => _activeWorkflowMode = 'input');
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
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
                              : const Icon(
                                  Icons.description_outlined,
                                  size: 14,
                                ),
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

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.5)
                : (isDark ? Colors.white12 : Colors.black12),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isActive ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : Colors.grey,
              ),
            ),
          ],
        ),
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

  // Compact action button for header
  Widget _buildCompactActionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: isActive ? color : Colors.grey),
        ),
      ),
    );
  }

  /// Convert markdown tables to mobile-friendly card layouts.
  /// Each table row becomes a compact card with "Header: Value" pairs,
  /// which is far more readable on narrow mobile screens than squished columns.
  String _convertTablesForMobile(String markdown) {
    final lines = markdown.split('\n');
    final result = <String>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      // Detect start of a markdown table (line starts with |)
      if (line.startsWith('|') && line.endsWith('|')) {
        // Collect all contiguous table lines
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }

        if (tableLines.length >= 3) {
          // Parse header row
          final headers = tableLines[0]
              .split('|')
              .map((h) => h.trim())
              .where((h) => h.isNotEmpty)
              .toList();

          // Skip separator row (index 1), process data rows
          for (int r = 2; r < tableLines.length; r++) {
            final cells = tableLines[r]
                .split('|')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();

            if (cells.isEmpty) continue;

            // Build a card for this row
            result.add(''); // blank line before card
            // Use first column value as the card title if it looks like a label
            if (headers.isNotEmpty && cells.isNotEmpty) {
              result.add('> **${cells[0]}**');
              for (int c = 1; c < cells.length && c < headers.length; c++) {
                result.add('> • ${headers[c]}: ${cells[c]}');
              }
            }
          }
          result.add(''); // blank line after cards
        } else {
          // Not enough rows — keep as-is
          result.addAll(tableLines);
        }
      } else {
        result.add(lines[i]);
        i++;
      }
    }

    return result.join('\n');
  }

  /// Sanitize AI response — remove unnecessary characters and clean formatting
  String _sanitizeAIResponseForIdeas(String text) {
    text = text.replaceAll(RegExp(r'^(?:Final Answer[:\s]*|Answer[:\s]*)', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\n(?:Final Answer[:\s]*|Answer[:\s]*)', caseSensitive: false), '\n');
    text = text.replaceAll('***', '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'^\*\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'```json[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll('`', '');
    text = text.replaceAll(RegExp(r'^Here (?:is|are) (?:the|your|my) (?:response|answer)[:\.]?\s*', caseSensitive: false), '');
    return text.trim();
  }

  /// Check if line is a section header (surrounded by **)
  bool _isSectionHeaderIdeas(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('**') && trimmed.endsWith('**') && 
           trimmed.length > 4 && !trimmed.substring(2, trimmed.length - 2).contains('**');
  }

  /// Extract header text from **header**
  String _extractHeaderTextIdeas(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return trimmed.substring(2, trimmed.length - 2).trim();
    }
    return trimmed;
  }

  /// Get contextual icon for section headers
  IconData _getSectionIconIdeas(String header) {
    final h = header.toLowerCase();
    if (h.contains('roadmap') || h.contains('step') || h.contains('plan') || h.contains('improvement')) return Icons.route_outlined;
    if (h.contains('vendor') || h.contains('platform') || h.contains('provider') || h.contains('supplier')) return Icons.storefront_outlined;
    if (h.contains('scheme') || h.contains('government') || h.contains('yojana') || h.contains('subsidy')) return Icons.account_balance_outlined;
    if (h.contains('invest') || h.contains('mutual') || h.contains('sip') || h.contains('fund')) return Icons.trending_up_outlined;
    if (h.contains('saving') || h.contains('budget') || h.contains('cost')) return Icons.savings_outlined;
    if (h.contains('insurance') || h.contains('policy')) return Icons.health_and_safety_outlined;
    if (h.contains('tax') || h.contains('deduction') || h.contains('gst')) return Icons.receipt_long_outlined;
    if (h.contains('loan') || h.contains('emi') || h.contains('credit') || h.contains('funding')) return Icons.credit_score_outlined;
    if (h.contains('tip') || h.contains('advice') || h.contains('suggest') || h.contains('recommend')) return Icons.lightbulb_outline;
    if (h.contains('warning') || h.contains('risk') || h.contains('caution') || h.contains('challenge')) return Icons.warning_amber_outlined;
    if (h.contains('benefit') || h.contains('advantage') || h.contains('pro') || h.contains('opportunity')) return Icons.star_outline;
    if (h.contains('how') || h.contains('process') || h.contains('apply') || h.contains('registration')) return Icons.checklist_outlined;
    if (h.contains('score') || h.contains('projection') || h.contains('target') || h.contains('revenue')) return Icons.analytics_outlined;
    if (h.contains('msme') || h.contains('local') || h.contains('enterprise') || h.contains('business')) return Icons.store_outlined;
    if (h.contains('market') || h.contains('analysis') || h.contains('research')) return Icons.pie_chart_outline;
    if (h.contains('summary') || h.contains('overview') || h.contains('conclusion')) return Icons.assessment_outlined;
    if (h.contains('supply') || h.contains('chain') || h.contains('logistics')) return Icons.local_shipping_outlined;
    if (h.contains('customer') || h.contains('user') || h.contains('audience')) return Icons.people_outline;
    if (h.contains('product') || h.contains('service') || h.contains('offering')) return Icons.inventory_2_outlined;
    if (h.contains('partner') || h.contains('collaboration') || h.contains('network')) return Icons.handshake_outlined;
    return Icons.label_outline;
  }

  /// Premium section header with gradient background and icon
  Widget _buildSectionHeaderIdeas(String text, bool isDark, Color accent, bool hasTopPadding) {
    final icon = _getSectionIconIdeas(text);
    return Padding(
      padding: EdgeInsets.only(top: hasTopPadding ? 14 : 0, bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: isDark ? 0.15 : 0.08),
              accent.withValues(alpha: 0.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Emerald dot bullet point
  Widget _buildBulletPointIdeas(String text, Color baseColor, Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFormattedTextIdeas(text, baseColor, isDark),
          ),
        ],
      ),
    );
  }

  /// Tip / callout box
  Widget _buildTipCalloutIdeas(String text, bool isDark, Color accent) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.12 : 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: isDark ? 0.3 : 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, size: 16,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFormattedTextIdeas(text, baseColor, isDark),
          ),
        ],
      ),
    );
  }

  /// Highlight card for key metric lines
  Widget _buildHighlightCardIdeas(String text, bool isDark, Color accent) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.12 : 0.06),
            accent.withValues(alpha: isDark ? 0.04 : 0.02),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFormattedTextIdeas(
              text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1'),
              baseColor,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Check if a line is a highlight-worthy metric
  bool _isHighlightLineIdeas(String line) {
    final hasAmount = line.contains('₹');
    final hasScore = RegExp(r'\d+/100|score|target|projection|revenue|profit|loss', caseSensitive: false).hasMatch(line);
    return hasAmount && hasScore && !line.startsWith('•') && !line.startsWith('-');
  }

  /// Visual roadmap card with timeline for numbered steps
  Widget _buildRoadmapCardIdeas(List<String> steps, bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (i) {
          final isLast = i == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline column
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 2),
                    child: _buildFormattedTextIdeas(
                      steps[i],
                      isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      isDark,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Parse inline bold/italic formatting into TextSpans
  List<InlineSpan> _parseInlineFormattingIdeas(String text, Color baseColor) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_');
    
    int lastEnd = 0;
    final matches = pattern.allMatches(text).toList();
    
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: baseColor),
        ));
      }
      
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(color: baseColor.withValues(alpha: 0.85), fontStyle: FontStyle.italic),
        ));
      }
      
      lastEnd = match.end;
    }
    
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: baseColor),
      ));
    }
    
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: TextStyle(color: baseColor)));
    }
    
    return spans;
  }

  /// Build formatted text with bold/italic support
  Widget _buildFormattedTextIdeas(String text, Color baseColor, bool isDark) {
    final spans = _parseInlineFormattingIdeas(text, baseColor);
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        color: baseColor,
        height: 1.5,
        fontSize: 13.5,
      ),
    );
  }

  /// Split content into segments and render with premium formatting.
  /// Uses the same visual language as the AI Advisor chat screen.
  List<Widget> _buildSmartContent(String content, bool isDark, bool isCritique) {
    final accent = isDark ? WealthInColors.emeraldGlow : WealthInColors.primary;
    final baseColor = isCritique 
        ? Colors.red.shade900 
        : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87);

    // First sanitize the content
    String cleanContent = _sanitizeAIResponseForIdeas(content);
    // Then convert tables
    cleanContent = _convertTablesForMobile(cleanContent);

    final lines = cleanContent.split('\n');
    final List<Widget> widgets = [];
    
    // Collect consecutive numbered lines for roadmap rendering
    List<String> roadmapBuffer = [];

    void flushRoadmap() {
      if (roadmapBuffer.isEmpty) return;
      widgets.add(_buildRoadmapCardIdeas(roadmapBuffer, isDark, accent));
      roadmapBuffer = [];
    }

    // Also detect emoji-prefixed roadmap steps (🔵 **Step 1: ...)
    final emojiStepPattern = RegExp(r'^[🔵🟢🟡🟠🔴🎯⭐✅]\s*\*\*');
    final arrowPattern = RegExp(r'^\s*⬇️\s*$');
    List<Map<String, String>> emojiRoadmapSteps = [];
    bool inEmojiRoadmap = false;

    void flushEmojiRoadmap() {
      if (emojiRoadmapSteps.isNotEmpty) {
        widgets.add(_buildRoadmapWidget(emojiRoadmapSteps, isDark));
        emojiRoadmapSteps = [];
      }
      inEmojiRoadmap = false;
    }

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      // Skip arrow lines
      if (arrowPattern.hasMatch(line)) continue;

      if (line.isEmpty) {
        flushRoadmap();
        if (inEmojiRoadmap) flushEmojiRoadmap();
        continue;
      }
      
      // Emoji-based roadmap steps
      if (emojiStepPattern.hasMatch(line)) {
        flushRoadmap();
        if (!inEmojiRoadmap) inEmojiRoadmap = true;

        final emoji = line.substring(0, line.indexOf(' '));
        var rest = line.substring(line.indexOf(' ') + 1).trim();
        rest = rest.replaceAll(RegExp(r'^\*\*'), '').replaceAll(RegExp(r'\*\*$'), '');
        
        final descLines = <String>[];
        while (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.isEmpty || arrowPattern.hasMatch(nextLine)) {
            if (arrowPattern.hasMatch(nextLine)) i++;
            break;
          }
          if (emojiStepPattern.hasMatch(nextLine)) break;
          descLines.add(nextLine);
          i++;
        }

        emojiRoadmapSteps.add({
          'emoji': emoji,
          'title': rest,
          'description': descLines.join('\n'),
        });
        continue;
      }

      if (inEmojiRoadmap) {
        flushEmojiRoadmap();
      }

      // Detect numbered steps → collect for roadmap
      final numberedMatch = RegExp(r'^(\d+)[\.)\-]\s*').firstMatch(line);
      if (numberedMatch != null) {
        roadmapBuffer.add(line.substring(numberedMatch.end).trim());
        continue;
      }
      
      // If we had steps buffered but now hit a non-step line, flush
      flushRoadmap();

      // Section headers with icon accent
      if (_isSectionHeaderIdeas(line)) {
        final headerText = _extractHeaderTextIdeas(line);
        widgets.add(_buildSectionHeaderIdeas(headerText, isDark, accent, widgets.isNotEmpty));
        continue;
      }
      
      // Tip / callout boxes (→ Tip: or 💡)
      if (line.startsWith('→ ') || line.toLowerCase().startsWith('tip:') || line.startsWith('💡')) {
        final tipText = line.replaceAll(RegExp(r'^[→💡]\s*'), '').replaceAll(RegExp(r'^[Tt]ip:\s*'), '').trim();
        widgets.add(_buildTipCalloutIdeas(tipText, isDark, accent));
        continue;
      }
      
      // Bullet points with emerald dot
      if (line.startsWith('• ') || line.startsWith('- ')) {
        final bulletText = line.substring(2).trim();
        widgets.add(_buildBulletPointIdeas(bulletText, baseColor, accent, isDark));
        continue;
      }
      
      // Highlight card for key metric lines
      if (_isHighlightLineIdeas(line)) {
        widgets.add(_buildHighlightCardIdeas(line, isDark, accent));
        continue;
      }
      
      // Regular text
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: _buildFormattedTextIdeas(line, baseColor, isDark),
      ));
    }

    flushRoadmap();
    if (inEmojiRoadmap) flushEmojiRoadmap();
    
    if (widgets.isEmpty) {
      return [Text(cleanContent, style: TextStyle(color: baseColor, height: 1.5, fontSize: 13.5))];
    }
    return widgets;
  }

  /// Render a visual roadmap/timeline widget from parsed step data.
  Widget _buildRoadmapWidget(List<Map<String, String>> steps, bool isDark) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.amber.shade700,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++)
            _buildRoadmapStep(
              emoji: steps[i]['emoji'] ?? '🔵',
              title: steps[i]['title'] ?? '',
              description: steps[i]['description'] ?? '',
              color: steps[i]['emoji'] == '🎯' 
                  ? Colors.green 
                  : colors[i % colors.length],
              isLast: i == steps.length - 1,
              isFinalGoal: steps[i]['emoji'] == '🎯',
              isDark: isDark,
              stepIndex: i,
            ).animate(delay: Duration(milliseconds: 80 * i))
             .fadeIn(duration: 300.ms, curve: Curves.easeOut)
             .slideY(begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  /// Build a single roadmap step with circle indicator and connecting line.
  Widget _buildRoadmapStep({
    required String emoji, 
    required String title,
    required String description,
    required Color color,
    required bool isLast,
    required bool isFinalGoal,
    required bool isDark,
    required int stepIndex,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: circle + connecting line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Step circle
                Container(
                  width: isFinalGoal ? 28 : 24,
                  height: isFinalGoal ? 28 : 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: isFinalGoal ? 13 : 11),
                    ),
                  ),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.2)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right side: content card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: isFinalGoal
                    ? Colors.green.withValues(alpha: isDark ? 0.12 : 0.06)
                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFinalGoal
                      ? Colors.green.withValues(alpha: 0.3)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                  width: isFinalGoal ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isFinalGoal ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: isFinalGoal 
                          ? Colors.green 
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark) {
    final isUser = message['role'] == 'user';
    final isCritique = (message['is_critique'] ?? 0) == 1;
    final content = (message['content'] ?? '').toString();

    // User messages: compact, right-aligned
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: WealthInColors.primary.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
    }

    // AI messages: full-width, rich-rendered with premium formatting
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Persona label with icon
          if (message['persona'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: (_personas[message['persona']]?['color'] as Color? ?? Colors.blue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      _personas[message['persona']]?['icon'] as IconData? ?? Icons.psychology,
                      size: 12,
                      color: _personas[message['persona']]?['color'] as Color? ?? Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _personas[message['persona']]?['name'] ?? 'Wealth Advisor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _personas[message['persona']]?['color'] as Color? ?? Colors.blue,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

          // Main content card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: isCritique
                  ? Colors.red.withValues(alpha: 0.08)
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: isCritique
                  ? Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1)
                  : Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Critique banner
                if (isCritique)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_rounded, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text('STRESS TEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 0.5)),
                      ],
                    ),
                  ),

                // Smart content renderer: visual roadmaps + markdown 
                ..._buildSmartContent(content, isDark, isCritique),

                const SizedBox(height: 8),

                // Bottom bar: badges + copy button
                Row(
                  children: [
                    // Source citations
                    if (message['sources'] is List && (message['sources'] as List).isNotEmpty)
                      InkWell(
                        onTap: () => _showSourcesSheet(context, message['sources'] as List, isDark),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 11, color: Colors.blue.shade300),
                              const SizedBox(width: 3),
                              Text(
                                '${(message['sources'] as List).length} sources',
                                style: TextStyle(fontSize: 9, color: Colors.blue.shade300, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Mode badge
                    if (message['mode'] != null) ...[
                      if (message['sources'] is List && (message['sources'] as List).isNotEmpty)
                        const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 10, color: Colors.deepPurple.shade300),
                            const SizedBox(width: 3),
                            Text('WealthIn', style: TextStyle(fontSize: 9, color: Colors.deepPurple.shade300, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],

                    // Gov schemes badge
                    if (_userLocation != null && message['mode'] != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance, size: 10, color: Colors.green.shade400),
                            const SizedBox(width: 3),
                            Text('Gov', style: TextStyle(fontSize: 9, color: Colors.green.shade400, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Copy button
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: isDark ? Colors.white30 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.03, end: 0);
  }

  /// Shows a bottom sheet with sources for an AI message
  void _showSourcesSheet(BuildContext context, List sources, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F23) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 18, color: Colors.blue.shade300),
                const SizedBox(width: 8),
                Text(
                  'Sources (${sources.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sources.take(5).map((source) {
              final title = source is Map ? (source['title'] ?? '') : source.toString();
              final url = source is Map ? (source['url'] ?? '') : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: Colors.blue.shade200),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (url.toString().isNotEmpty)
                            Text(
                              url.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade300,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
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
    // Pick a random wealth fact for encouragement
    final factIndex = DateTime.now().second % _msmeFacts.length;
    final fact = _msmeFacts[factIndex];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Warm welcome icon with glow
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    (_personas[_currentPersona]!['color'] as Color).withOpacity(0.2),
                    (_personas[_currentPersona]!['color'] as Color).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                _personas[_currentPersona]!['icon'] as IconData,
                size: 48,
                color: _personas[_currentPersona]!['color'] as Color,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to your Ideas Lab',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every great business started with a simple conversation.\nShare your idea — I\'ll help you shape, validate, and plan it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            // Wealth fact card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withOpacity(0.08)
                    : Colors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fact,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Workflow hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 8),
                  Text(
                    'Input → Refine → Anchor → DPR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
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
}

/// Full-screen DPR Document Editor - Feels like Google Docs / Notion
class _DprDocumentEditor extends StatefulWidget {
  final List<Map<String, dynamic>> sections;
  final Map<String, dynamic> metadata;
  final String? modelUsed;
  final String sessionTitle;

  const _DprDocumentEditor({
    required this.sections,
    required this.metadata,
    this.modelUsed,
    required this.sessionTitle,
  });

  @override
  State<_DprDocumentEditor> createState() => _DprDocumentEditorState();
}

class _DprDocumentEditorState extends State<_DprDocumentEditor> {
  late List<Map<String, dynamic>> _editableSections;
  final Map<String, TextEditingController> _controllers = {};
  bool _hasChanges = false;
  int? _activeSectionIndex;

  @override
  void initState() {
    super.initState();
    // Deep copy sections for editing
    _editableSections = widget.sections.map((s) {
      return Map<String, dynamic>.from(s.map((key, value) {
        if (value is Map) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        }
        return MapEntry(key, value);
      }));
    }).toList();

    // Create text controllers for each editable field
    for (int i = 0; i < _editableSections.length; i++) {
      final content =
          _editableSections[i]['content'] as Map<String, dynamic>? ?? {};
      for (final entry in content.entries) {
        final key = '${i}_${entry.key}';
        String valueStr;
        if (entry.value is Map) {
          valueStr = (entry.value as Map)
              .entries
              .map((me) => '${me.key}: ${me.value}')
              .join('\n');
        } else if (entry.value is List) {
          valueStr = (entry.value as List).map((v) => '• $v').join('\n');
        } else {
          valueStr = entry.value?.toString() ?? '';
        }
        _controllers[key] = TextEditingController(text: valueStr);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _titleCase(String input) {
    return input
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final completeness = widget.metadata['completeness_pct']?.toString();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E12) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1F25) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Unsaved Changes'),
                  content: const Text(
                    'You have unsaved edits. Discard them?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Keep Editing'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Discard',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sessionTitle.isNotEmpty
                  ? widget.sessionTitle
                  : 'Detailed Project Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(
                  _hasChanges ? Icons.edit : Icons.check_circle,
                  size: 11,
                  color: _hasChanges ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  _hasChanges ? 'Edited' : 'Saved',
                  style: TextStyle(
                    fontSize: 11,
                    color: _hasChanges
                        ? Colors.orange
                        : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (completeness != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '$completeness% complete',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          if (widget.modelUsed != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Chip(
                avatar: Icon(Icons.smart_toy_outlined, size: 14,
                    color: isDark ? Colors.white54 : Colors.black45),
                label: Text(
                  widget.modelUsed!,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey[100],
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy all text',
            onPressed: () {
              final buffer = StringBuffer();
              for (int i = 0; i < _editableSections.length; i++) {
                final section = _editableSections[i];
                buffer.writeln(
                    '${i + 1}. ${section['title'] ?? 'Section ${i + 1}'}');
                buffer.writeln('${'=' * 40}');
                final content =
                    section['content'] as Map<String, dynamic>? ?? {};
                for (final entry in content.entries) {
                  final key = '${i}_${entry.key}';
                  final val = _controllers[key]?.text ?? '';
                  buffer.writeln('${_titleCase(entry.key)}: $val');
                }
                buffer.writeln();
              }
              // Copy to clipboard
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('DPR text copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Section navigation sidebar (desktop only)
          if (MediaQuery.of(context).size.width > 700)
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF12171A) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'SECTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _editableSections.length,
                      itemBuilder: (context, index) {
                        final isActive = _activeSectionIndex == index;
                        final title = (_editableSections[index]['title'] ??
                                'Section ${index + 1}')
                            .toString();
                        return InkWell(
                          onTap: () {
                            setState(() => _activeSectionIndex = index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? WealthInColors.primary.withOpacity(0.1)
                                  : null,
                              border: Border(
                                left: BorderSide(
                                  width: 3,
                                  color: isActive
                                      ? WealthInColors.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? WealthInColors.primary
                                        : (isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive
                                          ? WealthInColors.primary
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Main document area
          Expanded(
            child: _editableSections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No DPR content generated',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width > 700 ? 40 : 16,
                      vertical: 24,
                    ),
                    itemCount: _editableSections.length,
                    itemBuilder: (context, index) {
                      return _buildDocumentSection(index, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(int index, bool isDark) {
    final section = _editableSections[index];
    final sectionTitle =
        (section['title'] ?? 'Section ${index + 1}').toString();
    final content = section['content'] as Map<String, dynamic>? ?? {};

    return GestureDetector(
      onTap: () => setState(() => _activeSectionIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F25) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _activeSectionIndex == index
                ? WealthInColors.primary.withOpacity(0.3)
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: _activeSectionIndex == index ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section heading  
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: WealthInColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: WealthInColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Divider(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            const SizedBox(height: 12),

            // Editable content fields
            ...content.entries.map((e) {
              final key = '${index}_${e.key}';
              final controller = _controllers[key];
              if (controller == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field label
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 14,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _titleCase(e.key),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Editable text field
                    TextField(
                      controller: controller,
                      maxLines: null,
                      onChanged: (_) {
                        if (!_hasChanges) {
                          setState(() => _hasChanges = true);
                        }
                      },
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: WealthInColors.primary.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        hintText: 'Enter ${_titleCase(e.key).toLowerCase()}...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white24 : Colors.black26,
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
    );
  }
}
