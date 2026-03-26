# 🔄 AI Provider Configuration Guide

WealthIn supports **seamless switching** between Groq and OpenAI using the **same OpenAI Python SDK**. Just change your API key and base URL!

---

## 🎯 Quick Start

### For Development/Testing (FREE) - Use Groq
```bash
./switch_ai_provider.sh groq
# Edit backend/.env and add your Groq API key
# Then start the backend
```

### For Finals/Demos (PAID) - Use OpenAI
```bash
./switch_ai_provider.sh openai
# Edit backend/.env and add your OpenAI API key
# Then start the backend
```

### Check Current Configuration
```bash
./switch_ai_provider.sh status
```

---

## 📋 How It Works

### The Magic: OpenAI-Compatible API

Both Groq and OpenAI use the **OpenAI API format**, so we use the same Python SDK:

```python
from openai import AsyncOpenAI

# For Groq
client = AsyncOpenAI(
    api_key="gsk_your_groq_key",
    base_url="https://api.groq.com/openai/v1"
)

# For OpenAI (just change the key!)
client = AsyncOpenAI(
    api_key="sk-your_openai_key"
    # base_url defaults to https://api.openai.com/v1
)
```

**Result**: Zero code changes needed! Just swap environment variables.

---

## 🔧 Environment Variables

### Option 1: Groq Configuration (Development)

```bash
# Required
OPENAI_API_KEY=gsk_your_groq_api_key_here
OPENAI_BASE_URL=https://api.groq.com/openai/v1
OPENAI_MODEL=llama-3.3-70b-versatile

# Optional: Fallback models
# OPENAI_MODEL=llama-3.3-70b-versatile,llama-3.1-70b-versatile,mixtral-8x7b-32768
```

**Groq Models Available**:
- `llama-3.3-70b-versatile` (Recommended - fastest)
- `llama-3.1-70b-versatile` (Fallback)
- `mixtral-8x7b-32768` (Fallback)
- `llama-3.1-8b-instant` (Ultra-fast, less capable)

**Get Groq API Key**: https://console.groq.com/keys

---

### Option 2: OpenAI Configuration (Finals)

```bash
# Required
OPENAI_API_KEY=sk-your_openai_api_key_here
# OPENAI_BASE_URL is NOT needed (uses default)
OPENAI_MODEL=gpt-4o-mini

# Optional: Use better models
# OPENAI_MODEL=gpt-4o          # Best quality, expensive
# OPENAI_MODEL=gpt-4-turbo     # Fast + quality, expensive
# OPENAI_MODEL=gpt-3.5-turbo   # Cheapest, less capable
```

**OpenAI Models Available**:
- `gpt-4o-mini` (Recommended - cheap, fast, good quality)
- `gpt-4o` (Best quality, most expensive)
- `gpt-4-turbo` (Fast + smart, expensive)
- `gpt-3.5-turbo` (Cheapest, basic tasks)

**Get OpenAI API Key**: https://platform.openai.com/api-keys

---

## 💰 Cost Comparison

| Provider | Model | Cost (Input) | Cost (Output) | Speed |
|----------|-------|--------------|---------------|-------|
| **Groq** | llama-3.3-70b | **FREE** | **FREE** | ⚡ 500+ tok/s |
| **Groq** | mixtral-8x7b | **FREE** | **FREE** | ⚡ 600+ tok/s |
| OpenAI | gpt-4o-mini | $0.15/1M | $0.60/1M | 🐢 50 tok/s |
| OpenAI | gpt-4o | $2.50/1M | $10.00/1M | 🐢 50 tok/s |
| OpenAI | gpt-3.5-turbo | $0.50/1M | $1.50/1M | 🏃 100 tok/s |

**Recommendation**:
- **Use Groq** for development/testing (free, fast)
- **Use OpenAI** only for finals/demos (paid, higher quality)

---

## 📝 Manual Configuration (Advanced)

If you want to manually configure instead of using the script:

### Step 1: Create `.env` file

```bash
cd backend
cp .env.groq.example .env
# OR
cp .env.openai.example .env
```

### Step 2: Edit `.env` and add your API key

For Groq:
```bash
OPENAI_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_BASE_URL=https://api.groq.com/openai/v1
OPENAI_MODEL=llama-3.3-70b-versatile
```

For OpenAI:
```bash
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# No OPENAI_BASE_URL needed
OPENAI_MODEL=gpt-4o-mini
```

### Step 3: Restart backend

```bash
cd backend
python -m uvicorn main:app --reload
```

---

## 🔍 Verify Configuration

### Check Status
```bash
./switch_ai_provider.sh status
```

**Expected Output (Groq)**:
```
================================================
Current AI Provider Configuration
================================================
🤖 Provider: GROQ (Development Mode)
📍 Base URL: https://api.groq.com/openai/v1

Model Configuration:
OPENAI_MODEL=llama-3.3-70b-versatile

API Key Status:
✅ OPENAI_API_KEY: Set (Groq)
================================================
```

