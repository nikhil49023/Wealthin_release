# WealthIn Architecture Refactor - Implementation Guide

## Architecture: Local-First with Python Sidecar

This project has moved to a **Local-First** architecture.
- **Frontend**: Flutter (Web, Linux, Android)
- **Backend**: Python Sidecar (running locally on `localhost:8000`)
- **Database**: SQLite (managed by Python backend)
- **Auth**: Firebase Auth (for user identity, strictly optional/auth-only)
- **Sync**: No cloud database sync. Data lives on the device (served by Python).

### ✅ Completed Status

1. **Python Sidecar Backend**
   - Serves as the implementation of "Local Database" via HTTP.
   - Endpoints for `budgets`, `goals`, `transactions`.
   - **Local LLM & Search**: `web_search_service.py` (DuckDuckGo), `pdf_parser_advanced.py`.
   - **Receipt Scanning**: OCR using `pymupdf2` and `Pillow`.
   - **Data Providers (Ready)**:
     - `web_search_service.py`: Prepared for **ScraperDog** (Web Scraping).
     - `api_sethu_service.py`: Prepared for **API Sethu** (Gov Schemes).
     - *Note: Waiting for API variables.*

2. **Flutter Refactor**
   - **Service Layer**: 
     - `DataService` talks to `localhost:8000`.
     - `AuthService` manages Firebase Auth (stripped of Firestore/Drive).
     - Removed `CloudSyncService` and `SupabaseAuthService`.
   - **Web Support**: Built and verified.
   - **Linux Support**: Code is ready (environment dependencies may vary).

### 🚧 Not Yet Started / In Progress

1. **Local LLM Inference Layer**
   - Connect Flutter chat UI to local model loading.
   - Currently exploring `llama.cpp` or python-side serving of GGUF models.

2. **Clean UI & Animations**
   - Final polish of the "Premium" feel.
   - Ensure specific color palette (Greens/Teals) is consistent.

---

## Integration Instructions

### 1. Python Backend Setup (The "Database")

The "database" is actually a SQLite file managed by the Python server. You must run this server for the app to work.

```bash
cd wealthin_agents
# Install dependencies
pip install -r requirements.txt
# Run the server
python main.py
```
*Server runs on localhost:8000*

### 2. Flutter App Setup

```bash
cd wealthin_flutter
flutter pub get
# Run on Web (connects to localhost:8000)
flutter run -d chrome
# Run on Linux (connects to localhost:8000)
flutter run -d linux
```

### 3. Testing on Web

To test the "Local Database" on Web:
1. **Start the Python Backend** in a terminal: `python wealthin_agents/main.py`
2. **Run the Flutter Web App** in another terminal: `flutter run -d chrome`
3. The Web App will make HTTP requests to `http://localhost:8000`. 
4. Data you create (Transactions, Budgets) is saved to the `wealthin.db` (or similar) underlying SQLite file in the `wealthin_agents` directory.

### 4. Linux Build (Native)

Ensure you have Linux build tools installed:
`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev lld`

```bash
flutter build linux
```

---

## Environment Variables

Create `.env` in `wealthin_agents/`:

```
# Web Search
# No API key required for DuckDuckGo
API_SETHU_KEY=
SCRAPERDOG_API_KEY=

# PDF Parsing
OCR_ENABLED=true

# Server
PORT=8000
```
---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **App shows "No Backend"** | Ensure `python main.py` is running. Check `localhost:8000/health`. |
| **Web CORS Error** | Python backend must include `CORSMiddleware` allowing `*` origins. |
| **Linux Build Fail (lld)** | Install `lld` or `clang` (e.g., `sudo apt install lld`). |
| **Firebase Auth Error** | Ensure `google-services.json` (Android) / `firebase_options.dart` (Web/Linux) are valid. |

---

## File Locations Reference

- **Python Backend**: `/backend/` (Main logic, Database access)
- **Flutter Services**: `/frontend/wealthin_flutter/lib/core/services/`
  - `data_service.dart`: HTTP Client for Python Backend
  - `auth_service.dart`: Firebase Auth Wrapper


## Implementation Status Summary

### ✅ Completed

