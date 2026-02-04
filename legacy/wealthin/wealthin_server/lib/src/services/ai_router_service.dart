import 'zoho_service.dart';
import 'sarvam_service.dart';
import 'openai_service.dart';

/// AIRouterService - Quad-Model Smart Routing with Response Validation
/// Routes between:
/// 1. Sarvam AI - for Indic language queries
/// 2. RAG (Zoho) - for factual accuracy
/// 3. LLM (Zoho) - for conversational responses
/// 4. OpenAI - as ultimate fallback for reliability
class AIRouterService {
  static final AIRouterService _instance = AIRouterService._internal();
  factory AIRouterService() => _instance;
  AIRouterService._internal();

  final ZohoService _zohoService = ZohoService();
  final SarvamService _sarvamService = SarvamService();
  final OpenAIService _openaiService = OpenAIService();

  /// Query types that need RAG (factual accuracy)
  static const _ragPatterns = [
    // Financial facts
    'tax', 'gst', 'income tax', 'deduction',
    'scheme', 'government', 'mudra', 'pmegp', 'startup india',
    'regulation', 'compliance', 'legal', 'license',
    'interest rate', 'emi', 'loan',
    // Market data
    'stock', 'mutual fund', 'investment', 'ppf', 'nps', 'epf',
    'insurance', 'term plan', 'health insurance',
    // Document needs
    'dpr', 'project report', 'bank document', 'business plan format',
    // Stats/Numbers
    'statistics', 'data', 'percentage', 'calculation',
  ];

  /// Query types that need only conversational LLM
  static const _llmPatterns = [
    // Casual conversation
    'hello', 'hi', 'hey', 'thanks', 'thank you', 'bye',
    // Opinion/advice
    'suggest', 'recommend', 'what should', 'opinion',
    'tips', 'advice', 'help me', 'how to',
    // Personal context
    'my budget', 'my expense', 'my income', 'my savings',
    'my transactions', 'my goal',
  ];

  /// Determine routing for query: Sarvam (Indic), RAG (factual), or LLM (conversational)
  QueryRouteDecision routeQuery(String query) {
    final lowerQuery = query.toLowerCase();

    // Step 1: Check for Indic language - route to Sarvam AI
    if (_sarvamService.isIndicQuery(query)) {
      final detectedLang = _sarvamService.detectLanguage(query);
      return QueryRouteDecision(
        routeType: RouteType.sarvam,
        useRag: false,
        reason: 'Indic language detected: $detectedLang - routing to Sarvam AI',
        confidence: 0.95,
        detectedLanguage: detectedLang,
      );
    }

    // Step 2: Check for RAG patterns (factual queries)
    for (final pattern in _ragPatterns) {
      if (lowerQuery.contains(pattern)) {
        return QueryRouteDecision(
          routeType: RouteType.rag,
          useRag: true,
          reason: 'Query contains factual pattern: "$pattern" - using RAG',
          confidence: 0.9,
        );
      }
    }

    // Step 3: Check for LLM-only patterns (conversational)
    for (final pattern in _llmPatterns) {
      if (lowerQuery.contains(pattern)) {
        return QueryRouteDecision(
          routeType: RouteType.llm,
          useRag: false,
          reason: 'Query is conversational: "$pattern" - using LLM',
          confidence: 0.85,
        );
      }
    }

    // Step 4: Check query length - short queries likely conversational
    if (query.split(' ').length < 4) {
      return QueryRouteDecision(
        routeType: RouteType.llm,
        useRag: false,
        reason: 'Short query - using LLM for quick response',
        confidence: 0.7,
      );
    }

    // Default: use RAG for unknown/complex queries (better accuracy)
    return QueryRouteDecision(
      routeType: RouteType.rag,
      useRag: true,
      reason: 'Complex query - using RAG for accuracy',
      confidence: 0.6,
    );
  }

