# WealthIn v2 Implementation Progress

**Status**: Phase 2 - Frontend Integration (Backend Infrastructure Complete)
**Last Updated**: Current Session
**Session Objective**: Modernize WealthIn from mock data to production-ready with gamification, OpenAI integration, and real financial management

---

## Executive Summary

This document tracks the comprehensive modernization of WealthIn v2 financial app from mock data based system to a production-ready platform with:
- ✅ Real user data management with SQLite + MongoDB
- ✅ Gamification with milestones and XP system
- ✅ OpenAI-powered business idea evaluation
- ✅ Automated transaction categorization and budget sync
- 🔄 PDF exports for analysis and DPR documents
- 🔄 Interactive DPR drafting with Socratic questioning

---

## Architecture Overview

### Frontend Stack
- **Framework**: Flutter 3.32+ with Dart
- **Local Storage**: SQLite (sqflite) - 3 databases (transactions, planning, wealthin)
- **HTTP Client**: http package for FastAPI backend communication
- **PDF Generation**: Syncfusion for rich PDF with charts
- **Authentication**: Supabase
- **State Management**: Provider (existing), planned refactor to Riverpod
- **Platform Awareness**: Android has embedded Python; desktop uses HTTP backend

### Backend Stack
- **Framework**: FastAPI with async/await (Python 3.10+)
- **Async Database**: aiosqlite for SQLite operations
- **NoSQL**: MongoDB with Motor driver (async) + in-memory fallback
- **AI Services**: OpenAI GPT-4o for idea evaluation and DPR assistance
- **PDF Processing**: pdfplumber for receipt/invoice parsing
- **Regional Languages**: Sarvam API for Hindi/Tamil/Kannada support

### Database Architecture
```
SQLite (Relational)
├── transactions.db
│   ├── transactions (id, user_id, amount, category, date, description, ...)
│   └── daily_trends (date, category, amount, user_id)
│
└── planning.db
    ├── budgets (id, user_id, category, amount, spent, period, ...)
    ├── goals (id, user_id, name, target, current, ...)
    ├── scheduled_payments (id, user_id, amount, date, ...)
    └── financial_health_cache (metadata)

MongoDB (NoSQL - Analysis & Gamification)
├── analysis_snapshots
├── milestones
├── idea_evaluations
├── dpr_documents
├── financial_metrics
└── budget_auto_sync
```

---

## Phase 1: Backend Foundation ✅ COMPLETE

### 1.1 MongoDB Integration Service
**File**: `backend/services/mongo_service.py`
**Status**: ✅ Complete

**Features Implemented**:
- Singleton async MongoDB client with connection pooling
- In-memory fallback for development/offline scenarios
- 6 collection schema definitions:
  - `analysis_snapshots`: Point-in-time financial snapshots with health indicators
  - `milestones`: 14 gamification milestones with XP rewards
  - `idea_evaluations`: OpenAI business idea assessments
  - `dpr_documents`: Detailed Project Report storage
  - `financial_metrics`: Monthly metrics history for trend analysis
  - `budget_auto_sync`: Transaction-to-budget categorization logs

**Gamification Milestones** (14 total, 10-150 XP each):
1. First Step (5k spent) - 10 XP
2. Budget Master (all budgets set) - 50 XP
3. Saver Initiate (10% savings rate) - 25 XP
4. Savings Champion (30% savings rate) - 100 XP
5. Debt Management (debt < 5 lakhs) - 75 XP
6. Financial Guardian (debt = 0) - 150 XP
7. Liquidity Expert (6 months emergency fund) - 100 XP
8. Investment Enthusiast (1 Lakh invested) - 75 XP
9. Financial Analyst (analyzed 50+ transactions) - 50 XP
10. Streak Master (30-day streak) - 60 XP
11. Goal Setter (3+ goals created) - 40 XP
12. Goal Achiever (1 goal completed) - 80 XP
13. Idea Innovator (3 ideas evaluated) - 45 XP
14. DPR Champion (DPR created) - 120 XP

**Key Methods**:
```python
save_analysis_snapshot()      # Save + check milestones
check_and_award_milestones()  # Award XP & level up
get_user_xp()                 # Returns level/XP/progress
save_idea_evaluation()        # Store OpenAI idea eval
save_dpr()                    # Store DPR document
get_metrics_history()         # Monthly trends
```

### 1.2 OpenAI Idea Evaluator Service
**File**: `backend/services/idea_evaluator_service.py`
**Status**: ✅ Complete