1. **Python Backend Enhancement**
   - Created `web_search_service.py` with DuckDuckGo search capability
   - Implemented finance-specific search (tax updates, schemes, interest rates, investment news)
   - Added result caching (6-12h TTL) to prevent stale data
   - Created `pdf_parser_advanced.py` with OCR support using pymupdf2
   - Implemented ReceiptParser for receipt/invoice extraction
   - Added duplicate transaction detection (24h window)
   - Multi-method extraction: tables → OCR → pattern matching with confidence scoring
   - Updated `requirements.txt` with pymupdf2, duckduckgo-search, numpy, Pillow

2. **Supabase Integration**
   - Created `supabase_auth_service.dart` with full OAuth support
   - Email/password authentication
   - Google OAuth 2.0 integration
   - User profile management with Supabase PostgreSQL
   - Session management and state tracking
   - Error handling and recovery
   - Added `supabase_flutter: ^2.0.0` to pubspec.yaml
   - Created reference `main_supabase.dart` implementation

3. **Endpoint Additions to Python Backend**
   - `/search/finance` - General financial search with categorization
   - `/search/tax-updates` - Tax and compliance information
   - `/search/schemes` - Government schemes and benefits
   - `/search/interest-rates` - Current rates and market data
   - `/extract-transactions` - Multi-method PDF parsing with OCR
   - `/extract-receipt` - Specialized receipt extraction

### 🚧 Not Yet Started

1. **Local LLM Inference Layer** (Step 6)
   - Need to build Flutter plugin integration (flutter_llama/mlc_llm)
   - Create model loader for sarvam-1 (GGUF format)
   - Implement local/cloud inference mode switching
   - Build Nemotron-compatible function calling parser
   - Set up fallback chain (local → cloud → OpenAI)

