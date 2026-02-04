# WealthIn v2 - Complete Implementation Plan

**Created:** 2026-01-30
**Status:** Active Development
**Last Updated:** 2026-01-30T09:53:45+05:30

---

## 📋 Executive Summary

This plan outlines the systematic completion of WealthIn v2's remaining features, prioritizing **critical technical tasks** that form the foundation for future enhancements. The work is organized into 3 phases with clear dependencies.

---

## 🎯 Phase 1: Critical Technical Tasks (Priority: HIGH)

### Task 1.1: AI Tools Integration ✅ (Partially Complete)
**Status:** 70% complete - Service exists, needs endpoint wiring
**Estimated Time:** 2-3 hours

#### Current State:
- ✅ `AIToolsService` exists with full function implementations
- ✅ `AiAdvisorEndpoint` has `askWithTools()`, `previewAction()`, `confirmAction()`
- ⚠️ Frontend Chat UI doesn't render action cards properly
- ⚠️ Confirmation flow not connected end-to-end

#### Tasks:
- [ ] **1.1.1** Wire `askAdvisorStructured()` to return action cards in proper format
- [ ] **1.1.2** Update Flutter `ai_advisor_screen.dart` to render ActionCard widgets
- [ ] **1.1.3** Implement confirmation dialog for actions (Budget, Goal, Payment)
- [ ] **1.1.4** Connect "Confirm" button to `confirmAction()` endpoint
- [ ] **1.1.5** Test end-to-end: "Create a ₹5000 food budget" → Card → Confirm → DB

#### Files to Modify:
```
wealthin_server/lib/src/endpoints/ai_advisor_endpoint.dart
wealthin_flutter/lib/features/ai_advisor/ai_advisor_screen.dart
wealthin_flutter/lib/features/ai_advisor/widgets/action_card.dart (NEW)
```

---

### Task 1.2: PDF Extraction Enhancement
**Status:** 60% complete - Basic extraction works, needs LLM structuring
**Estimated Time:** 3-4 hours

#### Current State:
- ✅ Python sidecar extracts raw text from PDFs (`pdfplumber`)
- ✅ `/transactions/extract-text` returns prompts for LLM
- ⚠️ Serverpod doesn't call LLM with extracted text
- ⚠️ Response isn't parsed back to transactions

#### Tasks:
- [ ] **1.2.1** In `TransactionImportEndpoint`, call Python sidecar's `/transactions/extract-text`
- [ ] **1.2.2** Send extracted prompts to Zoho LLM (already integrated)
- [ ] **1.2.3** Parse LLM JSON response into `Transaction` objects
- [ ] **1.2.4** Add batch insert to database with duplicate detection
- [ ] **1.2.5** Return success/failure count to Flutter

#### Files to Modify:
```
wealthin_server/lib/src/endpoints/transaction_import_endpoint.dart
wealthin_flutter/lib/features/transactions/import_dialog.dart
```

---

### Task 1.3: User Authentication (Foundation)
**Status:** 20% complete - Serverpod auth scaffolding exists
**Estimated Time:** 4-5 hours

#### Current State:
- ✅ `EmailIdpEndpoint` extends Serverpod's auth base
- ⚠️ All endpoints use hardcoded `userId = 1`
- ⚠️ No login/register screens in Flutter
- ⚠️ No session management

#### Tasks:
- [ ] **1.3.1** Create `AuthScreen` in Flutter with email/password login
- [ ] **1.3.2** Create `RegisterScreen` with form validation
- [ ] **1.3.3** Implement `AuthProvider` state management
- [ ] **1.3.4** Update all endpoints to use `session.userId` from auth
- [ ] **1.3.5** Add route guards - redirect unauthenticated users to login
- [ ] **1.3.6** Store auth token securely (shared_preferences for web/desktop)

#### Files to Create/Modify:
```
wealthin_flutter/lib/features/auth/login_screen.dart (NEW)
wealthin_flutter/lib/features/auth/register_screen.dart (NEW)
wealthin_flutter/lib/core/providers/auth_provider.dart (NEW)
wealthin_flutter/lib/main.dart (add auth wrapper)
wealthin_server/lib/src/endpoints/*.dart (replace userId = 1)
```

---

## 🌟 Phase 2: Feature Enhancements (Priority: MEDIUM)

### Task 2.1: Voice Interaction
**Status:** Not started
**Estimated Time:** 4-5 hours
**Dependency:** Task 1.1 complete

#### Tasks:
- [ ] **2.1.1** Add `speech_to_text` package to Flutter
- [ ] **2.1.2** Create voice input button in AI Advisor chat
- [ ] **2.1.3** Add text-to-speech output option (via `flutter_tts` or Sarvam)
- [ ] **2.1.4** Handle Hindi voice input → Sarvam AI routing

#### Files to Create:
```
wealthin_flutter/lib/features/ai_advisor/widgets/voice_input_button.dart
wealthin_flutter/lib/core/services/speech_service.dart
```

---

### Task 2.2: Document Generator
**Status:** 10% - Models exist in Python sidecar
**Estimated Time:** 5-6 hours
**Dependency:** Task 1.2 complete

#### Tasks:
- [ ] **2.2.1** Create ReportLab templates for: Loan Application, Project Report, Invoice
- [ ] **2.2.2** Add `/documents/generate` endpoint to Python sidecar
- [ ] **2.2.3** Create Flutter UI for document type selection
- [ ] **2.2.4** AI-powered content drafting (user provides context, AI fills template)
- [ ] **2.2.5** PDF download/share functionality