**Features**:
- GPT-4o integration for structured business idea evaluation
- Comprehensive JSON response schema with:
  - Viability score (0-100)
  - Market analysis (size, growth rate, audience)
  - Financial projections (investment, ROI, break-even)
  - SWOT analysis (Strengths, Weaknesses, Opportunities, Threats)
  - Competitive landscape & risk assessment
  - 5+ actionable recommendations
  - Revenue models & regulatory considerations
  - Confidence metrics
- Fallback scoring if OpenAI unavailable (predictable ~65 score)

**Request Format**:
```json
{
  "idea": "Build an AI-powered expense tracking app for Indian SMEs",
  "location": "India",
  "budget_range": "5-10 Lakhs",
  "user_context": {
    "monthly_income": 100000,
    "business_type": "Software Services"
  }
}
```

### 1.3 FastAPI Backend Enhancements
**File**: `backend/main.py`
**Status**: ✅ Complete - 8 new endpoints added

**New API Endpoints**:

1. **POST /analysis/save-snapshot**
   - Request: `AnalysisMetricsRequest` (income, expense, health_score, etc.)
   - Response: newly_achieved_milestones, user_level, xp_to_next_level
   - Saves to MongoDB, checks milestone eligibility, awards XP

2. **GET /analysis/milestones/{user_id}**
   - Response: Array of milestone objects with achievement status
   - Includes: level (1-20), total_xp, xp_to_next_level, milestone_count

3. **GET /analysis/history/{user_id}?months=6**
   - Response: Array of historical analysis snapshots
   - Useful for trend visualization and progress tracking

4. **POST /ideas/evaluate**
   - Request: `IdeaRequest` (idea, location, budget_range, user_context)
   - Response: Structured evaluation from OpenAI
   - Stores evaluation in MongoDB automatically

5. **GET /ideas/{user_id}?limit=10**
   - Response: List of saved idea evaluations
   - Includes: idea_text, score, viability, timestamp

6. **POST /dpr/save**
   - Request: `DPRRequest` (business_idea, sections, completeness, etc.)
   - Response: dpr_id for later retrieval/editing
   - Stores in MongoDB with timestamps

7. **GET /dpr/{user_id}?limit=10**
   - Response: List of user's DPR documents
   - Includes: business_idea, sections completion %, last_modified

8. **GET /metrics/history/{user_id}?months=12**
   - Response: Monthly financial metrics (income, expense, savings_rate, health_score)
   - Useful for trend charts and progress analysis

**Error Handling**: All endpoints gracefully degrade if MongoDB unavailable, using in-memory fallback.

**Pydantic Models Added**:
- `AnalysisMetricsRequest`
- `IdeaRequest`
- `DPRRequest`
- Response models with full type hints

---

## Phase 2: Frontend Integration 🔄 IN PROGRESS

### 2.1 Data Service Extensions
**File**: `frontend/wealthin_flutter/lib/core/services/data_service_extensions.dart`
**Status**: ✅ Complete

**Extension Methods Added to DataService**:

#### Gamification Methods
```dart
// Save analysis + check milestones in one call
saveAnalysisSnapshot({
  required userId, totalIncome, totalExpense, healthScore,
  required categoryBreakdown, savingsRate, insights,
  transactionCount, budgetCount, goalsCompleted, currentStreak, underBudgetMonths,
})
// Returns: {success, snapshot_id, newly_achieved_milestones[], user_level, total_xp}

// Get user's milestone progress
getMilestones(userId)
// Returns: {level, total_xp, xp_to_next_level, milestones[], milestones_achieved}

// Get 6-month analysis history
getAnalysisHistory(userId, months=6)
// Returns: [{health_score, savings_rate, timestamp}, ...]

// Get monthly metrics for trends
getMetricsHistory(userId, months=12)
// Returns: [{income, expense, savings_rate, health_score, transaction_count}, ...]
```

#### Idea Evaluation Methods
```dart
// Evaluate business idea with OpenAI
evaluateIdea({
  required userId, idea, location, budgetRange,
  userContext
})
// Returns: {score, viability, market_analysis, financial_projection, SWOT, recommendations}

// List saved ideas
getSavedIdeas(userId, limit=10)
// Returns: [{idea_id, idea_text, score, viability, created_at}, ...]
```