  /// Process query with tri-model smart routing and response validation
  Future<AIRouterResponse> processQuery(
    String query, {
    String? userContext,
    List<Map<String, dynamic>>? recentTransactions,
  }) async {
    final decision = routeQuery(query);
    final triedRoutes = <RouteType>{};
    
    // Try primary route
    var response = await _tryRoute(decision.routeType, query, userContext, recentTransactions);
    triedRoutes.add(decision.routeType);
    
    // If response looks like an error, try other routes
    if (_isErrorResponse(response)) {
      print('Response validation failed for ${decision.routeType}: "$response"');
      
      // Define fallback order based on primary route
      final fallbackOrder = _getFallbackOrder(decision.routeType);
      
      for (final fallbackRoute in fallbackOrder) {
        if (triedRoutes.contains(fallbackRoute)) continue;
        
        print('Trying fallback route: $fallbackRoute');
        final fallbackResponse = await _tryRoute(fallbackRoute, query, userContext, recentTransactions);
        triedRoutes.add(fallbackRoute);
        
        if (!_isErrorResponse(fallbackResponse)) {
          return AIRouterResponse(
            response: fallbackResponse,
            decision: decision.copyWith(
              reason: '${decision.reason} (fallback: $fallbackRoute succeeded)',
            ),
            success: true,
          );
        }
        print('Fallback $fallbackRoute also failed: "$fallbackResponse"');
      }
      
      // All routes failed, return the original response with failure flag
      return AIRouterResponse(
        response: "I'm having trouble right now. Please try again in a moment.",
        decision: decision,
        success: false,
        error: 'All AI routes failed validation',
      );
    }
    
    return AIRouterResponse(
      response: response,
      decision: decision,
      success: true,
    );
  }

  /// Check if response indicates an error or failure
  bool _isErrorResponse(String response) {
    if (response.isEmpty) return true;
    
    final lowerResponse = response.toLowerCase();
    
    // Error patterns to detect
    final errorPatterns = [
      "i'm having trouble",
      "i am having trouble",
      "unable to process",
      "cannot process",
      "error processing",
      "please try again",
      "something went wrong",
      "i apologize, but i",
      "i'm sorry, but i cannot",
      "i don't have enough information",
      "no answer found",
      "failed to",
      "error:",
      "exception:",
      "configuration is missing",
      "api key not",
      "unauthorized",
      "forbidden",
      "rate limit",
      "timeout",
  ];
    
    for (final pattern in errorPatterns) {
      if (lowerResponse.contains(pattern)) {
        return true;
      }
    }
    
    // Also check for very short responses (likely errors)
    if (response.length < 10) return true;
    
    return false;
  }

  /// Get fallback order based on primary route (OpenAI always last as ultimate fallback)
  List<RouteType> _getFallbackOrder(RouteType primary) {
    switch (primary) {
      case RouteType.sarvam:
        return [RouteType.llm, RouteType.rag, RouteType.openai];
      case RouteType.rag:
        return [RouteType.llm, RouteType.sarvam, RouteType.openai];
      case RouteType.llm:
        return [RouteType.rag, RouteType.sarvam, RouteType.openai];
      case RouteType.openai:
        return [RouteType.llm, RouteType.rag, RouteType.sarvam];
    }
  }

  /// Try a specific route and return response (or error message)
  Future<String> _tryRoute(
    RouteType route,
    String query,
    String? userContext,
    List<Map<String, dynamic>>? recentTransactions,
  ) async {
    try {
      switch (route) {
        case RouteType.sarvam:
          if (SarvamConfig.isValid) {
            return await _sarvamService.simpleChat(
              query,
              systemPrompt: _buildIndicSystemPrompt(),
            );
          } else {
            print('Sarvam not configured');
            return 'Configuration is missing for Sarvam';
          }
          
        case RouteType.rag:
          return await _zohoService.ragAnswer(query);
          
        case RouteType.llm:
          final systemPrompt = _buildSystemPrompt(userContext, recentTransactions);
          return await _zohoService.chat(systemPrompt, query);
          
        case RouteType.openai:
          // OpenAI as ultimate fallback - most reliable
          if (OpenAIConfig.isValid) {
            return await _openaiService.simpleChat(
              query,
              systemPrompt: _buildSystemPrompt(userContext, recentTransactions),
            );
          } else {
            print('OpenAI not configured');
            return 'Configuration is missing for OpenAI';
          }
      }
    } catch (e) {
      print('Route $route error: $e');
      return 'Error: $e';
    }
  }


