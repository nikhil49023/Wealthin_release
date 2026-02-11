import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/data_service.dart';
import '../../core/services/database_helper.dart';
import '../../core/theme/wealthin_theme.dart';

/// Enhanced Brainstorming Screen with Chat + Canvas Interface
/// Psychology Framework: Input (Chat) → Refinery (Critique) → Anchor (Canvas)
class EnhancedBrainstormScreen extends StatefulWidget {
  const EnhancedBrainstormScreen({super.key});

  @override
  State<EnhancedBrainstormScreen> createState() => _EnhancedBrainstormScreenState();
}

class _EnhancedBrainstormScreenState extends State<EnhancedBrainstormScreen> with SingleTickerProviderStateMixin {
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

  // Personas (Thinking Hats)
  final Map<String, Map<String, dynamic>> _personas = {
    'neutral': {
      'name': 'Neutral Consultant',
      'icon': Icons.psychology,
      'color': Colors.blue,
      'description': 'Balanced, practical advice'
    },
    'cynical_vc': {
      'name': 'Cynical VC',
      'icon': Icons.trending_down,
      'color': Colors.red,
      'description': 'Find every way this could fail'
    },
    'enthusiastic_entrepreneur': {
      'name': 'Creative Entrepreneur',
      'icon': Icons.lightbulb,
      'color': Colors.amber,
      'description': 'See opportunities everywhere'
    },
    'risk_manager': {
      'name': 'Risk Manager',
      'icon': Icons.shield,
      'color': Colors.orange,
      'description': 'Legal & financial safety'
    },
    'customer_advocate': {
      'name': 'Customer Advocate',
      'icon': Icons.people,
      'color': Colors.purple,
      'description': 'User-centric perspective'
    },
    'financial_analyst': {
      'name': 'Financial Analyst',
      'icon': Icons.calculate,
      'color': Colors.green,
      'description': 'Run the numbers'
    },
    'systems_thinker': {
      'name': 'Systems Thinker',
      'icon': Icons.account_tree,
      'color': Colors.teal,
      'description': 'Big picture ecosystem view'
    },
  };

