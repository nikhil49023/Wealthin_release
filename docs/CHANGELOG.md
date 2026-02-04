# WealthIn V2 Changelog

## [2026-01-30 15:30 IST] - Transaction Import & Trends Analysis Feature

### 🆕 New Features

#### Python Backend (wealthin_agents)

1. **Transaction Trends Analysis Service** (`services/trends_service.py`)
   - `SpendingTrend` dataclass for individual category trends
   - `UserTrends` dataclass for comprehensive user analysis
   - Monthly spending trend calculation
   - Category-wise spending breakdown with percentages
   - Recurring expense detection (monthly, weekly, bi-weekly patterns)
   - Anomaly detection (unusual spending > 2 standard deviations)
   - AI-ready context generation for personalized responses

2. **Enhanced PDF Parser** (`services/pdf_parser.py`)
   - Bank statement parsing for Indian banks:
     - HDFC Bank
     - State Bank of India (SBI)
     - ICICI Bank
     - Axis Bank
   - Table extraction using pdfplumber
   - Pattern-based text parsing fallback
   - Auto-categorization using keyword matching
   - Date normalization to ISO format (YYYY-MM-DD)
   - Support for Indian amount formats (with commas)

3. **New API Endpoints** (`main.py`)
   | Endpoint | Method | Description |
   |----------|--------|-------------|
   | `/transactions/import/pdf` | POST | Import transactions from bank statement PDF |
   | `/transactions/import/image` | POST | Import transaction from receipt image (Zoho VLM) |
   | `/transactions/import/batch` | POST | Batch import multiple transactions |
   | `/trends/{user_id}` | GET | Get comprehensive spending trends analysis |
   | `/trends/{user_id}/ai-context` | GET | Get AI-ready context summary |

4. **AI Integration Enhancement** (`services/ai_tools_service.py`)
   - Added `_get_user_trends_context()` method
   - AI advisor now receives user's spending trends in system prompt
   - Personalized responses based on:
     - Top spending categories
     - Increasing/decreasing spending patterns
     - Recurring expenses total
     - Detected anomalies

#### Flutter App (wealthin_flutter)

5. **Import Dialog UI** (`lib/widgets/import_dialog.dart`)
   - Two distinct import options with visual cards:
     - 📄 **PDF Icon (Red)** - For bank statements
     - 🖼️ **Image Icon (Blue)** - For receipts/handwritten notes
   - Connected to Python backend via HTTP multipart uploads
   - Displays detected bank name for PDFs
   - Transaction preview before import
   - Category chips for each transaction
   - Loading states with descriptive messages

6. **Transactions Screen Update** (`lib/features/transactions/transactions_screen.dart`)
   - Passes `userId` to ImportTransactionsDialog
   - Integration with Firebase Auth for user identification

### 📦 Dependencies Added

**Flutter (`pubspec.yaml`)**
```yaml
http_parser: ^4.1.0  # For multipart file uploads
```

### 🗄️ Database Schema (Existing)

The transactions table already supports all imported data:
```sql
transactions (
  id INTEGER PRIMARY KEY,
  user_id TEXT,
  amount REAL,
  description TEXT,
  category TEXT,
  type TEXT,  -- 'income' or 'expense'
  date TEXT,
  payment_method TEXT,
  notes TEXT,
  receipt_url TEXT,
  is_recurring INTEGER,
  created_at TEXT
)
```

### 🔄 Data Flow

```
User selects import option
        │
        ├── PDF Bank Statement
        │   └── POST /transactions/import/pdf
        │       └── PDF Parser extracts transactions
        │           └── Auto-categorize
        │               └── Save to SQLite
        │
        └── Receipt Image
            └── POST /transactions/import/image
                └── Zoho VLM Vision OCR
                    └── Extract merchant, amount, date
                        └── Auto-categorize
                            └── Save to SQLite

AI Advisor Query
        │
        └── GET user trends context
            └── Analyze recent transactions
                └── Generate personalized response
```

### 🧪 Testing

Backend endpoints tested:
```bash
# Health check
curl http://localhost:8000/

# Trends endpoint
curl http://localhost:8000/trends/test_user
```

### 📝 Notes

- Zoho Catalyst VLM is used for image OCR (requires configured credentials)
- Sarvam AI is used for Indic language queries
- All Python files compile without errors
- All Dart files have no analyzer errors
- Backend runs on port 8000 with auto-reload

---

## [Previous Changes]

*Add previous changelog entries here as needed*