**Expected Output (OpenAI)**:
```
================================================
Current AI Provider Configuration
================================================
🧠 Provider: OPENAI (Finals Mode - default)
📍 Base URL: https://api.openai.com/v1 (default)

Model Configuration:
OPENAI_MODEL=gpt-4o-mini

API Key Status:
✅ OPENAI_API_KEY: Set (OpenAI)
================================================
```

---

## 🧪 Test API Connection

### Test Groq
```bash
cd backend
python -c "
import asyncio
from services.groq_openai_service import groq_openai_service

async def test():
    await groq_openai_service.initialize()
    response = await groq_openai_service.chat([
        {'role': 'user', 'content': 'Say hello'}
    ])
    print(f'Provider: {groq_openai_service.provider_name}')
    print(f'Model: {groq_openai_service.last_model_used}')
    print(f'Response: {response[\"content\"]}')

asyncio.run(test())
"
```

**Expected Output**:
```
Provider: Groq
Model: llama-3.3-70b-versatile
Response: Hello! How can I help you today?
```

---

## 🚨 Troubleshooting

### Error: "OPENAI_API_KEY not set"

**Solution**: Make sure you've created `backend/.env` and added your API key.

```bash
cd backend
ls -la .env  # Should exist
cat .env | grep OPENAI_API_KEY  # Should show your key
```

---

### Error: "Invalid API key"

**For Groq**:
- Groq keys start with `gsk_`
- Get a new key at: https://console.groq.com/keys

**For OpenAI**:
- OpenAI keys start with `sk-`
- Get a new key at: https://platform.openai.com/api-keys

---

### Error: "Model not found"

**For Groq**:
- Check available models: https://console.groq.com/docs/models
- Use: `llama-3.3-70b-versatile` (not `llama3.3` or `llama-3`)

**For OpenAI**:
- Use: `gpt-4o-mini` (not `gpt-4-mini` or `gpt4o`)

---

### Response is slow

**For Groq**:
- Should be <1 second. If slow, check internet connection.

**For OpenAI**:
- Expected: 3-10 seconds for typical responses.
- Switch to `gpt-3.5-turbo` for faster responses.

---

## 🎬 Finals Preparation Checklist

Before your final demonstration:

```bash
# 1. Switch to OpenAI
./switch_ai_provider.sh openai

# 2. Add your OpenAI API key
nano backend/.env
# Set: OPENAI_API_KEY=sk-your_key_here

# 3. Choose model (recommend gpt-4o-mini for cost)
# In backend/.env:
# OPENAI_MODEL=gpt-4o-mini

# 4. Verify configuration
./switch_ai_provider.sh status

# 5. Test API connection
cd backend
python -c "import asyncio; from services.groq_openai_service import groq_openai_service; asyncio.run(groq_openai_service.initialize()); print('✅ OpenAI configured correctly' if groq_openai_service.is_available else '❌ Check your API key')"

# 6. Start backend
python -m uvicorn main:app --reload --port 8000

# 7. Test in app
# Open app → Ideas section → Ask AI a question
# Should see response from OpenAI in 3-5 seconds

# 8. Monitor usage (important!)
# https://platform.openai.com/usage
```

---

## 💡 Pro Tips

### 1. Cost Management
```bash
# Add to backend/.env to track spending
OPENAI_BUDGET_ALERT=10.00
OPENAI_HARD_LIMIT=50.00
```

### 2. Use Groq for Testing
- Develop entire app with Groq (free)
- Switch to OpenAI only for final demo
- **Saves $$$ during development**

### 3. Model Fallback
```bash
# If primary model fails, tries next
OPENAI_MODEL=gpt-4o-mini,gpt-3.5-turbo
```

### 4. Check API Status
- Groq Status: https://status.groq.com/
- OpenAI Status: https://status.openai.com/

---

## 📊 Which Provider Should I Use?

| Scenario | Provider | Model | Reason |
|----------|----------|-------|--------|
| **Development** | Groq | llama-3.3-70b | Free, fast |
| **Testing** | Groq | llama-3.3-70b | Free, fast |
| **Debugging** | Groq | llama-3.3-70b | Free, fast |
| **Finals Demo** | OpenAI | gpt-4o-mini | Professional, reliable |
| **Hackathon Pitch** | OpenAI | gpt-4o | Best quality |
| **Production (budget)** | Groq | llama-3.3-70b | Free tier |
| **Production (quality)** | OpenAI | gpt-4o-mini | Paid but cheap |

---

## 🔐 Security Notes

1. **Never commit `.env` files** - Already in `.gitignore`
2. **Rotate API keys** after demos if shared publicly
3. **Monitor usage** - Set billing alerts on both platforms
4. **Use environment variables** - Never hardcode keys in source code

---

## 📚 Additional Resources

- **Groq Documentation**: https://console.groq.com/docs
- **OpenAI Documentation**: https://platform.openai.com/docs
- **OpenAI Pricing**: https://openai.com/api/pricing/
- **Groq Pricing**: FREE (with rate limits)

---

**Status**: ✅ Unified OpenAI-compatible configuration ready  
**Flexibility**: Switch providers in <30 seconds  
**Cost Savings**: Use free Groq for 90% of development  
**Last Updated**: February 13, 2026
