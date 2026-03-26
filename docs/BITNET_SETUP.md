# BitNet Local Inference - Android Integration

## Overview

This guide explains how to run **1-bit quantized LLMs** locally on Android using **bitnet.cpp**.

### Why BitNet vs llama.cpp?

| Feature | llama.cpp (4-bit) | bitnet.cpp (1-bit) |
|---------|------------------|-------------------|
| Memory | 2-4 GB | **500 MB - 1 GB** |
| Speed | 10-20 tok/s | **20-40 tok/s** |
| Heating | High 🔥🔥🔥 | **Low 🔥** |
| Battery | High drain | **Lower drain** |
| Quality | Better | Good for simple tasks |

## Prerequisites

1. **Android NDK** (v25 or later)
   ```bash
   # Install via Android Studio: Tools > SDK Manager > SDK Tools > NDK
   export ANDROID_NDK_HOME=~/Android/Sdk/ndk/25.1.8937393
   ```

2. **CMake 3.22+**
   ```bash
   # Install via Android Studio: Tools > SDK Manager > SDK Tools > CMake
   ```

3. **Git**
   ```bash
   sudo apt install git
   ```

## Quick Setup (Automated)

Run the setup script:

```bash
cd /media/nikhil/f470dc98-92e4-4f7d-af60-1bfe0fc74e041/Wealthin_release
chmod +x setup_bitnet.sh
./setup_bitnet.sh
```

## Manual Setup

### Step 1: Clone BitNet Repository

```bash
cd frontend/wealthin_flutter/android/app/src/main/cpp
git clone https://github.com/microsoft/BitNet.git bitnet-cpp
```

### Step 2: Download Model

```bash
# Create model directory
mkdir -p frontend/wealthin_flutter/android/app/src/main/assets/models

# Download 1-bit quantized model (~500MB)
cd frontend/wealthin_flutter/android/app/src/main/assets/models

# Option A: BitNet-b1.58-3B (recommended)
curl -L -o bitnet-b1.58-3b.gguf \
  "https://huggingface.co/1bitLLM/bitnet_b1_58-3B/resolve/main/ggml-model-i2_s.gguf"

# Option B: Smaller model for testing (faster download)
curl -L -o bitnet-small.gguf \
  "https://huggingface.co/1bitLLM/bitnet_b1_58-large/resolve/main/ggml-model-i2_s.gguf"
```

### Step 3: Build Native Library

#### Option A: Let Gradle Build (Automatic)

Flutter/Gradle will automatically compile native code when building:

```bash
cd frontend/wealthin_flutter
flutter clean
flutter pub get
flutter build apk --release
```

#### Option B: Manual NDK Build

If automatic build fails:

```bash
cd frontend/wealthin_flutter/android/app/src/main/cpp/bitnet-cpp

# Create build directory
mkdir -p build && cd build

# Configure with CMake
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_NATIVE_API_LEVEL=26 \
  -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc)

# Copy to jniLibs
mkdir -p ../../jniLibs/arm64-v8a
cp libbitnet.so ../../jniLibs/arm64-v8a/
```

### Step 4: Install Dependencies

```bash
cd frontend/wealthin_flutter
flutter pub get
```

### Step 5: Build & Test

```bash
# Build release APK
flutter build apk --release

# Install on device
flutter install

# Or run directly
flutter run --release
```

## File Structure

```
frontend/wealthin_flutter/
├── android/app/src/main/
│   ├── cpp/
│   │   ├── CMakeLists.txt          # Native build config
│   │   ├── bitnet_jni.cpp          # JNI wrapper
│   │   └── bitnet-cpp/             # BitNet source (cloned)
│   ├── kotlin/.../
│   │   └── BitNetBridge.kt         # Kotlin JNI bridge
│   ├── jniLibs/
│   │   └── arm64-v8a/
│   │       └── libbitnet.so        # Compiled library
│   └── assets/models/
│       └── bitnet-b1.58-3b.gguf    # Downloaded model
├── lib/core/services/
│   ├── bitnet_inference_service.dart  # Flutter service
│   ├── hybrid_ai_service.dart         # Orchestrator
│   └── query_router.dart              # Routing logic
```

