# On-Device Server Production Setup

This guide makes the current app architecture production-safe while keeping local inference possible.

## 1. Which models can you use?

Yes, you can use:
- Sarvam models (for cloud/API path) by setting `SARVAM_CHAT_MODEL`.
- Any GGUF model with `llama-server` (local server path), including Indian/fine-tuned open models, as long as they run on mobile hardware.

Examples (verify exact model IDs in provider docs):
- Sarvam: set `--dart-define=SARVAM_CHAT_MODEL=<model-id>`
- GGUF local: `BharatGPT`, `Indic` or other Indian open-source variants if available in GGUF format.

## 2. Production-safe defaults in app

The app is configured to be safe for release:
- Routing defaults to API-first.
- Local `llama-server` is used automatically when reachable.
- Placeholder BitNet fallback is disabled unless explicitly enabled.

Build-time toggles:
- `LOCAL_LLM_SERVER_URL` (default: `http://localhost:8000`)
- `ENABLE_BITNET_FALLBACK` (default: `false`)
- `SARVAM_CHAT_MODEL` (default from app config)

## 3. Build command for production APK/AAB

Use your production values:

```bash
cd frontend/wealthin_flutter
flutter build appbundle --release \
  --dart-define=SARVAM_API_KEY=sk_xxx \
  --dart-define=SARVAM_CHAT_MODEL=sarvam-m \
  --dart-define=LOCAL_LLM_SERVER_URL=http://127.0.0.1:8000 \
  --dart-define=ENABLE_BITNET_FALLBACK=false
```

## 4. On-device llama-server setup (Android via Termux)

This is optional. If not available, app falls back to Sarvam.

### Step A: Install Termux and packages

```bash
pkg update -y
pkg install -y git cmake clang make python wget
```

### Step B: Build llama.cpp on device

```bash
cd ~
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build -j$(nproc) --target llama-server
```

### Step C: Download a GGUF model to phone storage

```bash
mkdir -p ~/models
cd ~/models
# Example only: replace with your chosen model URL
wget -O model.gguf "<GGUF_DOWNLOAD_URL>"
```

### Step D: Start on-device server

```bash
~/llama.cpp/build/bin/llama-server \
  -m ~/models/model.gguf \
  --host 127.0.0.1 \
  --port 8000 \
  -c 2048 \
  -t $(nproc)
```

When this server is running on the same device, app local inference works at `http://127.0.0.1:8000`.

## 5. Notes for Indian models

- If model supports OpenAI-compatible tool-calling natively, you still need app-side orchestration for reliability.
- Prefer quantized GGUF variants (`Q4_K_M`, `Q5_K_M`) for mobile.
- Test memory/latency on low-end devices before broad rollout.

## 6. Recommended rollout strategy

1. Release with API-first + local optional.
2. Enable local only for internal/test channels first.
3. Track latency, failures, and fallback rates.
4. Expand to production cohorts after stability targets are met.