  /// Handle fallback when primary route fails
  Future<AIRouterResponse> _handleFallback(
    String query, 
    QueryRouteDecision decision,
    String error,
  ) async {
    print('Primary route failed: $error');
    
    try {
      String fallbackResponse;
      
      // Try different fallback based on what failed
      switch (decision.routeType) {
        case RouteType.sarvam:
          // If Sarvam failed, try Zoho LLM
          fallbackResponse = await _zohoService.chat(
            'You are a helpful financial assistant fluent in Indian languages and culture.',
            query,
          );
          break;
          
        case RouteType.rag:
          // If RAG failed, try regular LLM
          fallbackResponse = await _zohoService.chat(
            'You are a helpful financial assistant. Answer concisely.',
            query,
          );
          break;
          
        case RouteType.llm:
          // If LLM failed, try RAG
          fallbackResponse = await _zohoService.ragAnswer(query);
          break;
          
        case RouteType.openai:
          // If OpenAI failed, try Zoho LLM
          fallbackResponse = await _zohoService.chat(
            'You are a helpful financial assistant. Answer concisely.',
            query,
          );
          break;
      }
      
      return AIRouterResponse(
        response: fallbackResponse,
        decision: decision.copyWith(
          reason: '${decision.reason} (fallback used: ${decision.routeType} failed)',
        ),
        success: true,
      );
    } catch (fallbackError) {
      return AIRouterResponse(
        response: "I'm having trouble processing your request. Please try again.",
        decision: decision,
        success: false,
        error: fallbackError.toString(),
      );
    }
  }

  /// Build system prompt for Indic language responses
  String _buildIndicSystemPrompt() {
    return '''You are WealthIn AI, a friendly financial advisor for Indian users.
You understand Indian culture, business practices, and financial concepts.
Respond naturally in the user's language (Hindi, Telugu, Tamil, etc.).
Use Indian Rupee (₹) for currency. Be culturally appropriate and helpful.
Understand terms like Kirana (retail shop), Dhaba (roadside restaurant), 
Tiffin service (meal delivery), and other local business concepts.''';
  }

  /// Build context-aware system prompt for LLM
  String _buildSystemPrompt(
    String? userContext,
    List<Map<String, dynamic>>? transactions,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are WealthIn AI, a friendly and helpful financial advisor.');
    buffer.writeln('You help users with budgeting, saving, and financial planning.');
    buffer.writeln('Keep responses concise but informative. Use Indian Rupee (₹) for currency.');
    buffer.writeln('');
    
    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln('User Context: $userContext');
      buffer.writeln('');
    }
    
    if (transactions != null && transactions.isNotEmpty) {
      buffer.writeln('Recent Transactions:');
      for (final t in transactions.take(5)) {
        final type = t['type'] == 'income' ? '+' : '-';
        buffer.writeln('  $type ₹${t['amount']} - ${t['description']}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('Respond naturally and provide actionable advice when appropriate.');
    
    return buffer.toString();
  }
}

/// Route types for the tri-model architecture
enum RouteType { sarvam, rag, llm, openai }

/// Routing decision details
class QueryRouteDecision {
  final RouteType routeType;
  final bool useRag;
  final String reason;
  final double confidence;
  final String? detectedLanguage;

  QueryRouteDecision({
    required this.routeType,
    required this.useRag,
    required this.reason,
    required this.confidence,
    this.detectedLanguage,
  });

  QueryRouteDecision copyWith({
    RouteType? routeType,
    bool? useRag,
    String? reason,
    double? confidence,
    String? detectedLanguage,
  }) {
    return QueryRouteDecision(
      routeType: routeType ?? this.routeType,
      useRag: useRag ?? this.useRag,
      reason: reason ?? this.reason,
      confidence: confidence ?? this.confidence,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
    );
  }

  Map<String, dynamic> toJson() => {
    'routeType': routeType.name,
    'useRag': useRag,
    'reason': reason,
    'confidence': confidence,
    if (detectedLanguage != null) 'detectedLanguage': detectedLanguage,
  };
}

/// Complete AI response with routing metadata
class AIRouterResponse {
  final String response;
  final QueryRouteDecision decision;
  final bool success;
  final String? error;

  AIRouterResponse({
    required this.response,
    required this.decision,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'response': response,
    'decision': decision.toJson(),
    'success': success,
    if (error != null) 'error': error,
  };
}
