---
name: smart-ai-router
description: Smart routing between RAG and LLM based on query type
---

# Smart AI Router Skill

This skill manages intelligent routing of AI queries between RAG (Retrieval Augmented Generation) for factual accuracy and regular LLM for conversational responses.

## Architecture

```
User Query → Query Classifier → Decision Engine → [RAG or LLM] → Response
                   ↓
           Pattern Matching
           + Query Length
           + Context Analysis
```

## Routing Logic

### Use RAG When:
- Query asks about **tax regulations**, GST, income tax
- Query mentions **government schemes** (MUDRA, PMEGP, Startup India)
- Query needs **market data** (stocks, mutual funds, interest rates)
- Query requires **document templates** (DPR, project reports)
- Query asks for **statistics** or calculations

### Use LLM When:
- Conversational greetings (hello, hi, thanks)
- Opinion/advice requests (what should I do, recommend)
- Personal budget questions referencing "my" transactions
- Short queries (< 4 words)
- General tips and strategies

## Implementation

The routing is implemented in:
- `wealthin_server/lib/src/services/ai_router_service.dart`

### Key Classes:
- `AIRouterService` - Main router singleton
- `QueryRouteDecision` - Decision metadata
- `AIRouterResponse` - Complete response with routing info

## Usage in Endpoints

```dart
final router = AIRouterService();
final result = await router.processQuery(
  query,
  recentTransactions: userTransactions,
);

// result.decision.useRag - whether RAG was used
// result.decision.reason - explanation for routing
// result.response - the actual response
```

## Fallback Behavior

If the primary route fails:
1. If RAG fails → Fallback to LLM
2. If LLM fails → Fallback to RAG
3. If both fail → Return error message