  // UI state
  bool _isCanvasVisible = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrCreateSession();
    _showProTipOnFirstLaunch();
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use the Cynical VC for brutal critique',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'When you click REFINE, the AI automatically switches to "Cynical VC" persona.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Why? Your brain is better at spotting flaws than creating perfection.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_down, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Cynical VC will:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('✓ Find every failure point', style: TextStyle(fontSize: 13)),
                      Text('✓ Challenge your assumptions', style: TextStyle(fontSize: 13)),
                      Text('✓ Show real financial impact', style: TextStyle(fontSize: 13)),
                      Text('✓ Make your idea bulletproof', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Result: 10x stronger ideas that survive the real world.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
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
      final messages = await _dbHelper.getBrainstormMessages(_currentSessionId!);
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

  Future<void> _createNewSession() async {
    final sessionId = await _dbHelper.createBrainstormSession(
      'Brainstorm ${DateTime.now().day}/${DateTime.now().month}',
      persona: _currentPersona,
    );

    setState(() {
      _currentSessionId = sessionId;
      _sessionTitle = 'Brainstorm ${DateTime.now().day}/${DateTime.now().month}';
      _messages = [];
      _canvasItems = [];
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentSessionId == null) return;

    setState(() => _isLoading = true);

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
        conversationHistory: _messages.map((m) => {
          'role': m['role'],
          'content': m['content'],
        }).toList(),
        persona: _currentPersona,
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
          _messages.add({
            'role': 'assistant',
            'content': response['content'],
            'persona': _currentPersona,
            'is_critique': _isCritiqueMode ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
            'sources': response['sources'],
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
        const SnackBar(content: Text('Start brainstorming first before critiquing!')),
      );
      return;
    }

    // Store original persona to restore later
    final originalPersona = _currentPersona;

    // PRO-TIP: Automatically switch to Cynical VC for brutal critique
    setState(() {
      _currentPersona = 'cynical_vc';
      _isLoading = true;
      _isCritiqueMode = true;
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
          backgroundColor: (_personas['cynical_vc']!['color'] as Color).withOpacity(0.9),
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
        conversationHistory: _messages.map((m) => {
          'role': m['role'],
          'content': m['content'],
        }).toList(),
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

    setState(() => _isLoading = true);

    try {
      final response = await _dataService.extractCanvasItems(
        conversationHistory: _messages.map((m) => {
          'role': m['role'],
          'content': m['content'],
        }).toList(),
      );

      if (response['success'] == true && response['ideas'] != null) {
        final ideas = response['ideas'] as List;

        // Add to canvas items in DB
        for (var idea in ideas) {
          final colorHex = _getCategoryColor(idea['category']).value;
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extracted ${ideas.length} ideas to canvas!')),
        );
      }
    } catch (e) {
      debugPrint('[Extract Canvas] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extract error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
        title: Text(_sessionTitle),
        backgroundColor: WealthInColors.primary,
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
                _dbHelper.updateBrainstormSession(_currentSessionId!, persona: persona);
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
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      body: Row(
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
      ),
    );
  }

  Widget _buildChatPanel(bool isDark) {
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
                bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCritiqueMode ? Icons.psychology : Icons.chat_bubble_outline,
                  color: _isCritiqueMode ? Colors.red : WealthInColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCritiqueMode
                      ? 'REFINERY: Finding Weak Points 🔍'
                      : 'INPUT: Free Association',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isCritiqueMode ? Colors.red : null,
                  ),
                ),
                if (_isCritiqueMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _personas['cynical_vc']!['icon'] as IconData,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Cynical VC Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Critique button with enhanced styling
                Tooltip(
                  message: '💡 PRO-TIP: Auto-switches to Cynical VC for brutal critique',
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runCritique,
                    icon: const Icon(Icons.content_cut, size: 16),
                    label: const Text('REFINE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: _isCritiqueMode ? 0 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Extract to canvas button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _extractToCanvas,
                  icon: const Icon(Icons.push_pin, size: 16),
                  label: const Text('ANCHOR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WealthInColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
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
                      valueColor: AlwaysStoppedAnimation(WealthInColors.primary),
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
                top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your raw thoughts here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
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
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPanel(bool isDark) {
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
                bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dashboard_customize,
                  color: WealthInColors.cyanGlow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'CANVAS: Ideas That Survived',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_canvasItems.length} items',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark) {
    final isUser = message['role'] == 'user';
    final isCritique = (message['is_critique'] ?? 0) == 1;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.4,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? WealthInColors.primary.withOpacity(0.2)
              : (isCritique
                  ? Colors.red.withOpacity(0.1)
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100])),
          borderRadius: BorderRadius.circular(12),
          border: isCritique
              ? Border.all(color: Colors.red, width: 2)
              : null,
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
                    _personas[message['persona']]?['icon'] as IconData? ?? Icons.psychology,
                    size: 14,
                    color: _personas[message['persona']]?['color'] as Color? ?? Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _personas[message['persona']]?['name'] ?? 'Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _personas[message['persona']]?['color'] as Color? ?? Colors.blue,
                    ),
                  ),
                ],
              ),
            if (!isUser && message['persona'] != null) const SizedBox(height: 6),
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
    final cardColor = colorHex != null ? Color(colorHex) : _getCategoryColor(category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardColor.withOpacity(0.15) : cardColor.withOpacity(0.1),
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
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () async {
                  await _dbHelper.deleteCanvasItem(item['id'] as int);
                  final canvasItems = await _dbHelper.getCanvasItems(_currentSessionId!);
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
            color: (_personas[_currentPersona]!['color'] as Color).withOpacity(0.3),
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
          const SizedBox(height: 24),
          const Text(
            '💡 Tip: Dump raw thoughts here.\n'
            '🔍 Click REFINE to critique ideas.\n'
            '📌 Click ANCHOR to pin survivors to canvas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
