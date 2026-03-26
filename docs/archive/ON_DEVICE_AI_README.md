# On-Device Inference Integration Guide

## Overview
Hybrid AI system for WealthIn that uses:
- **On-device (Phi-4-mini)**: 90% of queries - categorization, calculations, simple Q&A
- **API (Sarvam AI)**: 10% of queries - web search, complex reasoning, real-time data

## Cost Savings
- Pure API: $100/month at 10K users
- Hybrid: $20/month at 10K users (80% savings)
- Breakeven: 3-4 months of development

## Implementation Steps

### 1. Add Flutter Packages

Add to `pubspec.yaml`:
```yaml
dependencies:
  # For on-device inference
  llama_cpp_dart: ^0.2.0  # Or latest version
  # Alternative: flutter_llama

  # For device detection
  device_info_plus: ^9.1.0

  # For model downloads
  dio: ^5.4.0
  path_provider: ^2.1.0
```

### 2. Download Phi-4-mini Model

Model: `Phi-4-Q4_K_M.gguf` (2.5GB)
URL: https://huggingface.co/microsoft/phi-4-gguf/resolve/main/Phi-4-Q4_K_M.gguf

**Option A: Bundle with app (increases APK size)**
```bash
# Download model
mkdir -p frontend/wealthin_flutter/assets/models
curl -L -o frontend/wealthin_flutter/assets/models/Phi-4-Q4_K_M.gguf \
  https://huggingface.co/microsoft/phi-4-gguf/resolve/main/Phi-4-Q4_K_M.gguf

# Add to pubspec.yaml
flutter:
  assets:
    - assets/models/Phi-4-Q4_K_M.gguf
```

**Option B: Download on first run (recommended)**
- Smaller APK size
- Implemented in `on_device_inference_service.dart` (TODO: complete implementation)

### 3. Integrate llama.cpp

Update `on_device_inference_service.dart` to use actual llama.cpp:

```dart
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class OnDeviceInferenceService {
  LlamaContext? _llamaContext;

  Future<bool> _loadModel() async {
    try {
      _llamaContext = await LlamaCpp.loadModel(
        _modelPath,
        params: LlamaParams(
          nCtx: 2048,        // Context window
          nThreads: 4,       // CPU threads
          nGpuLayers: 0,     // Use CPU (or GPU if available)
          useMlock: true,    // Lock model in RAM
        ),
      );
      _modelLoaded = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String> generate(
    String prompt, {
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    final response = await _llamaContext!.generate(
      prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      stopTokens: ['<|endoftext|>', 'User:', '\n\n'],
    );
    return response.text;
  }
}
```

### 4. Native Code Integration (Android)

If using direct FFI, add native llama.cpp:

```bash
# Add llama.cpp as native library
cd frontend/wealthin_flutter/android/app/src/main/jniLibs
mkdir -p arm64-v8a armeabi-v7a x86_64

# Download precompiled llama.cpp binaries
# Or compile from source: https://github.com/ggerganov/llama.cpp
```

### 5. Test the Hybrid System

Run the test queries:
```dart
// Simple queries (should use on-device)
final test1 = await hybridAI.testQuery("Is 500 rupees a good price?");
final test2 = await hybridAI.testQuery("Categorize: savings or investment?");

// Complex queries (should use API)
final test3 = await hybridAI.testQuery("Search for latest mutual fund news");
final test4 = await hybridAI.testQuery("Explain tax implications of ELSS");

// Check stats
final stats = hybridAI.getStats();
print('Local: ${stats['local_percentage']}');
print('API: ${stats['api_percentage']}');
```

## Current Status

✅ **Implemented:**
- Smart query router with complexity analysis
- Hybrid service orchestrator
- Multi-key Sarvam AI fallback
- Stats tracking
- Integration with AI advisor screen

⏳ **TODO:**
- Add llama_cpp_dart package
- Implement actual model loading
- Implement actual inference
- Add model download with progress
- Add device capability detection (RAM, chipset)
- Test on real devices
- Optimize memory usage
- Add model unloading after idle

## Performance Targets

**On-device (Phi-4-mini on Snapdragon 8 Gen 2):**
- Latency: 1-2 seconds for 50 tokens
- Throughput: ~10-20 tokens/sec
- RAM: 2.5GB (model) + 0.5GB (runtime) = 3GB total
- Battery: ~1% per 10 queries

**API (Sarvam AI):**
- Latency: 2-3 seconds for 50 tokens
- Cost: ₹0.10 per 1K tokens
- No RAM usage
- No battery impact

## Agentic Workflow Integration

For your web search agentic loops:

```dart
// Inner loop queries (use on-device)
final category = await hybridAI.chat(
  "Categorize this query: $userQuery",
  queryContext: QueryContext(
    isAgenticLoop: true,
    isInnerQuery: true,  // Forces local inference
  ),
);

// Web search (use API)
final searchResults = await hybridAI.chat(
  "Search for: $userQuery",
  queryContext: QueryContext(
    requiresWebAccess: true,  // Forces API
  ),
);

// Final answer generation (use API for accuracy)
final finalAnswer = await hybridAI.chat(
  "Generate answer based on: $searchResults",
  queryContext: QueryContext(
    requiresAccuracy: true,  // Forces API
  ),
);
```

## Monitoring

View hybrid stats in Settings screen:
```dart
final stats = hybridAI.getStats();
// Shows: local%, API%, fallback count, device capability
```

## Troubleshooting

**Model not loading:**
- Check file exists at path
- Check file size (should be ~2.5GB)
- Check device RAM (need 6GB+ total, 3GB+ free)

**Slow inference:**
- Reduce max_tokens (256 → 128)
- Reduce context window (2048 → 1024)
- Try quantized model (Q4_K_M → Q4_0)

**High memory usage:**
- Enable model unloading (automatic after 5 min idle)
- Reduce context window
- Clear conversation history

## Next Steps

1. **This weekend:** Test on your Oppo CPH2689
   - Download model
   - Run basic inference
   - Measure latency, battery, UX

2. **If successful:** Integrate into app
   - Add package dependencies
   - Complete model loading code
   - Deploy to test users

3. **Monitor:** Track local/API split
   - Target: 90% local, 10% API
   - Adjust router thresholds if needed

## Resources

- Phi-4 model: https://huggingface.co/microsoft/phi-4-gguf
- llama.cpp: https://github.com/ggerganov/llama.cpp
- llama_cpp_dart: https://pub.dev/packages/llama_cpp_dart
- Alternative: flutter_llama: https://pub.dev/packages/flutter_llama