## Usage in Code

### Basic Usage

```dart
import 'package:wealthin_flutter/core/services/bitnet_inference_service.dart';

// Initialize
await bitnetInference.initialize();

// Generate
final response = await bitnetInference.generate(
  "What is SIP?",
  maxTokens: 128,
  temperature: 0.7,
);
print(response);
```

### With Hybrid Service (Recommended)

```dart
import 'package:wealthin_flutter/core/services/hybrid_ai_service.dart';

// Initialize
await hybridAI.initialize();

// Chat - automatically routes to local or API
final response = await hybridAI.chat(
  "What is SIP?",
  userId: "user123",
);
print(response.response);
print("Mode: ${response.inferenceMode}"); // 'local', 'api', or 'cache'
```

## Testing

### Test Local Inference

```dart
// Test if BitNet is ready
final info = bitnetInference.getModelInfo();
print("Model loaded: ${info['model_loaded']}");
print("Quantization: ${info['quantization']}");

// Run test inference
if (bitnetInference.isReady) {
  final response = await bitnetInference.generate(
    "Category: mutual fund investment",
    maxTokens: 10,
  );
  print("Response: $response");
}
```

### Test Hybrid Routing

Use the test screen:
```
lib/features/ai_advisor/hybrid_ai_test_screen.dart
```

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Load time | < 5s | First load only |
| Inference | < 2s | For 50 tokens |
| Memory | < 1 GB | Model + runtime |
| Heating | Minimal | 1-bit = less compute |
| Battery | < 1%/10 queries | Estimated |

## Troubleshooting

### "UnsatisfiedLinkError: libbitnet.so not found"

**Cause:** Native library not compiled or not in jniLibs.

**Fix:**
```bash
# Option 1: Rebuild with Gradle
cd frontend/wealthin_flutter
flutter clean && flutter build apk --release

# Option 2: Manual build
cd android/app/src/main/cpp/bitnet-cpp
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a
make -j4
cp libbitnet.so ../../jniLibs/arm64-v8a/
```

### "Model file not found"

**Cause:** Model not downloaded or wrong path.

**Fix:**
```bash
# Check model exists
ls -la android/app/src/main/assets/models/

# Download if missing
curl -L -o android/app/src/main/assets/models/bitnet-b1.58-3b.gguf \
  "https://huggingface.co/1bitLLM/bitnet_b1_58-3B/resolve/main/ggml-model-i2_s.gguf"
```

### "CMake Error"

**Cause:** Missing NDK or wrong version.

**Fix:**
```bash
# Check NDK
echo $ANDROID_NDK_HOME
ls $ANDROID_NDK_HOME

# Install NDK via Android Studio
# Tools > SDK Manager > SDK Tools > NDK (Side by side)
```

### "Phone still heating up"

**Cause:** Model too large or continuous inference.

**Fix:**
1. Use smaller model (BitNet-large instead of 3B)
2. Reduce max_tokens (128 → 64)
3. Add cooldown between queries
4. Use hybrid mode (most queries to API)

## Current Status

### ✅ Implemented
- BitNet inference service (Dart)
- JNI wrapper (C++)
- Kotlin bridge
- CMake configuration
- Hybrid service integration
- Query routing

### ⏳ TODO
- [ ] Complete actual bitnet.cpp integration
- [ ] Test model loading on device
- [ ] Benchmark performance
- [ ] Optimize memory usage
- [ ] Add model download in-app

### ⚠️ Mock Mode
Currently returns mock responses until native library is compiled.
The infrastructure is ready - just needs bitnet.cpp compilation.

## Next Steps

1. **Today**: Run `./setup_bitnet.sh` to download BitNet and model
2. **Build**: `flutter build apk --release`
3. **Test**: Install on your Oppo CPH2689
4. **Monitor**: Check heating, latency, battery
5. **If heating occurs**: Use hybrid mode with more API calls

## Resources

- [BitNet Paper](https://arxiv.org/abs/2310.11453)
- [BitNet GitHub](https://github.com/microsoft/BitNet)
- [1-bit LLM Models](https://huggingface.co/1bitLLM)
- [Android NDK Guide](https://developer.android.com/ndk/guides)