#### DPR Management Methods
```dart
// Save DPR document
saveDPR({
  required userId, businessIdea, sections,
  completeness, researchData, financialProjections
})
// Returns: dpr_id

// List saved DPRs
getSavedDPRs(userId, limit=10)
// Returns: [{dpr_id, business_idea, completeness, sections, last_modified}, ...]
```

#### Budget Auto-Sync
```dart
// Auto-categorize transactions and sync to budgets
autoCategorizeAndSyncBudgets({
  required userId, transactions
})
// Returns: {success, transactions_imported, categories_synced, new_budgets_created}
```

**Platform Awareness**: All methods include fallback for Android (local-only sync).

### 2.2 Budget Display Fix
**File**: `flutter/wealthin_flutter/lib/features/budgets/budgets_screen.dart`
**Status**: 🔄 PENDING

**Current Issue**: Mock data fallback in `_OverallBudgetCard` widget (line ~120-140)

**Fix Required**:
1. Remove hardcoded values in `_OverallBudgetCard`
2. Enforce real data from `_loadBudgets()`
3. Add proper error UI if no budgets exist
4. Add "No Data" state with create budget button

**Code Changes**:
```dart
// BEFORE (in _OverallBudgetCard):
final totalBudget = budgets.isEmpty ? 500000 : budgets.map<double>((b) => b.amount).fold(0, (a, b) => a + b);
final totalSpent = budgets.isEmpty ? 235000 : budgets.map<double>((b) => b.spent).fold(0, (a, b) => a + b);

// AFTER: Enforce real data or show empty state
final totalBudget = budgets.map<double>((b) => b.amount).fold(0, (a, b) => a + b);
final totalSpent = budgets.map<double>((b) => b.spent).fold(0, (a, b) => a + b);

// If budgets.isEmpty, show "Create Your First Budget" prompt instead
```

**Status**: Ready to implement

### 2.3 Transaction Import → Budget Auto-Sync
**File**: `flutter/wealthin_flutter/lib/features/transactions/transaction_confirmation_screen.dart`
**Status**: 🔄 PENDING

**Current Flow**:
1. User confirms transaction import
2. Transactions saved to database
3. **Missing**: Budget updated in real-time

**Enhancement**:
```dart
// In _onConfirm():
1. Call dataService.saveTransactions(transactions, userId);
2. Call dataService.autoCategorizeAndSyncBudgets(transactions, userId);
3. Show toast: "3 budgets updated from 50 imported transactions"
4. Call Navigator.pop(context, true) to refresh parent
```

**Changes Needed**:
- Add await for `autoCategorizeAndSyncBudgets()`
- Update parent budget list via callback
- Show confirmation toast with sync results

**Status**: Ready to implement

### 2.4 Analysis Screen Gamification
**File**: `flutter/wealthin_flutter/lib/features/analysis/analysis_screen.dart`
**Status**: 🔄 PENDING

**Current State**: Shows health score gauge, metrics cards, no gamification

**Enhancements Required**:

1. **Add XP/Level Display** (at top)
   - Level indicator: "Level 3 • 150/300 XP"
   - Progress bar showing XP to next level
   - Total milestones achieved: "5/14 Milestones"

2. **Milestones Section** (new widget)
   - Grid of 14 milestone cards
   - Locked (grayed out) vs Unlocked (highlighted)
   - Each shows: icon, name, XP reward, achievement status
   - Click to view details

3. **Load Milestones on Screen Entry**
   ```dart
   Future<void> _loadMilestones() async {
     final milestonesData = await dataService.getMilestones(userId);
     setState(() {
       userLevel = milestonesData['level'];
       totalXP = milestonesData['total_xp'];
       xpToNextLevel = milestonesData['xp_to_next_level'];
       milestones = milestonesData['milestones'];
     });
   }
   ```

4. **Save Snapshot on Screen Load**
   - Call `saveAnalysisSnapshot()` with current metrics
   - Check for newly_achieved_milestones
   - Show toast if new milestone achieved: "🎉 Savings Champion! +100 XP"

**UI Mockup**:
```
┌─────────────────────────────────────┐
│ Level 3  [█████░░░░░░] 150/300 XP  │
│ 5 of 14 Milestones Achieved       │
└─────────────────────────────────────┘
[Health Score Gauge]
[Financial Metrics Cards]
[Milestones Grid]
├─ 🎯 First Step ✓
├─ 💰 Saver Initiate ✓
├─ 🏆 Savings Champion ✓
├─ 📊 Budget Master ✓
├─ 🔐 Financial Guardian (locked)
└─ ... (10 more)
```

