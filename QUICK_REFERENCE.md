# Quick Reference: Local LlamaServer Setup

## What's Happening Right Now ⏳

- **llama.cpp:** Building llama-server executable (5-15 min)
- **Flutter:** Rebuilding app with new LlamaServer service (3-5 min)
- **Combined ETA:** 15-20 minutes total

## When Builds Finish ✅

You'll have:
```
/tmp/llama.cpp/build/bin/llama-server    ← The server executable
/tmp/llama.cpp/build/bin/llama-cli       ← Optional CLI tool
~/flutter_app_rebuilt.apk                ← Updated app with new services
```

## The Commands You'll Run

**Terminal 1 - Start LlamaServer (keep running):**
```bash
cd /tmp/llama.cpp
./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M
```

**Terminal 2 - Monitor Android logs:**
```bash
adb logcat | grep -E "LlamaServer|HybridAI"
```

**Terminal 3 - Restart Flutter app:**
```bash
cd ~/Wealthin_release/frontend/wealthin_flutter
flutter run  # Or press 'r' if already running
```

## What You'll See

### In LlamaServer Terminal:
```
server listening on http://127.0.0.1:8000
loading model from hf://TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M
[model download starting...]
[model loaded - ready for inference]
[POST /v1/chat/completions - 2100ms]
[POST /v1/chat/completions - 1800ms]
```

### In Flutter App:
**Message:** "What is mutual fund?"

**Response (from TinyLlama):**
```
A mutual fund is a pooled investment...
[showing: local (LlamaServer)]
```

### In ADB Logs:
```
[HybridAI] → Using LlamaServer (local inference)
[LlamaServer] ✓ Generated 234 characters
[HybridAI] ✓ LlamaServer completed in 1850ms
```

## Architecture You Just Set Up

```
Your Phone → Flask App → LlamaServer → TinyLlama Model
                         (localhost:8000)   (500MB, runs on your PC)

No API costs!
Instant availability!
100% privacy!
```

## If Something Goes Wrong

| Problem | Quick Fix |
|---------|-----------|
| "Server not available" | `curl localhost:8000/health` - is server running? |
| App slow | First response is slow (model warming up) - normal |
| "Out of memory" | Need ~4GB RAM for TinyLlama - close other apps |
| Build fails | `flutter clean && flutter pub get && flutter run` |

## Files You'll Need

- `LLAMA_SERVER_SETUP.md` - Full setup guide with troubleshooting
- `STATUS_REPORT.md` - Detailed implementation report
- `LLAMA_SERVER_SETUP.md` - Everything you need to know

## Timeline

```
Now (00:00)     ⏳ Builds in progress
+10 min (10:00) ✅ Builds done, ready to start server
+15 min (15:00) ⏳ Model downloading (first time only)
+17 min (17:00) ✅ Server ready, app can connect
+20 min (20:00) ✅ EVERYTHING WORKING - model inference in app!

Total wait time: ~20 minutes from now
```

## Success Criteria

You'll know it's working when:

✅ LlamaServer console shows "listening on http://127.0.0.1:8000"
✅ ADB logs show "[LlamaServer] ✓ Generated X characters"
✅ App response shows "(local (LlamaServer))" footer
✅ Response comes in 1-3 seconds (not 0.5s API, not 5s first time)

## Next Phase After Testing

Once working, you can:
1. **Measure performance:** `hybridAI.getStats()` shows % of queries went local
2. **Test different modes:** `hybridAI.useAPIOnly()`, `hybridAI.useLocalFirst()`
3. **Try other models:** Download other GGUF quantizations
4. **Network setup:** Run on different machines with `--host 0.0.0.0`

## Commands for Monitoring

```bash
# Check if llama build is done
ls -lh /tmp/llama.cpp/build/bin/llama-server

# Check if Flutter build is done
flutter logs | grep "flutter:"

# Start server once builds done
cd /tmp/llama.cpp && ./build/bin/llama-server -hf TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:Q4_K_M

# Test server from another terminal
curl http://localhost:8000/health

# Watch app logs
adb logcat -s "flutter" | grep -E "LlamaServer|HybridAI|chat"
```

---

**Come back here after builds finish and follow the "Commands You'll Run" section!**
