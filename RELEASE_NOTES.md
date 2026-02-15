# WealthIn v2.2.2 - AI Engine Reliability Fix

## 🔧 Critical Fixes

### AI API Key Configuration
- **Fixed missing Sarvam AI key** — Sarvam fallback was completely non-functional due to missing API key configuration
- **Fixed API key race condition** — Keys were being injected using synchronous getters before secure storage finished loading, sending empty strings to the Python bridge
- **Fixed 13+ code paths bypassing key injection** — Many screens (Brainstorm, Analysis, Deep Research) called the Python bridge directly without ensuring API keys were configured

### AI Model Resilience
- **Added Groq model fallback chain** — If the primary model (`openai/gpt-oss-20b`) fails due to rate limits or errors, the system now automatically tries `llama-3.3-70b-versatile` → `llama-3.1-8b-instant` → `mixtral-8x7b-32768`
- **Added 2-second retry delay on 429 rate limits** before trying the next model
- **Increased Groq API timeout** from 30s to 45s for complex prompts

### Sarvam AI Integration
- **Fixed Sarvam urllib fallback** — Improved error logging with HTTP status codes and error bodies
- **Added proper error separation** — HTTPError vs generic exceptions now logged independently for better debugging

## 🔍 Diagnostic Improvements
- `set_config()` now logs which AI providers are active (key lengths only — never actual values)
- `PythonBridgeService.setConfig()` logs key injection status
- `AIAgentService` logs key status on initialization (✓/✗ for each provider)

## 🏗️ Architecture Improvements
- `PythonBridgeService.ensureConfigured()` — Safety net that auto-injects keys before any LLM call, regardless of which screen initiates it
- `AIAgentService.reinjectKeys()` — Public method for re-injecting keys after user changes them in Settings
- Async key getters ensure secure storage is fully loaded before reading keys