**Status**: Ready to implement

### 2.5 Analysis PDF Export
**File**: `flutter/wealthin_flutter/lib/core/services/pdf_report_service.dart`
**Status**: 🔄 PENDING

**Current State**: `generateHealthReport()` exists but not called from UI

**Enhancement**:

1. **Add Export Button** in `analysis_screen.dart`
   ```dart
   FloatingActionButton(
     onPressed: _exportAnalysisAsPDF,
     child: Icon(Icons.file_download),
   )
   ```

2. **Enhance PDF Report** with visuals:
   - Health score gauge (SVG/chart)
   - Expense pie chart (category breakdown)
   - 6-month trend line chart
   - Milestone achievements grid
   - Key insights with emoji icons
   - Savings potential recommendations

3. **Export Implementation**:
   ```dart
   Future<void> _exportAnalysisAsPDF() async {
     showSnackBar('Generating PDF...');
     final pdf = await pdfReportService.generateHealthReport(
       healthScore: _healthScore,
       dashboardData: _dashboardData,
       userName: userName,
       milestones: achievedMilestones,
       recommendations: insights,
     );
     
     final file = await pdf.save();
     await openFile(file);
     showSnackBar('Analysis exported successfully!');
   }
   ```

4. **Syncfusion Integration**:
   - Use `SfCartesianChart` for trend visualization
   - Use `SfCircularChart` for category breakdown
   - Use `PdfDocument` to embed charts in PDF

**Status**: Ready to implement

### 2.6 Ideas Section - OpenAI Evaluation
**File**: `flutter/wealthin_flutter/lib/features/brainstorm/brainstorm_screen.dart`
**Status**: 🔄 PENDING

**Current State**: Has UI framework, missing backend integration

**Enhancement**:

1. **Evaluate Button** in idea card
   ```dart
   ElevatedButton(
     onPressed: () => _evaluateIdea(ideaText, budget),
     child: Text('Get AI Evaluation'),
   )
   ```

2. **Call OpenAI Evaluation**:
   ```dart
   Future<void> _evaluateIdea(String idea, String budget) async {
     showLoadingDialog('Analyzing with AI...');
     
     final evaluation = await dataService.evaluateIdea(
       userId: userId,
       idea: idea,
       location: 'India',
       budgetRange: budget,
       userContext: {
         'monthly_income': userMonthlyIncome,
         'savings_rate': savingsRate,
         'business_experience': years,
       },
     );
     
     if (evaluation != null) {
       _showEvaluationResults(evaluation);
     }
   }
   ```

3. **Display Results**:
   - **Viability Score**: 0-100 with visual gauge
   - **Market Analysis**: Size, growth rate, target audience
   - **Financial Projection**: Investment needed, monthly costs, ROI, break-even
   - **SWOT Analysis**: 4-card layout
   - **Top 5 Recommendations**: Bulleted list
   - **Risk Assessment**: Key risks & mitigation

4. **Save Idea** functionality:
   ```dart
   Future<void> _saveIdea(Map<String, dynamic> evaluation) async {
     final saved = await dataService.saveIdeaEvaluation(
       userId: userId,
       evaluation: evaluation,
     );
     showSnackBar('Idea saved to your collection!');
   }
   ```

5. **View Previous Ideas**:
   - Tab/section showing past evaluations
   - List with dates, idea name, viability score
   - Click to view detailed evaluation

**UI Layout**:
```
┌─ Evaluate Idea ────────────┐
│ [Viability Score: 72/100]  │
│ 💡 Market Size: 500Cr      │
│ 💰 Investment: 8 Lakhs     │
│ 📈 ROI: 2.5x in 3 years    │
│ [Detailed SWOT, Risks]     │
│ [Save] [Export PDF] [Share]│
└────────────────────────────┘
[Previous Ideas List]
├─ K-12 EdTech App (65)
├─ AgriTech Platform (78)
└─ ...
```

**Status**: Ready to implement

### 2.7 DPR Interactive Drafting
**File**: `flutter/wealthin_flutter/lib/features/dpr/` (NEW)
**Status**: 🔄 PENDING - Requires new UI module

**Feature Overview**:
Interactive step-by-step DPR creation with Socratic questioning from AI

**Architecture**:

1. **DPR Sections** (6 major):
   - Executive Summary
   - Market Analysis &amp; Opportunity
   - Financial Projections &amp; Business Model
   - Risk Management &amp; Mitigation
   - Implementation Roadmap
   - Supporting Documents & Appendices