#### Files to Create:
```
wealthin_python_sidecar/templates/ (document templates)
wealthin_server/lib/src/endpoints/document_endpoint.dart
wealthin_flutter/lib/features/documents/ (new feature module)
```

---

### Task 2.3: Dashboard AI Insights
**Status:** Model exists, not connected
**Estimated Time:** 2-3 hours
**Dependency:** Task 1.1 complete

#### Tasks:
- [ ] **2.3.1** Create `/insights/daily` endpoint in Python using `DailyInsight` model
- [ ] **2.3.2** Call from Dashboard on load (with 24h cache)
- [ ] **2.3.3** Design "FinBite" insight card with trend indicator
- [ ] **2.3.4** Add animations (slide in, pulse for important alerts)

#### Files to Modify:
```
wealthin_python_sidecar/main.py (add /insights/daily)
wealthin_flutter/lib/features/dashboard/dashboard_screen.dart
wealthin_flutter/lib/features/dashboard/widgets/finbite_card.dart (NEW)
```

---

### Task 2.4: Regional Localization
**Status:** Routing exists, UI not localized
**Estimated Time:** 3-4 hours
**Dependency:** None

#### Tasks:
- [ ] **2.4.1** Add Flutter `intl` package and ARB files for Hindi, Tamil, Telugu
- [ ] **2.4.2** Create language selector in Profile screen
- [ ] **2.4.3** Use Sarvam AI for dynamic UI translation (labels, buttons)
- [ ] **2.4.4** Store language preference per user

#### Files to Create:
```
wealthin_flutter/lib/l10n/*.arb (localization files)
wealthin_flutter/lib/core/providers/locale_provider.dart
```

---

## 🧪 Phase 3: Testing & DevOps (Priority: LOW-MEDIUM)

### Task 3.1: Unit & Integration Tests
**Status:** Not started
**Estimated Time:** 4-5 hours

#### Tasks:
- [ ] **3.1.1** Test `AIRouterService.routeQuery()` with mock AI services
- [ ] **3.1.2** Test fallback mechanism triggers correctly
- [ ] **3.1.3** Test `AIToolsService` action execution
- [ ] **3.1.4** Integration test: Chat → Tool → DB → Response

#### Files to Create:
```
wealthin_server/test/ai_router_test.dart
wealthin_server/test/ai_tools_test.dart
wealthin_flutter/test/integration/chat_flow_test.dart
```

---

### Task 3.2: Docker Production Setup
**Status:** docker-compose exists for DB
**Estimated Time:** 3-4 hours

#### Tasks:
- [ ] **3.2.1** Create Dockerfile for Serverpod backend
- [ ] **3.2.2** Create Dockerfile for Python sidecar
- [ ] **3.2.3** Update docker-compose.yaml with all services
- [ ] **3.2.4** Add health checks and restart policies
- [ ] **3.2.5** Document deployment process

#### Files to Create:
```
wealthin_server/Dockerfile
wealthin_python_sidecar/Dockerfile
docker-compose.production.yaml
```

---

## 📊 Task Dependency Graph

```
Phase 1 (Critical - Must complete first)
├── 1.1 AI Tools ─────────────┐
├── 1.2 PDF Extraction ───────┼── Enables Phase 2
└── 1.3 Authentication ───────┘

Phase 2 (Features - After Phase 1)
├── 2.1 Voice (needs 1.1)
├── 2.2 Documents (needs 1.2)
├── 2.3 Dashboard Insights (needs 1.1)
└── 2.4 Localization (independent)

Phase 3 (Polish - After Phase 2)
├── 3.1 Testing (needs 1.*, 2.*)
└── 3.2 Docker (independent)
```

---

## ⚡ Quick Start Commands

```bash
# Start all services
./start_wealthin.sh

# Or manually:
cd wealthin/wealthin_server && docker compose up -d  # DB
cd wealthin/wealthin_python_sidecar && source venv/bin/activate && python main.py  # Sidecar
cd wealthin/wealthin_server && dart bin/main.dart  # Backend
cd wealthin/wealthin_flutter && flutter run -d linux  # Frontend

# Regenerate code after model changes
cd wealthin/wealthin_server && serverpod generate
```

---

## 🔄 Progress Tracking

| Task | Status | Started | Completed |
|------|--------|---------|-----------|
| 1.1 AI Tools Integration | ✅ Complete | 2026-01-30 | 2026-01-30 |
| 1.2 PDF Extraction | ✅ Complete | - | (already implemented) |
| 1.3 User Authentication | ✅ Complete | 2026-01-30 | 2026-01-30 |
| 2.1 Voice Interaction | 🔴 Not Started | - | - |
| 2.2 Document Generator | 🔴 Not Started | - | - |
| 2.3 Dashboard Insights | 🔴 Not Started | - | - |
| 2.4 Localization | 🔴 Not Started | - | - |
| 3.1 Testing | 🔴 Not Started | - | - |
| 3.2 Docker | 🔴 Not Started | - | - |

---

## 📝 Notes

- **API Keys Required:** Zoho, Sarvam, OpenAI (set in `.env` or `start_wealthin.sh`)
- **Ports Used:** 8000 (Python), 8082/8085 (Serverpod), 8090 (PostgreSQL)
- **Flutter SDK:** Use bundled SDK in `flutter/` directory

---

*Plan generated by AI assistant. Last validation: 2026-01-30*