2. **Theme System Perfection** (Step 7)
   - Need to audit all screens for off-theme colors
   - Verify WCAG AA contrast ratios (4.5:1 minimum)
   - Test dark mode on deep blacks (#000000-#121212)
   - Ensure light mode gray scale (#F9FAFB-#111827)
   - Update any remaining Firebase references

3. **Comprehensive Animations** (Step 8)
   - Click/tap: Scale(0.95→1.0, 150ms) on all interactive elements
   - Input focus: Border transitions (navy→emerald, 200ms)
   - Scroll: StaggeredListView with fadeIn + slideY
   - Navigation: Page transitions with fade + slide
   - Loading states: Enhanced typing indicators and progress animations

4. **Chat Interface Polish** (Step 9)
   - Message bubble animations (slide + fade, 300ms)
   - Typing indicator with vertical bob
   - Quick-reply suggestions with staggered fadeIn
   - Code syntax highlighting and copy functionality
   - Timestamp grouping and section headers

5. **Google Drive Structured Database** (Step 10)
   - Replace binary backup with JSON documents
   - Implement delta sync with timestamps
   - Add conflict resolution using Drive's revision API
   - Offline-first queue for pending operations

---

## Integration Instructions

### Python Backend Setup

1. **Install new dependencies:**
   ```bash
   cd wealthin_agents
   pip install -r requirements.txt
   ```

2. **Add endpoints to main.py:**
   - Copy contents of `new_endpoints_to_add.py` into `main.py`
   - Place before the "# ============== Run Server ==============" section
   - Add imports at the top:
     ```python
     from services.web_search_service import web_search_service
     from services.pdf_parser_advanced import pdf_parser_service, ReceiptParser
     ```

3. **Test endpoints:**
   ```bash
   curl -X POST http://localhost:8000/search/finance \
     -H "Content-Type: application/json" \
     -d '{"query":"income tax 2025", "limit": 5}'
   
   curl -X POST http://localhost:8000/health
   ```

### Flutter App Setup

1. **Update main.dart:**
   - Option A (Recommended): Rename `lib/main.dart` → `lib/main_firebase.dart`, then `lib/main_supabase.dart` → `lib/main.dart`
   - Option B: Manually update existing main.dart following reference in `main_supabase.dart`

2. **Install dependencies:**
   ```bash
   cd wealthin_flutter
   flutter pub get
   ```

3. **Update AuthWrapper to use Supabase:**
   - Replace `authService` references with `supabaseAuth`
   - Update imports from Firebase to Supabase

4. **Test Supabase connection:**
   ```dart
   // In any screen
   print('Supabase User: ${supabaseAuth.currentUserId}');
   print('Is Authenticated: ${supabaseAuth.isAuthenticated}');
   ```

---

## Nemotron Function Calling Setup

### Expected Format for Training Data

Your training dataset should follow this structure for tool calls:

```json
{
  "type": "tool_call",
  "tool_call": {
    "name": "create_budget",
    "arguments": {
      "category": "Food",
      "amount": 5000,
      "period": "monthly"
    }
  }
}
```

### Parser Implementation (Next Step)

Create `lib/core/services/nemotron_function_parser.dart`:

```dart
class NemotronFunctionParser {
  static Map<String, dynamic>? parseToolCall(String response) {
    try {
      // Extract JSON from response
      final regex = RegExp(r'\{[\s\S]*?\}');
      final match = regex.firstMatch(response);
      if (match == null) return null;
      
      final json = jsonDecode(match.group(0)!);
      
      // Check Nemotron format
      if (json['type'] == 'tool_call' && json['tool_call'] != null) {
        return json['tool_call'];
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}
```

---

## Configuration Files

### Environment Variables

Create `.env` file in `wealthin_agents/`:

```
# Supabase
SUPABASE_URL=https://sguzpnegfmeuczgsmtgl.supabase.co
SUPABASE_KEY=sb_publishable_ee1UuOOs0ruoqtmdqbRCEg__ls-kja4

# Web Search (auto-configured via duckduckgo-search)
# No API key required

# PDF Parsing
OCR_ENABLED=true  # Set to false to disable OCR (pymupdf2)

# Backend Port
PORT=8000
```

### Supabase Database Schema

Create tables in Supabase PostgreSQL:

```sql
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  avatar_url TEXT,
  contact_info JSONB DEFAULT '{}',
  personal_details JSONB DEFAULT '{}',
  app_settings JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to see only their own profile
CREATE POLICY "Users can view own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id);
```

---

## Next Steps Priority

### Immediate (This Week)

1. Merge Supabase integration into main branch
2. Test Python endpoints with real data
3. Update chat interface with basic animations (fade-in/slide)

### Short Term (Next 2 Weeks)

1. Implement local LLM inference layer with model switching
2. Add theme audit and WCAG AA compliance fixes
3. Comprehensive animation rollout across app
4. Enhanced chat UX (quick replies, syntax highlighting)

### Medium Term (Next Month)

1. Google Drive structured database refactor
2. Full offline-first sync queue implementation
3. Production-grade error handling and logging

---

## Testing Checklist

- [ ] Supabase auth works on iOS/Android/Web
- [ ] Web search returns relevant finance results
- [ ] PDF parsing correctly identifies bank statements vs receipts
- [ ] Receipt extraction captures merchant, amount, date
- [ ] Duplicate detection removes within-24h duplicates
- [ ] All animations run smoothly at 60fps on low-end devices
- [ ] Dark mode contrast meets WCAG AA standards
- [ ] Chat interface responds smoothly with animations
- [ ] Offline queue captures transactions when no connection
- [ ] Google Drive sync completes without data loss

---

## Deployment Notes

### Python Backend
- Deploy to: Railway, Heroku, or custom VPS
- Set environment variables before deployment
- Ensure OCR dependencies installed (pymupdf2, Pillow)

### Flutter App
- Replace Firebase credentials with Supabase in release build
- Update bundle IDs and app signing
- Test on minimum Android 6.0, iOS 11.0

### Database (Supabase)
- Configure automatic daily backups
- Set up RLS policies before going to production
- Monitor for rate limits on web search API (duckduckgo-search is free but rate-limited)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| PDF extraction returns empty | Check OCR_ENABLED setting, ensure pymupdf2 installed |
| Web search returns no results | Verify internet connection, check DuckDuckGo status |
| Supabase auth fails | Verify credentials in Supabase dashboard match `supabase_auth_service.dart` |
| Animations stutter on old devices | Profile with DevTools, consider disabling non-critical animations |
| Dark mode text unreadable | Check contrast ratios in WealthInTheme, increase brightness for text |

---

## File Locations Reference

- Python Backend Services: `/wealthin_agents/services/`
- Flutter Core Services: `/wealthin_flutter/lib/core/services/`
- Flutter Features: `/wealthin_flutter/lib/features/`
- Theme System: `/wealthin_flutter/lib/core/theme/wealthin_theme.dart`
- Main App Entry: `/wealthin_flutter/lib/main.dart` (or `main_supabase.dart`)

---

Generated: February 1, 2026
Last Updated: Implementation Phase 1 Complete
