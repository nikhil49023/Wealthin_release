import 'package:flutter/material.dart';
import '../../core/services/hybrid_ai_service.dart';
import '../../core/services/query_router.dart';
import '../../main.dart' show authService;

/// Test screen for Hybrid AI system
/// Tests API responses, performance, and reliability
class HybridAITestScreen extends StatefulWidget {
  const HybridAITestScreen({super.key});

  @override
  State<HybridAITestScreen> createState() => _HybridAITestScreenState();
}

class _HybridAITestScreenState extends State<HybridAITestScreen> {
  final List<TestResult> _testResults = [];
  bool _isTesting = false;
  Map<String, dynamic>? _stats;

  final List<TestQuery> _testQueries = [
    // All queries are API-only now
    TestQuery(
      query: "Is 500 rupees a good price for lunch?",
      expectedStrategy: InferenceStrategy.api,
      category: "Simple decision",
    ),
    TestQuery(
      query: "Categorize this: mutual fund investment",
      expectedStrategy: InferenceStrategy.api,
      category: "Categorization",
    ),
    TestQuery(
      query: "Calculate: 10000 * 12",
      expectedStrategy: InferenceStrategy.api,
      category: "Simple math",
    ),
    TestQuery(
      query: "Yes or no: Should I save money?",
      expectedStrategy: InferenceStrategy.api,
      category: "Yes/No question",
    ),

    // Medium queries
    TestQuery(
      query: "Explain what is ELSS in 2 sentences",
      expectedStrategy: InferenceStrategy.api,
      category: "Simple explanation",
    ),
    TestQuery(
      query: "Give me 3 saving tips",
      expectedStrategy: InferenceStrategy.api,
      category: "Simple list",
    ),

    // Complex queries (should use API)
    TestQuery(
      query: "Search for latest mutual fund news in India",
      expectedStrategy: InferenceStrategy.api,
      category: "Web search",
    ),
    TestQuery(
      query: "What are the current best performing mutual funds?",
      expectedStrategy: InferenceStrategy.api,
      category: "Real-time data",
    ),
    TestQuery(
      query: "Analyze and compare HDFC vs ICICI mutual funds",
      expectedStrategy: InferenceStrategy.api,
      category: "Complex analysis",
    ),
    TestQuery(
      query: "Create a step-by-step retirement planning strategy",
      expectedStrategy: InferenceStrategy.api,
      category: "Multi-step reasoning",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _stats = hybridAI.getStats();
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isTesting = true;
      _testResults.clear();
    });

    for (final testQuery in _testQueries) {
      await _runSingleTest(testQuery);
    }

    setState(() {
      _isTesting = false;
    });

    await _loadStats();
  }

  Future<void> _runSingleTest(TestQuery testQuery) async {
    final startTime = DateTime.now();

    try {
      // API-only strategy
      const actualStrategy = InferenceStrategy.api;

      // Execute query
      final response = await hybridAI.chat(
        testQuery.query,
        userId: authService.currentUserId,
      );

      final latency = DateTime.now().difference(startTime);

      setState(() {
        _testResults.add(TestResult(
          query: testQuery,
          actualStrategy: actualStrategy,
          response: response.response,
          latencyMs: latency.inMilliseconds,
          inferenceMode: response.inferenceMode ?? 'unknown',
          success: true,
        ));
      });
    } catch (e) {
      final latency = DateTime.now().difference(startTime);

      setState(() {
        _testResults.add(TestResult(
          query: testQuery,
          actualStrategy: InferenceStrategy.api, // Fallback
          response: 'Error: $e',
          latencyMs: latency.inMilliseconds,
          inferenceMode: 'error',
          success: false,
        ));
      });
    }

    // Small delay between tests
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid AI Test Suite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          Expanded(
            child: _testResults.isEmpty
                ? _buildEmptyState()
                : _buildTestResults(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTesting ? null : _runAllTests,
        icon: _isTesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isTesting ? 'Testing...' : 'Run Tests'),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Loading stats...'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hybrid AI Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Queries',
                  _stats!['total_queries'].toString(),
                  Icons.analytics,
                  Colors.blue,
                ),
                _buildStatItem(
                  'API',
                  _stats!['api_queries'].toString(),
                  Icons.cloud,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Cache Hits',
                  _stats!['cache_hits'].toString(),
                  Icons.bolt,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(),
            const SizedBox(height: 8),
            Text('Mode: ${_stats!['mode']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tests run yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press the button below to run test suite',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _testResults.length,
      itemBuilder: (context, index) {
        final result = _testResults[index];
        final isCorrect =
            result.actualStrategy == result.query.expectedStrategy;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Icon(
              result.success
                  ? (isCorrect ? Icons.check_circle : Icons.warning)
                  : Icons.error,
              color: result.success
                  ? (isCorrect ? Colors.green : Colors.orange)
                  : Colors.red,
            ),
            title: Text(
              result.query.query,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${result.inferenceMode.toUpperCase()} • ${result.latencyMs}ms • ${result.query.category}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(
                      'Expected Strategy',
                      result.query.expectedStrategy.toString(),
                    ),
                    _buildResultRow(
                      'Actual Strategy',
                      result.actualStrategy.toString(),
                      highlight: !isCorrect,
                    ),
                    _buildResultRow(
                      'Inference Mode',
                      result.inferenceMode,
                    ),
                    _buildResultRow(
                      'Latency',
                      '${result.latencyMs}ms',
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Response:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.response,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? Colors.orange : Colors.grey[700],
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TestQuery {
  final String query;
  final InferenceStrategy expectedStrategy;
  final String category;

  TestQuery({
    required this.query,
    required this.expectedStrategy,
    required this.category,
  });
}

class TestResult {
  final TestQuery query;
  final InferenceStrategy actualStrategy;
  final String response;
  final int latencyMs;
  final String inferenceMode;
  final bool success;

  TestResult({
    required this.query,
    required this.actualStrategy,
    required this.response,
    required this.latencyMs,
    required this.inferenceMode,
    required this.success,
  });
}
