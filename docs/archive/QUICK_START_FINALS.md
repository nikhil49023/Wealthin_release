# 🎯 Quick Start Guide for Finals

**For finals demonstration, follow these exact steps:**

---

## ⚡ 30-Second Setup

```bash
# 1. Switch to OpenAI
./switch_ai_provider.sh openai

# 2. Add your OpenAI API key
nano backend/.env
# Set: OPENAI_API_KEY=sk-your_key_here
# Set: OPENAI_MODEL=gpt-4o-mini

# 3. Verify configuration
./switch_ai_provider.sh status
# Should show: "Provider: OPENAI (Finals Mode)"

# 4. Start backend
cd backend && python -m uvicorn main:app --reload --port 8000

# 5. Start Android app (new terminal)
cd frontend/wealthin_flutter
flutter run
```

---

## 🎬 For Demonstration

### What You'll Show

1. **Transaction Management**
   - Auto SMS parsing (show 300+ transactions imported)
   - Budget tracking with alerts
   - Financial health dashboard

2. **AI Business Advisor**
   - Ask: "Help me start a boutique business"
   - Shows OpenAI GPT-4o-mini response
   - 3 specialized modes: Strategic Planner, Financial Architect, Execution Coach

3. **DPR Generation**
   - Section-by-section generation
   - Milestone scoring (shows 78.5% completeness)
   - Export to bank-ready PDF

---

## 🔑 OpenAI Configuration

**What the judges will see:**

```
Provider: OpenAI GPT-4o-mini
Response time: ~3-5 seconds (normal for OpenAI)
Quality: Professional, bank-ready content
Cost: ~$0.001 per request (very cheap)
```

**Why this matters:**
- ✅ Professional quality responses
- ✅ Reliable (99.9% uptime)
- ✅ Judges recognize OpenAI brand
- ✅ Shows you can use production APIs

---

## 💰 Cost During Demo

**Estimated cost for 30-minute demo:**

- 20 AI queries × $0.001 = **$0.02 total**
- Budget needed: **$5-10** (safe buffer)

**Monitor usage:**
https://platform.openai.com/usage

---

## 🚨 Emergency Backup Plan

**If OpenAI fails during demo:**

```bash
# Switch back to Groq (free, instant)
./switch_ai_provider.sh groq
nano backend/.env
# Add your Groq key
# Restart backend
```

Groq is 10x faster and free!

---

## ✅ Pre-Demo Checklist

```bash
# [ ] OpenAI API key added to backend/.env
# [ ] OpenAI account has credit ($5+ balance)
# [ ] Tested AI chat (got response in 3-5 seconds)
# [ ] Backend running on port 8000
# [ ] Frontend connected to backend
# [ ] APK built and installed on demo device
# [ ] Demo script prepared
# [ ] Backup Groq key ready (just in case)
```

---

## 📊 What Makes This Special

**Unified AI Architecture:**
- Same codebase works with Groq OR OpenAI
- Switch providers in 30 seconds
- No code changes needed
- Just swap the API key

**Development Strategy:**
- 90% development: Groq (free, fast)
- Finals demo: OpenAI (professional)
- **Result**: Save $$$ during dev, quality for demo

---

## 🎤 Demo Script Suggestion

```
"Let me show you WealthIn's AI-powered business advisor.

[Open Ideas section]

I'll ask the AI: 'Help me start a handmade jewelry boutique'

[AI responds in 3-5 seconds using OpenAI GPT-4o-mini]

Notice how the AI provides:
✅ Market analysis with real data
✅ Cost breakdown and pricing
✅ Step-by-step recommendations

Now let me generate a bank-ready DPR...

[Show section-by-section generation]
[Show milestone scoring: 78.5% complete]
[Export to PDF]

This DPR is ready to submit to banks for loan approval."
```

---

## 🔗 Important Links

- **OpenAI Dashboard**: https://platform.openai.com/
- **Usage Monitoring**: https://platform.openai.com/usage
- **API Keys**: https://platform.openai.com/api-keys
- **Status Page**: https://status.openai.com/

---

**Status**: ✅ Ready for finals  
**Total Setup Time**: 30 seconds  
**Cost**: <$1 for entire demo  
**Backup Plan**: Groq (free) if needed
