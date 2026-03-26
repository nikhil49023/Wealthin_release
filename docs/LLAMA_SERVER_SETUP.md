# LlamaServer Setup & Testing Guide

## Quick Start (TL;DR)

Once llama.cpp is built:

```bash
# 1. Start the server with TinyLlama model (auto-downloads)
cd /tmp/llama.cpp
./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M

# 2. In another terminal, check if server is ready (wait for "listening on http://127.0.0.1:8000")
curl http://localhost:8000/health

# 3. Restart the Flutter app on your device
flutter run
```

## Detailed Setup

### Step 1: llama.cpp Building Status

The build is happening in `/tmp/llama.cpp` and should finish in 5-15 minutes depending on CPU.

Check build progress:
```bash
ps aux | grep cmake
# or
tail -f  /tmp/llama.cpp/build.log 2>/dev/null || echo "No log yet"
```

### Step 2: Run LlamaServer

Once the build completes:

```bash
cd /tmp/llama.cpp

# Start server with TinyLlama 1.1B model
# The -hf flag auto-downloads from Hugging Face
./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M

# Expected output:
# server listening on http://127.0.0.1:8000
# loading model from...
# llm_load_tensors...
# ggml_cuda_init...
# [LLM] ready!
```

The server will:
- Download the model (first run only): ~2-3 minutes
- Load into memory: ~30 seconds
- Start listening on port 8000

You'll see:
```
server listening on http://127.0.0.1:8000
```

### Step 3: Verify Server is Working

In another terminal:

```bash
# Test the health endpoint
curl http://localhost:8000/health
# Response: {"status":"ok"}

# Test inference (should return JSON with response)
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "What is SIP?"}],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

### Step 4: Run Flutter App

```bash
# Terminal 1: Keep LlamaServer running
cd /tmp/llama.cpp
./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M

# Terminal 2: Rebuild and run Flutter app
cd /media/nikhil/f470dc98-92e4-4f7d-af60-1bfe0fc74e041/Wealthin_release/frontend/wealthin_flutter
flutter run --release
```

### Step 5: Test in App

Once the app restarts:
1. Open "AI Advisor" tab
2. Send a message: "What is budgeting?"
3. You should see response from **LlamaServer** (logs will show "local (LlamaServer)")
4. Response should come from TinyLlama model

## Network Setup (Advanced)

If running on local network (phone on different machine):

1. Find your computer's IP:
   ```bash
   hostname -I | awk '{print $1}'  # Linux
   # or
   ipconfig getifaddr en0  # macOS
   ```

2. Start server on all interfaces:
   ```bash
   ./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M --host 0.0.0.0
   ```

3. In Flutter app initialization, set custom address:
   ```dart
   hybridAI.setLlamaServerAddress('http://192.168.1.100:8000');
   ```

## Monitoring

Watch logs while app runs:

```bash
# Terminal 3: See Android app logs
adb logcat | grep -E "LlamaServer|HybridAI|chat_screen"
```

You'll see patterns like:
```
[LlamaServer] Query: "What are mutual funds?"
[LlamaServer] ✓ Generated 234 characters
[HybridAI] ✓ LlamaServer completed in 2340ms
```

## Troubleshooting

### LlamaServer says "Server not responding"

**Problem:** App shows "LlamaServer not available at http://localhost:8000"

**Solution:**
1. Is the server running?
   ```bash
   curl http://localhost:8000/health
   ```
   If no response, start the server again.

2. Is it still downloading/loading?
   - First run takes 2-3 minutes to download the model
   - Check if you see "listening on http://127.0.0.1:8000" in terminal

3. Port conflict?
   ```bash
   lsof -i :8000  # See what's using port 8000
   ```

### Slow responses (>5 seconds)

**Problem:** Responses take too long

**Solution:**
- First response takes longer (model warming up) - this is normal
- Subsequent responses should be 1-3 seconds
- TinyLlama 1.1B is slower than cloud API (~2s vs ~1s)
- Normal for CPU inference

### "Out of memory" errors

**Problem:** Server crashes with OutOfMemory

**Solution:**
- TinyLlama needs ~4GB RAM
- Check available RAM: `free -h`
- Kill other processes if needed

### Android app can't reach server

**Problem:** App on phone shows LlamaServer not available, but `curl` from dev machine works

**Solution:**
1. Make sure server listens on all IPs:
   ```bash
   pkill llama-server  # Stop current
   ./build/bin/llama-server --host 0.0.0.0 -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M
   ```

2. Set correct IP in Flutter code:
   ```dart
   hybridAI.setLlamaServerAddress('http://YOUR_COMPUTER_IP:8000');
   ```

3. Check firewall:
   ```bash
   sudo ufw allow 8000  # Linux
   # macOS: System Preferences → Security & Privacy → Firewall
   ```

## What to Expect

### Speed Comparison
- **LlamaServer (TinyLlama):** 1-3 seconds per response
- **API (Sarvam):** 0.5-1.5 seconds per response
- **Cache:** 0ms (instant)

### Quality
- TinyLlama is smaller, faster, but less accurate
- Good for common financial questions
- May struggle with complex advice

### Costs
- **LlamaServer local:** $0 (free, runs on your machine)
- **Sarvam API:** ~₹1/query at scale
- **Combined hybrid:** Best of both (fast local + fallback for complex)

## Next: Switching Modes

Once you've tested LlamaServer, you can switch modes:

```dart
// In debug console or app settings:
hybridAI.useAPIOnly();          // Use only Sarvam API
hybridAI.useLocalOnly();        // Use only LlamaServer (no fallback)
hybridAI.useLocalFirst();       // LlamaServer first, API fallback (default)
```

Check stats in app:
```dart
print(hybridAI.getStats());
// Shows: llama_server_queries, local_queries, api_queries, cache_hits
```

## Model Alternatives

TinyLlama 1.1B is balanced. To try others:

```bash
# Faster but lower quality (400MB)
./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q2_K

# Better quality but slower (7GB, slower on CPU)
./build/bin/llama-server -hf TheBloke/Mistral-7B-Instruct-v0.2-GGUF:Q4_K_M

# Check available quantizations:
# https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
# https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF
```

## Build Progress

Current status:
- ✅ llama.cpp cloned
- ✅ CMake configured
- ⏳ Building llama-server (5-15 min remaining)
- ⏳ Flutter app building (rebuilding with new services)

Check build logs:
```bash
ps aux | grep -E "cmake|flutter"
```

Once both complete, you can start testing!
