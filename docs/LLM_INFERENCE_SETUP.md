# LLM Inference Layer Implementation Guide

## Overview

The LLM Inference Layer provides flexible routing between local Nemotron models, cloud-based inference, and OpenAI as a fallback. This enables offline-capable local inference while gracefully falling back to cloud options when needed.

## Architecture

```
Flutter App
    ↓
AIAgentService (Updated)
    ↓
LLMInferenceRouter
    ├─→ Local Inference (Nemotron/Sarvam-1)
    ├─→ Cloud Inference (Backend endpoint)
    └─→ OpenAI Fallback (GPT-4 Turbo)
```

## Components Created

### 1. **nemotron_inference_service.dart**
   - Handles local GGUF model loading and inference
   - Device capability detection (RAM, storage, OS)
   - Automatic model selection (1B for mobile, 3B for larger devices)
   - Nemotron function calling format parser
   - Cloud endpoint integration

### 2. **llm_inference_router.dart**
   - Routes inference requests through preferred mode
   - Implements fallback logic: local → cloud → OpenAI
   - Timeout handling and error recovery
   - Configurable mode switching
   - Status monitoring

### 3. **ai_agent_service.dart** (Updated)
   - Enhanced with initialization for LLM routing
   - `chat()` method now routes through inference router
   - Falls back to direct backend endpoint if all modes fail
   - Tracks tokens used and inference mode
   - Maintains backward compatibility

### 4. **llm_inference_endpoints.py** (Python Backend)
   - `/llm/inference` - Main inference endpoint
   - `/llm/parse-tool-call` - Extracts tool calls from response
   - `/llm/status` - Returns capability information

## Setup Instructions

### Phase 1: Basic Cloud Inference (No Local Model)

**1. Initialize in main.dart:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with cloud-only mode initially
  await aiAgentService.initialize(
    preferredMode: InferenceMode.cloud,
    allowFallback: true,
  );
  
  runApp(const MyApp());
}
```

**2. Use in chat screen:**
```dart
final response = await aiAgentService.chat(
  "Help me create a budget for groceries",
  userContext: {
    'monthly_income': 50000,
    'current_expenses': 35000,
  },
);

if (response.actionTaken) {
  print('AI wants to call: ${response.actionType}');
  print('Parameters: ${response.actionData}');
}
```

### Phase 2: Add Local Nemotron Model

**1. Add mlc_llm to pubspec.yaml:**
```yaml
dependencies:
  mlc_llm: ^0.2.0  # Or flutter_llama depending on preference
```

**2. Update nemotron_inference_service.dart implementation:**
Replace the mock `inferLocal()` method with actual mlc_llm integration:

```dart
Future<NemotronResponse> inferLocal(
  String prompt, {
  List<Map<String, dynamic>>? tools,
  int maxTokens = 2048,
  double temperature = 0.7,
  Map<String, dynamic>? systemPrompt,
}) async {
  if (!_isModelLoaded) {
    throw Exception('Model not loaded.');
  }

  try {
    // Use mlc_llm or flutter_llama
    final mlcEngine = MLCEngine();
    
    // Build prompt with tools
    final fullPrompt = _buildPromptWithTools(
      systemPrompt ?? {},
      prompt,
      tools ?? [],
    );
    
    // Run inference
    final response = await mlcEngine.generate(
      fullPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
    
    // Parse Nemotron function calls
    final toolCall = parseToolCall(response);
    
    return NemotronResponse(
      text: response,
      toolCall: toolCall,
      finishReason: 'stop',
      tokensUsed: response.length ~/ 4, // Rough estimate
      isLocal: true,
    );
  } catch (e) {
    rethrow;
  }
}
```

**3. Initialize with local mode:**
```dart
await aiAgentService.initialize(
  preferredMode: InferenceMode.local,
  allowFallback: true,
);
```

### Phase 3: Add Python Backend Inference

**1. Add LLM endpoints to Python backend:**

Copy `llm_inference_endpoints.py` content into `wealthin_agents/main.py`:

```python
from datetime import datetime

# Add after imports and before routes
# ... [insert llm_inference_endpoints.py content here]

# In main() function, add before app startup:
# Routes are registered with @app.post() decorator
```

**2. Test endpoint:**
```bash
curl -X POST http://localhost:8000/llm/inference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is a budget?",
    "max_tokens": 200,
    "temperature": 0.7,
    "format": "nemotron"
  }'
