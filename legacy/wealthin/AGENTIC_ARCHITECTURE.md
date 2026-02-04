# WealthIn Agentic Backend - Implementation Plan

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter Frontend                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │  Dashboard  │  │Transactions │  │  AI Chat    │  │    DPR      │ │
│  │   Charts    │  │   Import    │  │  + Actions  │  │  Generator  │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │
└─────────┼────────────────┼────────────────┼────────────────┼────────┘
          │                │                │                │
          ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Serverpod Backend (Dart)                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Endpoint Layer                             │   │
│  │  • AgentEndpoint (orchestrates AI actions)                   │   │
│  │  • TransactionEndpoint (CRUD + import)                       │   │
│  │  • BudgetEndpoint / GoalEndpoint                             │   │
│  │  • DebtEndpoint / ScheduledPaymentEndpoint                   │   │
│  │  • DPREndpoint                                               │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Service Layer                              │   │
│  │  • ZohoService (LLM Chat, RAG, Vision)                       │   │
│  │  • AgentDispatcher (function calling interpreter)            │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Python Sidecar (FastAPI @ :8000)                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  • PDF Transaction Extraction (pdfplumber/PyMuPDF)           │   │
│  │  • DPR PDF Generation (ReportLab/WeasyPrint)                 │   │
│  │  • Complex Financial Calculations                            │   │
│  │  • Agentic Tool Execution                                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Phase 1: Database Models (Serverpod Protocol)

### New Models Required:
1. **Budget** - Category-based spending limits
2. **SavingsGoal** - Target amounts with deadlines
3. **Debt** - EMI, loans, credit tracking
4. **ScheduledPayment** - Recurring payment reminders
5. **AgentAction** - Log of AI-triggered actions
6. **AgentToolCall** - Function call definitions

## Phase 2: Agentic Tool Definitions

```json
{
  "tools": [
    {
      "name": "upsert_budget",
      "description": "Create or update a budget limit for a spending category",
      "parameters": {
        "category": "string - The category name",
        "limit": "number - Monthly spending limit in INR",
        "period": "string - 'monthly' or 'weekly'"
      }
    },
    {
      "name": "create_savings_goal",
      "description": "Set a new financial savings target",
      "parameters": {
        "name": "string - Goal name",
        "target_amount": "number - Target amount in INR",
        "deadline": "string - Target date (YYYY-MM-DD)"
      }
    },
    {
      "name": "add_debt",
      "description": "Track a new debt or loan",
      "parameters": {
        "name": "string - Debt name",
        "principal": "number - Principal amount",
        "interest_rate": "number - Annual interest rate %",
        "emi": "number - Monthly EMI",
        "start_date": "string - Loan start date",
        "tenure_months": "number - Loan tenure in months"
      }
    },
    {
      "name": "schedule_payment",
      "description": "Set up a recurring payment reminder",
      "parameters": {
        "name": "string - Payment name",
        "amount": "number - Payment amount",
        "frequency": "string - 'daily', 'weekly', 'monthly'",
        "next_due": "string - Next due date",
        "auto_deduct": "boolean - Whether to auto-track as expense"
      }
    },
    {
      "name": "analyze_investment",
      "description": "Perform investment opportunity analysis",
      "parameters": {
        "capital": "number - Investment amount",
        "type": "string - 'fd', 'sip', 'rd', 'custom'",
        "duration_months": "number - Investment duration",
        "expected_return": "number - Expected annual return %"
      }
    },
    {
      "name": "generate_document",
      "description": "Generate a professional document (DPR, Report)",
      "parameters": {
        "doc_type": "string - 'dpr', 'budget_report', 'cashflow'",
        "data": "object - Document-specific data"
      }
    },
    {
      "name": "extract_transactions",
      "description": "Extract transactions from uploaded document",
      "parameters": {
        "source": "string - 'vision', 'pdf', 'bank_statement'",
        "document_base64": "string - Base64 encoded document"
      }
    }
  ]
}
```

## Phase 3: Implementation Order

### Step 1: Protocol Definitions (Serverpod Models)
- Budget, SavingsGoal, Debt, ScheduledPayment, AgentAction

### Step 2: Python Sidecar Enhancement
- PDF extraction with pdfplumber
- Vision model integration call
- DPR PDF generation
- Financial calculators (SIP, EMI, FD)

### Step 3: Agent Dispatcher (Function Calling)
- Parse LLM responses for tool calls
- Execute corresponding database operations
- Return action cards to frontend

### Step 4: Frontend Action Cards
- Budget action card widget
- Goal action card widget
- Investment calculator widget
- Cashflow chart widget

## Key System Prompts (from Next.js)

### Financial Advisor Prompt:
```
You are "WealthIn," a friendly and interactive financial advisor for entrepreneurs in India.
Your tone should be encouraging and helpful.

You have access to the user's profile, transactions, and can use these tools:
- upsert_budget: Set spending limits
- create_savings_goal: Create savings targets
- add_debt: Track loans/EMIs
- schedule_payment: Set reminders
- analyze_investment: Calculate returns
- generate_document: Create reports

When the user expresses an intent, respond with a tool call in JSON format:
{
  "action": "tool_name",
  "parameters": {...},
  "confirmation_message": "Human-readable confirmation"
}
```

### Transaction Extraction Prompt:
```
Extract all transactions from the provided text.
Each transaction must have: description, date (YYYY-MM-DD), type (income/expense), amount (number).
Return ONLY a valid JSON array.
```
