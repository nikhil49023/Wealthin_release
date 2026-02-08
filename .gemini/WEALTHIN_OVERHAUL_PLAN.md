# WealthIn App Overhaul - Implementation Plan

**Created:** 2026-02-07
**Status:** In Progress

---

## Overview

This document outlines the comprehensive plan to overhaul the WealthIn app across 6 phases:
1. Robust PDF Parsing
2. Dashboard & Navigation Restructuring
3. Financial Analysis Features
4. Payment Scheduling & AI
5. Budget Integration
6. General UI/UX Polish

---

## Phase 1: Robust PDF Parsing ✏️

### Current State
- Backend: `backend/services/pdf_parser.py` - PDFParserService with pdfplumber
- No extensive logging for raw extracted text
- Limited Android-specific handling

### Tasks

#### 1.1 Add Extensive Logging to PDF Parser
**File:** `backend/services/pdf_parser.py`

```python
# Add at top of file
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("pdf_parser")

# In extract_text() and extract_transactions_from_pdf():
logger.debug(f"[PDF DEBUG] Raw text extracted ({len(text)} chars):\n{text[:2000]}")
logger.debug(f"[PDF DEBUG] Tables found: {len(tables)}")
for i, table in enumerate(tables):
    logger.debug(f"[PDF DEBUG] Table {i}: {table[:3]}...")  # First 3 rows
```

**Changes needed:**
- Add logging throughout `extract_text()`, `extract_transactions_from_pdf()`, `_extract_from_tables()`, `_extract_from_text()`
- Log raw text dump before any processing
- Log each regex match attempt and result

#### 1.2 Refine pypdf Extraction Logic for Android
**File:** `backend/services/pdf_parser.py`

- Add text normalization for Android encoding issues
- Handle common layout variations (multi-column, wrapped text)
- Add fallback extraction methods

```python
def _normalize_text_for_android(self, text: str) -> str:
    """Normalize text that may have Android-specific encoding issues."""
    import unicodedata
    # Normalize Unicode characters
    text = unicodedata.normalize('NFKC', text)
    # Fix common Android PDFBox extraction issues
    text = text.replace('\u00a0', ' ')  # Non-breaking space
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    # Remove zero-width characters
    text = text.replace('\u200b', '').replace('\u200c', '')
    return text
```

#### 1.3 Debug Mode Integration
**Frontend:** `lib/features/dashboard/dashboard_screen.dart` 

- Add debug toggle in Settings
- Show raw extraction results in dialog before saving transactions
- Store debug logs locally for review

---

## Phase 2: Dashboard & Navigation Restructuring ✏️

### Current State
- Dashboard has: InteractiveBanner ✅, FinBiteCard, CashflowCard, CategoryBreakdown, etc.
- AnalysisScreen already exists with: HealthScore, Metrics (Income/Expense/Savings), CashflowCard, TrendAnalysis, etc.
- Navigation has 6 tabs: Home, Analysis, Finance, AI, Ideas, Profile

### Tasks

#### 2.1 Simplify Dashboard - Remove Redundant Cards
**File:** `lib/features/dashboard/dashboard_screen.dart`

**KEEP on Dashboard:**
- InteractiveBanner (already exists with ivory gradient + 3D assets)
- FinBiteCard (daily AI insight)
- QuickActionsCard (needs enhancement)

