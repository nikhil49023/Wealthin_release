# WealthIn v2 - Complete Setup Guide

## 🎉 Project Overview

WealthIn v2 is a **sovereign-first, local-first** personal finance app built with:
- **Flutter** - Cross-platform mobile/web frontend
- **Serverpod** - Dart backend with PostgreSQL
- **Python/FastAPI** - AI agents for document parsing

## 📁 Project Structure

```
wealthin_v2/
├── flutter/              # Flutter SDK (cloned from GitHub)
├── wealthin/            # Main Serverpod project
│   ├── wealthin_server/  # Backend server
│   │   ├── lib/src/endpoints/  # API endpoints
│   │   └── lib/src/models/     # Database models (.spy.yaml)
│   ├── wealthin_client/  # Generated client SDK
│   └── wealthin_flutter/ # Flutter app
│       └── lib/
│           ├── core/     # Theme, models, services
│           └── features/ # App screens
│               ├── dashboard/
│               ├── transactions/
│               ├── ai_advisor/
│               ├── brainstorm/
│               └── profile/
└── wealthin_agents/      # Python AI service
```

## 🚀 Running the App

### 1. Start Docker (PostgreSQL + Redis)
```bash
cd wealthin/wealthin_server
docker compose up -d
```

### 2. Run Database Migrations
```bash
cd wealthin/wealthin_server
dart bin/main.dart --apply-migrations
```

### 3. Start the Serverpod Backend
```bash
cd wealthin/wealthin_server
dart bin/main.dart
```

### 4. Start the Flutter App
```bash
export PATH="$PWD/flutter/bin:$PATH"
cd wealthin/wealthin_flutter
flutter run -d chrome
```

### 5. Start Python AI Agent (Optional)
```bash
cd wealthin_agents
source venv/bin/activate
uvicorn main:app --reload --port 8001
```

## ✨ Features Implemented

### Dashboard
- 📊 Financial overview (income, expenses, savings rate)
- 🤖 AI-powered suggestions (FinBite)
- ⚡ Quick actions (Scan, AI Advisor, Brainstorm)

### Transactions
- 📋 List with filtering (All/Income/Expense)
- ➕ Add transactions manually
- 📄 Import from PDF (via local OCR - zero cloud cost!)

### AI Advisor
- 💬 Chat interface for financial advice
- 🎯 Smart suggestions based on context
- 📝 Quick prompts for common queries

### Brainstorm
- 💡 Business idea analyzer
- 📈 Viability scoring (0-100)
- 📋 SWOT analysis with recommendations
- 💾 Save and compare ideas

### Profile
- 👤 User settings
- ⭐ Gamification credits system
- 🎨 Theme settings (Dark mode)
- 🌐 Multi-language support (EN, Hindi, Tamil)

## 🔧 Serverpod Endpoints

| Endpoint | Description |
|----------|-------------|
| `transaction.getTransactions` | Get user's transactions |
| `transaction.createTransaction` | Add new transaction |
| `transaction.getDashboardSummary` | Get income/expense summary |
| `budget.getBudgets` | Get user's budgets |
| `goal.getGoals` | Get savings goals |
| `userProfile.getOrCreateProfile` | Create/get user profile |
| `userProfile.awardCredits` | Award gamification credits |

## 🏗️ Development Commands

### Regenerate Serverpod Code
```bash
cd wealthin/wealthin_server
serverpod generate
```

### Analyze Flutter Code
```bash
cd wealthin/wealthin_flutter
flutter analyze lib/
```

### Build for Production
```bash
cd wealthin/wealthin_flutter
flutter build web --release
```

## 🔑 Key Design Principles

1. **Local-First**: PDF parsing uses local OCR, not cloud APIs
2. **Zero-Marginal Cost**: Core features work without API costs
3. **Sovereign Data**: User data stays on their infrastructure
4. **Gamification**: Credits reward good financial habits

## 📝 Next Steps

1. Connect Flutter screens to Serverpod endpoints
2. Implement user authentication
3. Add file picker for PDF import in Flutter
4. Integrate Gemini API for AI Advisor
5. Add charts and visualizations
