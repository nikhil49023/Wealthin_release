# WealthIn v2.4.0 — Wealth Creation Rebrand & DPR Fix

## 🏷️ Full App Rebrand — Wealth Creation & Financial Planner
- **Splash screen tagline** updated from "MSME Finance Copilot" → "Wealth Creation & Financial Planner"
- **AI Advisor welcome** rewritten from MSME business focus → personal finance, wealth building, investment, budgeting, and government schemes
- **Ideas (Brainstorm) modes** — "MSME Copilot" → "Wealth Planner" with updated descriptions, starter prompts, and encouragement facts
- **Personas** rebranded — "Strategy Consultant" → "Wealth Advisor", "Critical Investor" → "Risk Analyst", "Financial Analyst" → "Investment Analyst"
- **System prompts** — AI now positions as a personal finance mentor for all Indians, covering SIPs, mutual funds, PPF, NPS, tax planning, insurance, goal-based saving
- **Starter prompts** shifted from MSME/DPR/loan focused → savings plans, investment options, home buying, emergency funds
- **Facts/encouragement** — MSME stats replaced with wealth creation & financial literacy facts
- **Badge labels** — "Copilot" → "WealthIn", "MSME" → "Gov"
- **Government services** — generalized "MSME" references to broader "Government Services"
- **API key naming** — "GOV_MSME_API_KEY" → "GOV_API_KEY"

## 🔧 DPR (Detailed Project Report) Flow Fixes
- **Clipboard copy fixed** — DPR editor's "Copy all text" button now actually copies to clipboard (was only showing snackbar)
- **Fallback template** — When Python bridge fails, DPR now shows a complete 10-section editable template instead of empty document
- **Tool description** updated — DPR generation now described for "loan applications and financial planning" (not MSME-only)
- **Section schema** — `msme_category` → `enterprise_category`, `msme_schemes` → `applicable_schemes`

## 📊 Finance Hub — Auto-refresh After Import
- **Tab refresh on import** — Finance Hub tabs now auto-refresh after importing transactions via the import dialog
- **ValueKey pattern** — Used `_refreshKey` counter with `ValueKey` to force tab widget rebuild
- **Added `super.key`** to all tab content widgets for proper key propagation

## 🐍 Python Bridge Updates
- Mode detection updated to include `wealth_planner` alongside legacy `msme_copilot`
- Brainstorm system prompt rebranded to personal finance mentor
- Response formatting examples use savings/SIP/emergency fund metrics instead of business revenue/break-even
- DPR workflow instructions kept intact but rebranded

## Previous: v2.3.0 — Premium UI & Stability Release

### Premium Ideas Rendering
- Ported AI Advisor's rich rendering engine to Ideas section
- Gradient headers, visual timelines, emerald bullets, tip boxes, metric cards
- Smooth fade+slide animations

### Import Dialog Fix
- `_isSaving` guard prevents double saves
- Background budget sync after dialog close
- Fixed Navigator crash on async gaps