**REMOVE from Dashboard (they're in Analysis screen):**
- CashflowCard → Already in AnalysisScreen
- CategoryBreakdownCard → Already in AnalysisScreen  
- TrendAnalysisCard → Already in AnalysisScreen
- FinancialOverviewCard → Already in AnalysisScreen
- MetricCard usage (Income/Expense/Savings) → Already in AnalysisScreen

#### 2.2 Enhance QuickActionsCard
**File:** `lib/features/dashboard/dashboard_screen.dart` (lines 807-855)

Current quick actions: Add Transaction, Scan Bill, AI Chat, Tools
**Add:**
- Schedule Payment
- Set Budget
- Savings Goal

```dart
// Enhanced Quick Actions with 2-row grid
final quickActions = [
  ('Add Transaction', Icons.add_card, _showAddTransactionDialog),
  ('Scan Statement', Icons.document_scanner, _scanBankStatement),
  ('AI Advisor', Icons.auto_awesome, _openAIChat),
  ('Schedule Payment', Icons.schedule, _openSchedulePayment),
  ('Set Budget', Icons.pie_chart, _openBudgets),
  ('Savings Goal', Icons.savings, _openGoals),
];
```

#### 2.3 Add Profile Button to Dashboard Header
**File:** `lib/features/dashboard/dashboard_screen.dart`

- Add profile avatar/button to `_buildHeader()`
- Make it navigate to ProfileScreen

#### 2.4 Remove Profile from Bottom Navigation
**File:** `lib/main.dart`

Current: 6 tabs (Home, Analysis, Finance, AI, Ideas, Profile)
New: 5 tabs (Home, Analysis, Finance, AI, Ideas)

```dart
// Remove ProfileScreen from _screens list
final List<Widget> _screens = const [
  DashboardScreen(),
  AnalysisScreen(),
  FinanceHubScreen(),
  AiHubScreen(),
  BrainstormScreen(),
  // ProfileScreen removed - accessible from dashboard header
];

// Update NavigationBar destinations (remove Profile)
```

#### 2.5 Verify Analysis Tab Content
**File:** `lib/features/analysis/analysis_screen.dart`

**Already contains (no changes needed):**
- HealthScoreCard ✅
- IncomeCard, ExpenseCard, SavingsCard, SavingsRateCard ✅
- CashflowCard ✅
- TrendAnalysisCard ✅
- CategoryBreakdownCard ✅
- FinancialOverviewCard ✅
- Per Capita Insights ✅

---

## Phase 3: Financial Analysis Features ✏️

### Current State
- AnalysisScreen has `_calculateHealthScore()` - basic implementation
- `trends_service.py` provides transaction analysis
- No per-capita/income source analysis connected

### Tasks

#### 3.1 Enhance FinancialHealthIndicator
**File:** `lib/features/analysis/analysis_screen.dart`

Current scoring (lines 55-85):
- Base: 50
- Savings rate: 0-30 points
- Expense ratio: 0-20 points
- Max: 100

**Enhance with:**
- Consistency bonus (regular income +10)
- Emergency fund progress (+10)
- Budget adherence (+10)

```dart
int _calculateHealthScore(DashboardData? data) {
  if (data == null) return 0;
  
  int score = 30; // Base score (reduced from 50)
  
  // Savings rate (0-25 points)
  final savingsRate = data.savingsRate;
  if (savingsRate >= 30) score += 25;
  else if (savingsRate >= 20) score += 20;
  else if (savingsRate >= 10) score += 12;
  else if (savingsRate > 0) score += 5;
  
  // Expense ratio (0-20 points)
  if (data.totalIncome > 0) {
    final ratio = data.totalExpense / data.totalIncome;
    if (ratio < 0.5) score += 20;
    else if (ratio < 0.7) score += 15;
    else if (ratio < 0.9) score += 5;
  }
  
  // Consistency bonus (0-15 points) - needs transaction data
  // TODO: Analyze transaction regularity
  
  // Budget adherence (0-10 points) - needs budget data
  // TODO: Compare spending vs budget limits
  
  return score.clamp(0, 100);
}
```

#### 3.2 Implement IncomeAnalysis Widget
**File:** `lib/features/analysis/widgets/income_analysis_card.dart` (NEW)

Features:
- Per capita income (total / family size)
- Income sources breakdown (from trends_service)
- Month-over-month comparison

```dart
class IncomeAnalysisCard extends StatelessWidget {
  final double totalIncome;
  final int familySize;
  final List<Map<String, dynamic>> incomeSources;
  
  // Displays:
  // - Per Capita Income: ₹X/person
  // - Income Sources chart/list
  // - Trend indicator (up/down vs last month)
}
```

#### 3.3 Connect to Python Backend trends_service
**Backend:** `backend/services/trends_service.py` - Already implemented ✅

**Frontend integration needed:**
**File:** `lib/core/services/data_service.dart`

```dart
Future<TrendsContext> getTrendsAnalysis(String userId) async {
  final response = await _http.get('/analytics/trends/$userId');
  return TrendsContext.fromJson(response.data);
}
```

**Add to AnalysisScreen:**
```dart
// Load trends data
final trendsData = await _dataService.getTrendsAnalysis(userId);
// Display top income/expense sources
```

---

## Phase 4: Payment Scheduling & AI ✏️

### Current State
- `ScheduledPaymentsScreen` exists with full CRUD UI
- `ai_tools_service.py` has `_schedule_payment()` function
- AI can schedule payments via pattern matching

### Tasks

#### 4.1 Audit Schedule Payment UI Flows
**File:** `lib/features/payments/scheduled_payments_screen.dart`

**Test cases:**
- [ ] Add new payment (dialog opens, saves correctly)
- [ ] Edit existing payment
- [ ] Mark as paid
- [ ] Delete payment
- [ ] Recurring payment creation
- [ ] Due date validation

**Ensure navigation:**
- Can navigate from Dashboard QuickActions
- Can navigate from Finance Hub

#### 4.2 Add Navigation Entry Points
**File:** `lib/features/finance/finance_hub_screen.dart`

```dart
// Add card/button for "Scheduled Payments"
_buildActionCard(
  'Scheduled Payments',
  Icons.schedule,
  () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const ScheduledPaymentsScreen(),
  )),
)
```

#### 4.3 Verify AI schedule_payment Tool
**File:** `backend/services/ai_tools_service.py` (lines 772-793)

```python
def _schedule_payment(self, args: Dict[str, Any]) -> AIToolResponse:
    """Schedule a payment reminder."""
    # Current implementation - verify it returns correct format
    # for Flutter to save locally
```

**Test prompts:**
- "Schedule my rent payment of ₹15,000 for the 1st of every month"
- "Remind me to pay electricity bill on 15th"
- "Add a recurring SIP payment of ₹5000 monthly"

#### 4.4 AI Integration Test
**Testing flow:**
1. Open AI Advisor chat
2. Say "Schedule my rent payment of ₹15000 on the 1st of every month"
3. AI should confirm and create the payment
4. Check ScheduledPaymentsScreen for new entry

---

## Phase 5: Budget Integration ✏️

### Current State
- Budget categories defined in `budgets_screen.dart`
- Transaction categories from PDF parser
- Category mapping may not match

### Tasks

#### 5.1 Standardize Category List
**Create shared constants file:**
**File:** `lib/core/constants/categories.dart` (NEW)

```dart
class Categories {
  static const List<String> all = [
    'Food & Dining',
    'Shopping',
    'Transport',
    'Bills & Utilities',
    'Entertainment',
    'Health & Medical',
    'Education',
    'Travel',
    'Groceries',
    'Personal Care',
    'Investments',
    'Salary',
    'Business Income',
    'Other Income',
    'Other',
  ];
  
  static const Map<String, IconData> icons = {
    'Food & Dining': Icons.restaurant,
    'Shopping': Icons.shopping_bag,
    // ... etc
  };
}
```

#### 5.2 Update Transaction Fetch to Recalculate Budgets
**File:** `lib/core/services/data_service.dart`

```dart
Future<void> onTransactionsUpdated() async {
  // After transactions are added/modified
  await _recalculateBudgetProgress();
}

Future<void> _recalculateBudgetProgress() async {
  final budgets = await getBudgets();
  final transactions = await getTransactions();
  
  for (var budget in budgets) {
    final spent = transactions
        .where((t) => t.category == budget.category && t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    
    await updateBudgetSpent(budget.id, spent);
  }
}
```

#### 5.3 Ensure Category Mapping Matches
**File:** `backend/services/transaction_categorizer.py`

Map backend categories to match frontend:
```python
CATEGORY_MAP = {
    'food': 'Food & Dining',
    'restaurant': 'Food & Dining',
    'uber': 'Transport',
    'ola': 'Transport',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    # ... etc
}
```

---

## Phase 6: General UI/UX Polish ✏️

### Tasks

#### 6.1 Button Audit Checklist

**DashboardScreen:**
- [ ] QuickAction: Add Transaction → Opens dialog
- [ ] QuickAction: Scan Bill → Opens scanner
- [ ] QuickAction: AI Chat → Navigates to AI screen
- [ ] QuickAction: Tools → Navigates to Finance tools
- [ ] FinBite refresh → Refreshes insight
- [ ] Banner CTA → Navigates to Analysis

**FinanceHubScreen:**
- [ ] All navigation cards functional
- [ ] Tab switching works

**ScheduledPaymentsScreen:**
- [ ] Add button → Opens dialog
- [ ] Edit button → Opens edit dialog
- [ ] Delete button → Confirms & deletes
- [ ] Mark paid → Updates status

**BudgetsScreen:**
- [ ] Add budget → Opens dialog with category dropdown
- [ ] Edit budget
- [ ] Delete budget

**GoalsScreen:**
- [ ] Add goal
- [ ] Update progress
- [ ] Delete goal

**ProfileScreen:**
- [ ] Theme toggle works
- [ ] Logout works
- [ ] Settings navigation

#### 6.2 3D Animated Splash Screen Enhancement
**File:** `lib/features/splash/splash_screen.dart`

**Current features:** ✅
- Particle system
- Morphing logo with 3D rotation
- Gradient animations
- Progress indicator

**Enhancements (optional):**
- Add a 3D coin/wallet animation (using Transform.rotateY)
- Add subtle parallax effect
- Optimize for smoother 60fps

#### 6.3 Profile Button in Dashboard Header
**File:** `lib/features/dashboard/dashboard_screen.dart`

In `_buildHeader()` (lines 722-755):
```dart
Widget _buildHeader(ThemeData theme) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting, style: ...),
          Text(userName, style: ...),
        ],
      ),
      // Add profile button
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(Icons.person, color: theme.colorScheme.primary),
        ),
      ),
    ],
  );
}
```

---

## Implementation Order

### Week 1: Foundation ✅ COMPLETED
1. ✅ Phase 2.4 - Remove Profile from navbar (main.dart)
2. ✅ Phase 2.1 - Simplify Dashboard (removed CategoryBreakdownCard, RecentTransactionsCard)
3. ✅ Phase 6.3 - Add Profile button to header (both mobile and desktop)
4. ✅ Phase 2.2 - Enhance QuickActions (2-row grid with Add, Scan, Advisor, Payments, Tools, Analysis)

### Week 2: PDF & Analysis
4. ✅ Phase 1.1 - Add logging to PDF parser (extensive debug logging)
5. ✅ Phase 1.2 - Android encoding fixes (_normalize_text_for_android)
6. ✅ Phase 3.1 - Enhance health score (5-factor scoring: savings, expense ratio, emergency fund, income, categories)
7. ✅ Phase 5.1 - Standardize categories (created lib/core/constants/categories.dart)
8. ✅ Phase 3.3 - Connect trends service (getMonthlyTrends already implemented, TrendAnalysisCard uses it)

### Week 3: Actions & Integration
9. ✅ Phase 4.1 - Audit payments UI (Finance Hub has 4 tabs including Bills/Scheduled Payments)
10. ✅ Phase 4.3 - Verify AI payment tool (reviewed - works correctly)
11. ✅ Phase 5.1 - Standardize categories (DONE - lib/core/constants/categories.dart)
12. ✅ Phase 5.2 - Budget recalculation (already implemented in database_helper.dart)

### Week 4: Polish
13. Phase 6.1 - Button audit (TODO - full walkthrough)
14. ✅ Phase 6.2 - Splash enhancements (already has 3D animations)
15. Final testing

---

## Files to Modify

| File | Phase | Changes |
|------|-------|---------|
| `main.dart` | 2.4 | Remove Profile from navbar |
| `dashboard_screen.dart` | 2.1, 2.2, 6.3 | Simplify, enhance quick actions, profile button |
| `analysis_screen.dart` | 3.1 | Enhanced health score |
| `pdf_parser.py` | 1.1, 1.2 | Logging, Android fixes |
| `scheduled_payments_screen.dart` | 4.1 | Audit & fixes |
| `ai_tools_service.py` | 4.3 | Verify schedule_payment |
| `data_service.dart` | 3.3, 5.2 | Trends API, budget recalc |
| `categories.dart` | 5.1 | NEW - shared constants |

---

## Testing Checklist

- [ ] PDF parsing works on Android with Hindi/English statements
- [ ] Dashboard is clean and focused
- [ ] All cards moved to Analysis screen display correctly
- [ ] Profile accessible from dashboard header
- [ ] Quick actions all functional
- [ ] Scheduled payments CRUD works
- [ ] AI can schedule payments
- [ ] Budgets track actual spending
- [ ] Categories match between transactions and budgets
- [ ] All buttons have handlers
- [ ] Splash screen is smooth

---

**Let's start with Phase 2 (Dashboard restructuring) as it has the most visible impact!**
