# WealthIn - Agentic Backend Walkthrough

## Architecture Overview

The WealthIn agentic backend transforms the app from a simple text-based chatbot to an **Action-Oriented System** using a **Dispatcher Pattern**.

## Agentic Features Implemented

### 1. Function Calling / Tool Use

The `AgentEndpoint.chat()` method detects user intent and returns either:
- **Text Response**: Regular conversational advice
- **Action Card**: A structured tool call for the frontend to render

**Available Tools:**
- `upsert_budget` - Set spending limits (category, limit, period)
- `create_savings_goal` - Financial targets (name, target_amount, deadline)
- `add_debt` - Track loans/EMIs (name, principal, interest_rate, emi)
- `schedule_payment` - Recurring reminders (name, amount, frequency)
- `analyze_investment` - Calculate returns (investment_type, principal, rate, duration)
- `generate_cashflow_analysis` - Spending patterns (period)

### 2. Transaction Import (3 Methods)

1. **Vision Model** (Handwritten/Bills) - Zoho VL-Qwen2.5-7B for OCR
2. **PDF Extraction** (Bank Statements) - Python sidecar + LLM
3. **Category Inference** - Auto-categorizes by description

### 3. Debt and EMI Management

`DebtEndpoint` provides: Create/Update/Delete debts, Record payments, EMI calculation, Debt summary

### 4. Scheduled Payments

`ScheduledPaymentEndpoint` provides: Recurring payment reminders, Upcoming/overdue tracking

### 5. Investment Calculators

Python sidecar provides: SIP, FD, EMI, RD calculations

## Running the System

1. Start Serverpod: `cd wealthin_server && ./run_server.sh`
2. Start Python Sidecar: `cd wealthin_python_sidecar && ./run_sidecar.sh`
3. Start Flutter: `cd wealthin_flutter && flutter run -d web-server --web-port 8083`

---

## Change Log

### January 30, 2026 - 10:45 AM IST

#### Navigation Consolidation - Minimal Navigation Bar

**Objective:** Reduce navigation bar clutter by categorizing related features into hub screens.

**Before (6 navigation items):**
| Index | Label | Screen |
|-------|-------|--------|
| 0 | Dashboard | DashboardScreen |
| 1 | Transactions | TransactionsScreen |
| 2 | Advisor | AiAdvisorScreen |
| 3 | Documents | DocumentsScreen |
| 4 | Ideas | BrainstormScreen |
| 5 | Profile | ProfileScreen |

**After (4 navigation items):**
| Index | Label | Icon | Screen | Contains |
|-------|-------|------|--------|----------|
| 0 | Dashboard | dashboard | DashboardScreen | Overview, AI Insights, Cashflow widgets |
| 1 | Finance | account_balance_wallet | **FinanceHubScreen** | Transactions, Budgets, Goals, Bills (tabs) |
| 2 | AI Tools | auto_awesome | **AiHubScreen** | Advisor, Documents, Brainstorm (tabs) |
| 3 | Profile | person | ProfileScreen | Settings, Credits, Preferences |

**Files Created:**
```
lib/features/finance/finance_hub_screen.dart    # Finance hub with 4 tabs
lib/features/ai_hub/ai_hub_screen.dart          # AI tools hub with 3 tabs
```

**Files Modified:**
```
lib/main.dart                                    # Navigation reduced from 6 → 4 items
lib/features/profile/profile_screen.dart         # Quick links now open Finance Hub with initialTabIndex
lib/features/transactions/transactions_screen.dart
lib/features/budgets/budgets_screen.dart
lib/features/goals/goals_screen.dart
lib/features/payments/scheduled_payments_screen.dart
lib/features/ai_advisor/ai_advisor_screen.dart
lib/features/documents/documents_screen.dart
lib/features/brainstorm/brainstorm_screen.dart
```

**Pattern Used - Hub Screens with Embeddable Bodies:**

Each feature screen was refactored to export a `*ScreenBody` widget:

```dart
// Standalone screen (for direct navigation)
class TransactionsScreen extends StatelessWidget {
  Widget build(context) => Scaffold(
    appBar: AppBar(title: Text('Transactions')),
    body: TransactionsScreenBody(),
  );
}

// Embeddable body (for hub tabs)
class TransactionsScreenBody extends StatefulWidget { ... }
```

**Hub Screen Structure:**

```dart
class FinanceHubScreen extends StatefulWidget {
  final int initialTabIndex;  // For deep linking from Profile
  const FinanceHubScreen({super.key, this.initialTabIndex = 0});
}

// TabController initialized with widget.initialTabIndex
// Tabs: [TransactionsScreenBody, BudgetsScreenBody, GoalsScreenBody, ScheduledPaymentsScreenBody]
```

**Deep Linking from Profile:**

```dart
// Profile quick links open Finance Hub at specific tab
onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const FinanceHubScreen(initialTabIndex: 1), // Opens Budgets tab
  ),
),
```

**Benefits:**
- ✅ Cleaner navigation bar (4 items vs 6)
- ✅ Related features grouped logically
- ✅ Tab-based navigation within categories
- ✅ Deep linking preserved via initialTabIndex
- ✅ Standalone screens still accessible for direct routes
- ✅ Works on mobile (NavigationBar) and desktop (NavigationRail)

---
