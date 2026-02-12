import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/python_bridge_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';

/// Deep Research Screen - Agentic research with live status log
class DeepResearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const DeepResearchScreen({super.key, this.initialQuery});

  @override
  State<DeepResearchScreen> createState() => _DeepResearchScreenState();
}

class _DeepResearchScreenState extends State<DeepResearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  
  bool _isResearching = false;
  List<String> _statusLog = [];
  String? _report;
  List<String> _sources = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _queryController.text = widget.initialQuery!;
    }
  }
  
  @override
  void dispose() {
    _queryController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }
  
  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isResearching = true;
      _statusLog = ['🔍 Initiating deep research...'];
      _report = null;
      _sources = [];
    });
    
    try {
      // Add simulated progress updates while waiting
      _addSimulatedProgress();

      final result = await pythonBridge.chatWithLLM(
        query:
            'Perform deep research on this topic and return a structured report with practical conclusions and references if possible: $query',
      );

      final responseText = result['response']?.toString();
      final rawSources = result['sources'];
      final parsedSources = <String>[];
      if (rawSources is List) {
        for (final source in rawSources) {
          if (source is String) {
            parsedSources.add(source);
          } else if (source is Map<String, dynamic>) {
            final title = source['title']?.toString() ?? 'Source';
            final url = source['url']?.toString();
            parsedSources.add(url != null && url.isNotEmpty ? '$title - $url' : title);
          } else {
            parsedSources.add(source.toString());
          }
        }
      }

      setState(() {
        _statusLog.addAll([
          '🧠 Synthesizing final report...',
          '✅ Research complete',
        ]);
        _report = responseText;
        _sources = parsedSources;
        _isResearching = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _statusLog.add('❌ Error: $e');
        _isResearching = false;
      });
    }
  }
  
  void _addSimulatedProgress() {
    // Add visual feedback while waiting for backend
    Future.delayed(const Duration(seconds: 2), () {
      if (_isResearching && mounted) {
        setState(() => _statusLog.add('📋 Planning research strategy...'));
        _scrollToBottom();
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (_isResearching && mounted) {
        setState(() => _statusLog.add('🌐 Searching DuckDuckGo...'));
        _scrollToBottom();
      }
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (_isResearching && mounted) {
        setState(() => _statusLog.add('📖 Reading top sources...'));
        _scrollToBottom();
      }
    });
    Future.delayed(const Duration(seconds: 12), () {
      if (_isResearching && mounted) {
        setState(() => _statusLog.add('🤔 Evaluating findings...'));
        _scrollToBottom();
      }
    });
  }
  
  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔬 Deep Research'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.deepNavy,
                const Color(0xFF1E3A5F), // Navy blue gradient
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Query Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.grey.shade900 
                  : Colors.grey.shade50,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Reliance Q3 earnings + green hydrogen outlook"',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                    ),
                    onSubmitted: (_) => _startResearch(),
                    enabled: !_isResearching,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isResearching ? null : _startResearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WealthInTheme.regalGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isResearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Research'),
                ),
              ],
            ),
          ),
          
          // Live Status Log
          if (_statusLog.isNotEmpty) ...[
            Container(
              height: 160,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WealthInTheme.trueEmerald.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isResearching ? Colors.green : Colors.grey,
                        ),
                      ).animate(
                        onPlay: (c) => c.repeat(),
                        autoPlay: _isResearching,
                      ).fade(duration: 500.ms, begin: 0.4, end: 1.0),
                      const SizedBox(width: 8),
                      Text(
                        _isResearching ? 'RESEARCHING...' : 'COMPLETE',
                        style: TextStyle(
                          color: _isResearching ? Colors.green : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _statusLog.length,
                      itemBuilder: (context, index) {
                        final log = _statusLog[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Report Display
          Expanded(
            child: _report != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report content
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.grey.shade900 
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: SelectableText(
                            _report!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        
                        // Sources
                        if (_sources.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Sources (${_sources.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _sources.take(5).map((url) {
                              final domain = Uri.tryParse(url)?.host ?? url;
                              return ActionChip(
                                avatar: const Icon(Icons.link, size: 16),
                                label: Text(
                                  domain.length > 25 
                                      ? '${domain.substring(0, 25)}...' 
                                      : domain,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () {
                                  // Could launch URL here
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a research query to begin',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'e.g., "TCS Q3 FY24 earnings analysis"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