```

**3. Update cloud endpoint in Flutter:**
```dart
await aiAgentService.initialize(
  preferredMode: InferenceMode.cloud,
  cloudEndpoint: 'http://localhost:8000',
  allowFallback: true,
);
```

### Phase 4: Add OpenAI Fallback

**1. Get OpenAI API key:**
- Sign up at https://platform.openai.com
- Create API key in account settings
- Set environment variable or pass programmatically

**2. Initialize with OpenAI fallback:**
```dart
await aiAgentService.initialize(
  preferredMode: InferenceMode.cloud,
  openaiApiKey: const String.fromEnvironment('OPENAI_API_KEY'),
  allowFallback: true,
);
```

**3. Costs:**
- GPT-4 Turbo: ~$0.01-0.03 per 1K tokens
- Recommended: Use local/cloud only, OpenAI as emergency fallback

## Nemotron Function Calling Format

The system uses the following format for tool calls:

```json
{
  "type": "tool_call",
  "tool_call": {
    "name": "create_budget",
    "arguments": {
      "category": "Food",
      "amount": 5000,
      "period": "monthly"
    }
  }
}
```

### Available Tools

From `ai_agent_service.dart`:
- `create_budget` - Create spending category limit
- `create_savings_goal` - Set savings target
- `schedule_payment` - Setup bill reminder
- `add_transaction` - Record income/expense
- `get_spending_summary` - Generate financial report

## Inference Mode Comparison

| Mode | Latency | Cost | Privacy | Reliability |
|------|---------|------|---------|-------------|
| **Local** | <1s | Free | High | ✅ Offline |
| **Cloud** | 1-3s | Free | Medium | ✅ Online required |
| **OpenAI** | 2-5s | $0.01-0.03/msg | Low | ✅ Highly reliable |

## Monitoring & Debugging

### Check Inference Status
```dart
final status = aiAgentService.getInferenceStatus();
print(status);
// Output:
// {
//   initialized: true,
//   inferenceRouter: {
//     preferredMode: InferenceMode.cloud,
//     nemotronStatus: { modelLoaded: false, ... },
//     ...
//   }
// }
```

### Switch Modes at Runtime
```dart
// Switch to local if available
aiAgentService.setInferenceMode(InferenceMode.local);

// Switch to cloud
aiAgentService.setInferenceMode(InferenceMode.cloud);
```

### Debug Logs
All components log to console with prefix:
- `[NemotronInference]` - Model loading and inference
- `[LLMRouter]` - Routing decisions and fallbacks
- `[AIAgentService]` - High-level chat operations

## Testing Checklist

- [ ] Cloud inference returns valid responses
- [ ] Tool calls are correctly parsed from responses
- [ ] Fallback activates when preferred mode fails
- [ ] Timeouts are handled gracefully
- [ ] OpenAI fallback works (if configured)
- [ ] Tokens are counted accurately
- [ ] Inference mode can be switched at runtime
- [ ] Local model loads correctly (when implemented)
- [ ] Offline detection works properly

## Performance Optimization Tips

1. **Cache model in memory** - Avoid reloading between requests
2. **Use quantized models** - 1B/3B Q4 formats reduce size/latency
3. **Batch requests** - Process multiple queries together
4. **Set appropriate timeout** - Balance between responsiveness and quality
5. **Monitor token usage** - For OpenAI cost optimization

## Next Steps

1. ✅ **Integrate Cloud Inference** - Test `/llm/inference` endpoint
2. **Implement Local Model Loading** - mlc_llm or flutter_llama
3. **Add Model Caching** - Store GGUF files locally
4. **Create UI Indicators** - Show which mode is active
5. **Build Analytics Dashboard** - Track inference costs and latency
6. **Optimize Prompts** - Task-specific system messages for better results

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cloud inference times out | Increase timeout in `llm_inference_router.dart` |
| OpenAI returns errors | Verify API key is valid and has quota |
| Tool calls not parsing | Check response format matches Nemotron spec |
| Local model won't load | Verify GGUF file exists and device has RAM |
| High latency | Profile with DevTools, consider cloud mode |
| High costs | Reduce token limits, cache responses |

## File Locations

- **Flutter Services**: `/wealthin_flutter/lib/core/services/`
  - `nemotron_inference_service.dart`
  - `llm_inference_router.dart`
  - `ai_agent_service.dart` (updated)

- **Python Backend**: `/wealthin_agents/`
  - `llm_inference_endpoints.py` (to merge into main.py)
  - `main.py` (add `/llm/*` routes)

- **Configuration**: Environment variables or `.env` file
  - `OPENAI_API_KEY` (optional, for fallback)
  - Backend URL auto-configured via `backendConfig`

---

## Advanced: Custom Model Integration

To use a different model instead of Sarvam-1:

1. **Prepare GGUF file** - Convert model to GGUF format
2. **Update model paths** in `nemotron_inference_service.dart`
3. **Modify prompt templates** if model has different expectations
4. **Test thoroughly** - Verify tool call parsing works

Example for Llama 2 or Mistral:
```dart
const String CUSTOM_MODEL = 'mistral-7b-q4';

// Update selectOptimalModel() to choose this model
String selectOptimalModel(Map<String, dynamic> capabilities) {
  return CUSTOM_MODEL;
}
```