2. **Socratic Questioning Flow**:
   ```
   Backend: POST /dpr/{dpr_id}/next-question
   Returns: {
       "section": "Market Analysis",
       "question": "Who are your primary customers?",
       "guidance": "Think about: age, income, pain points...",
       "examples": ["SaaS for accountants", "Mobile app for students"],
       "input_type": "long_text" | "multiselect" | "numeric"
   }
   ```

3. **Interactive Draft Screen UI**:
   ```
   ┌─ DPR for: K-12 EdTech App ──────┐
   │ [Progress: 45%]                  │
   │ Section 2/6: Market Analysis     │
   │                                  │
   │ ❓ Who are your primary customers?│
   │ [Long text input]                │
   │ 💡 Tip: Think about age, income  │
   │                                  │
   │ 📋 Example answers:              │
   │ • Teachers seeking better tools  │
   │ • Parents wanting safe platform  │
   │                                  │
   │ [← Back] [Save Draft] [Next →]   │
   └─────────────────────────────────┘
   ```

4. **Draft Saving**:
   ```dart
   Future<void> _saveDraft() async {
     final dprId = await dataService.saveDPR(
       userId: userId,
       businessIdea: ideaTitle,
       sections: completedSections,
       completeness: progressPercentage,
       researchData: researchNotes,
     );
     showSnackBar('Draft saved successfully!');
   }
   ```

5. **PDF Export** (Final DPR):
   - Generate comprehensive PDF with:
   - All sections with user's answers
   - Financial tables and projections
   - Market research summaries
   - Professional formatting with logo/branding
   - Executive summary on first page

**Implementation Steps**:
1. Create `dpr_screen.dart` with step-by-step UI
2. Create `dpr_question_widget.dart` for dynamic question display
3. Create `dpr_pdf_service.dart` extending pdf_report_service
4. Add backend support for Socratic questions (extend dpr_generator.py)
5. Hook up navigation from brainstorm_screen to DPR

**Status**: Ready to implement

---

## Phase 3: Remaining Tasks

### Priority Order

| # | Task | File | Status | Est. Effort |
|---|------|------|--------|------------|
| 1 | Fix Budget Display (Remove Mock Data) | budgets_screen.dart | 🔄 PENDING | 1h |
| 2 | Transaction Auto-Sync to Budgets | transaction_confirmation_screen.dart | 🔄 PENDING | 1.5h |
| 3 | Analysis Gamification UI | analysis_screen.dart | 🔄 PENDING | 3h |
| 4 | Analysis PDF Export | analysis_screen.dart + pdf_report_service.dart | 🔄 PENDING | 2h |
| 5 | Ideas Section Integration | brainstorm_screen.dart | 🔄 PENDING | 2h |
| 6 | DPR Interactive Drafting | dpr_screen.dart (NEW) | 🔄 PENDING | 4h |
| 7 | Testing & Integration | all | 🔄 PENDING | 2h |

**Total Remaining Effort**: ~15.5 hours

### 3.1 Testing Checklist

- [ ] Budget section shows real data (no mock fallback)
- [ ] Importing 10 transactions updates budgets immediately
- [ ] Analysis screen displays current user level and XP
- [ ] Milestone achieved triggers toast notification
- [ ] Export analysis to PDF creates file successfully
- [ ] OpenAI idea evaluation returns within 10 seconds
- [ ] Save idea evaluation to MongoDB works offline (syncs later)
- [ ] DPR Socratic questions appear sequentially
- [ ] DPR PDF export includes all sections and formatting
- [ ] App works on Android with embedded Python backend
- [ ] App works on desktop with FastAPI HTTP backend

### 3.2 Deployment Checklist

- [ ] All endpoints return proper error responses
- [ ] MongoDB connection string configured in environment
- [ ] OpenAI API key configured in environment
- [ ] PDF Syncfusion license key (if required) configured
- [ ] iOS/Android signing certificates updated
- [ ] Backend deployed to production server
- [ ] Database migrations run successfully
- [ ] Analytics logging added to critical paths

---

## Key Code Patterns

### Pattern 1: Real Data Enforcement
```dart
// ✅ Good - Enforces real data
List<BudgetModel> budgets = await dataService.getBudgets(userId);
if (budgets.isEmpty) {
  return _showEmptyState();
}
```

```dart
// ❌ Bad - Uses mock fallback
List<BudgetModel> budgets = await dataService.getBudgets(userId) ?? [];
if (budgets.isEmpty) {
  budgets = [BudgetModel(amount: 500000, spent: 235000)]; // MOCK!
}
```

### Pattern 2: Async Milestone Checking
```dart
// On transaction import completion
final snapshot = await dataService.saveAnalysisSnapshot(
  userId: userId,
  totalIncome: totalIncome,
  totalExpense: totalExpense,
  // ... other fields
);

if (snapshot['newly_achieved_milestones'].isNotEmpty) {
  for (final milestone in snapshot['newly_achieved_milestones']) {
    showSnackBar('🎉 ${milestone['name']}! +${milestone['xp']} XP');
  }
}
```

### Pattern 3: Async OpenAI Evaluation
```dart
Future<void> _evaluateIdea(String idea) async {
  showLoadingDialog('Analyzing with OpenAI...');
  
  try {
    final evaluation = await dataService.evaluateIdea(
      userId: userId,
      idea: idea,
      userContext: {'monthly_income': userIncome},
    );
    
    if (evaluation != null) {
      _showEvaluationResults(evaluation);
    } else {
      showSnackBar('Evaluation failed. Please try again.');
    }
  } catch (e) {
    showErrorDialog('Error: $e');
  }
}
```

---

## Environment Configuration

### Backend (.env)
```bash
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/wealthin
OPENAI_API_KEY=sk-...
SARVAM_API_KEY=...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=...
DATABASE_PATH=/app/data
```

### Frontend (lib/core/constants/backend_config.dart)
```dart
const String _baseUrl = 'http://localhost:8001'; // or production URL
const bool _useHTTPBackend = !kIsWeb; // Android uses embedded Python
```

---

## Database Migration Notes

### SQLite Foreign Keys
```sql
CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  spent REAL DEFAULT 0,
  period TEXT DEFAULT 'monthly',
  UNIQUE(user_id, category, period)
);
```

### MongoDB Indexes
```javascript
// Essential indexes for performance
db.analysis_snapshots.createIndex({ user_id: 1, created_at: -1 });
db.milestones.createIndex({ user_id: 1 });
db.idea_evaluations.createIndex({ user_id: 1, created_at: -1 });
db.dpr_documents.createIndex({ user_id: 1, created_at: -1 });
db.financial_metrics.createIndex({ user_id: 1, month: -1 });
```

---

## Known Issues & Limitations

### Current
- [ ] iOS doesn't have embedded Python (uses HTTP only)
- [ ] PDF charts require Syncfusion license
- [ ] OpenAI evaluations take 5-10 seconds
- [ ] MongoDB fallback doesn't persist across app restarts
- [ ] DPR Socratic questions not yet implemented

### Future Improvements
- [ ] Implement offline queue for failed requests
- [ ] Add retry logic with exponential backoff
- [ ] Cache OpenAI evaluations for similar ideas
- [ ] Implement progressive DPR saves
- [ ] Add data encryption for sensitive fields
- [ ] Implement request rate limiting

---

## Quick Start for Next Developer

1. **Backend Setup**:
   ```bash
   cd backend
   pip install -r requirements.txt
   export MONGODB_URI="..." OPENAI_API_KEY="..."
   python main.py
   ```

2. **Frontend Setup**:
   ```bash
   cd frontend/wealthin_flutter
   flutter pub get
   flutter run
   ```

3. **Testing API**:
   ```bash
   curl -X POST http://localhost:8001/ideas/evaluate \
     -H "Content-Type: application/json" \
     -d '{"user_id":"test","idea":"AI expense tracker","location":"India"}'
   ```

4. **Common Debugging**:
   - MongoDB unavailable? Check mongo_service.py fallback is working
   - OpenAI timeout? Check API key and rate limits
   - Budget not syncing? Check transaction_categorizer.dart categorization logic

---

## References

- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Flutter Best Practices](https://flutter.dev/docs/testing/best-practices)
- [MongoDB Operations](https://docs.mongodb.com/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Syncfusion Flutter Docs](https://www.syncfusion.com/flutter-widgets)

---

**Session Summary**:
- ✅ Backend infrastructure complete (MongoDB + OpenAI)
- ✅ 8 new API endpoints created
- ✅ Data service extensions for all new features
- 🔄 Frontend integration ready to begin
- 🎯 Next: Implement Task #1 (Budget display fix)

**Contact**: For questions about implementation details, check inline code comments or refer to Architecture document.
