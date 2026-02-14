# Wealthin - Personal Finance Management App

## Overview

Wealthin is a comprehensive personal finance management application built with Flutter that helps users track, analyze, and optimize their financial health. The app provides intelligent insights, automated transaction categorization, budgeting tools, and AI-powered financial advisory features.

## Version

**Version:** 1.0.0+1

## Technology Stack

### Frontend Framework
- **Flutter:** 3.32.0
- **Dart SDK:** 3.8.0

### Key Dependencies

#### UI & Visualization
- `fl_chart: ^0.65.0` - Charts and data visualization
- `google_fonts: ^7.1.0` - Custom typography
- `flutter_animate: ^4.5.2` - Smooth animations
- `cupertino_icons: ^1.0.5` - iOS-style icons

#### Backend & Database
- `supabase_flutter: ^2.3.4` - Backend as a service, authentication, real-time database
- `sqflite: ^2.4.1` - Local SQLite database for offline storage
- `flutter_secure_storage: ^10.0.0` - Secure local data storage

#### Data & Network
- `http: ^1.6.0` - HTTP requests
- `http_parser: ^4.1.0` - HTTP parsing utilities
- `cached_network_image: ^3.4.1` - Image caching
- `shared_preferences: ^2.3.5` - Simple key-value storage
- `path_provider: ^2.1.5` - File system paths

#### Document Processing
- `syncfusion_flutter_pdf: ^32.2.3` - PDF generation and parsing
- `file_picker: ^10.3.10` - File selection
- `image_picker: ^1.1.2` - Camera and gallery access

#### Communication & Permissions
- Android Notification Listener Service (native) - Bank notification access for transaction detection
- `flutter_contacts: ^1.1.9+2` - Contact management
- `speech_to_text: ^7.0.0` - Voice input
- `permission_handler: ^11.3.1` - Runtime permissions
- `url_launcher: ^6.3.2` - URL and deep link handling

#### Internationalization
- `intl: ^0.20.2` - Internationalization and formatting
- `flutter_localizations` - Localization support

## Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration and secrets
│   ├── constants/       # App-wide constants (categories, etc.)
│   ├── models/          # Data models
│   ├── providers/       # State management providers
│   ├── services/        # Business logic services
│   │   ├── ai_agent_service.dart
│   │   ├── auth_service.dart
│   │   ├── contact_service.dart
│   │   ├── data_service.dart
│   │   ├── database_helper.dart
│   │   ├── financial_calculator.dart
│   │   ├── llm_inference_router.dart
│   │   ├── native_pdf_parser.dart
│   │   ├── notification_service.dart
│   │   ├── pdf_report_service.dart
│   │   ├── python_bridge_service.dart
│   │   ├── secure_storage_service.dart
│   │   ├── notification_transaction_service.dart
│   │   ├── startup_permissions_service.dart
│   │   └── transaction_categorizer.dart
│   ├── theme/           # App theming
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable widgets
├── features/            # Feature modules
│   ├── ai_advisor/      # AI financial advisor
│   ├── ai_hub/          # AI tools hub
│   ├── analysis/        # Financial analysis
│   ├── analytics/       # Analytics and health scores
│   ├── auth/            # Authentication
│   ├── brainstorm/      # Financial brainstorming
│   ├── budgets/         # Budget management
│   ├── cashflow/        # Cash flow forecasting
│   ├── dashboard/       # Main dashboard
│   ├── documents/       # Document management
│   ├── finance/         # Financial tools
│   ├── goals/           # Financial goals
│   ├── government/      # Government services integration
│   ├── investment/      # Investment calculator
│   ├── onboarding/      # User onboarding
│   ├── payments/        # Scheduled payments & subscriptions
│   ├── profile/         # User profile and settings
│   ├── research/        # Deep financial research
│   ├── splash/          # Splash screen
│   └── transactions/    # Transaction management
├── l10n/                # Localization files
│   ├── app_en.arb       # English
│   ├── app_hi.arb       # Hindi
│   ├── app_ta.arb       # Tamil
│   └── app_te.arb       # Telugu
├── widgets/             # Global widgets
└── main.dart            # App entry point
```

## Core Features

### 1. **Authentication & Security**
- Secure user authentication via Supabase
- Encrypted local storage for sensitive data
- Biometric authentication support

### 2. **Dashboard**
- Real-time financial overview
- Cash flow visualization
- Category-wise expense breakdown
- Recent transactions
- Trend analysis
- Interactive financial metrics
- Daily streak tracking
- Financial insights ("FinBites")

### 3. **Transaction Management**
- Manual transaction entry
- Automated bank-notification transaction detection
- Smart categorization using AI
- Transaction editing and confirmation
- Multi-category support
- Contact-based merchant identification

### 4. **Budgeting & Goals**
- Create and track budgets
- Set financial goals
- Progress monitoring
- Budget alerts and notifications

### 5. **Cash Flow Forecasting**
- Predict future cash flow
- Income and expense projections
- Scenario planning

### 6. **AI-Powered Features**
- **AI Advisor:** Personalized financial advice
- **AI Chat:** Interactive financial assistant
- **AI Hub:** Centralized AI tools
- **Transaction Categorization:** ML-based auto-categorization
- **Financial Health Score:** Comprehensive health assessment
- **Deep Research:** AI-powered financial research
- **Brainstorming:** Financial planning assistant

### 7. **Analytics**
- Financial health scoring
- Visual analytics with charts
- Category-wise spending analysis
- Trend identification
- Custom date range analysis

### 8. **Document Management**
- PDF document upload and parsing
- Bill and invoice storage
- Automatic data extraction from PDFs
- Document organization

### 9. **Payment Tracking**
- Scheduled payments
- Subscription management
- Payment reminders
- Recurring transaction detection

### 10. **Government Services Integration**
- Access to government financial services
- Scheme discovery
- Application tracking

### 11. **Multi-Language Support**
- English (en)
- Hindi (hi)
- Tamil (ta)
- Telugu (te)

### 12. **Data Import/Export**
- PDF report generation
- Data export functionality
- Backup and restore

## Key Services

### Database Management
- **SQLite (sqflite):** Local offline-first database
- **Supabase:** Cloud backend with real-time sync
- Transaction caching for offline functionality

### AI & Machine Learning
- **LLM Inference Router:** Intelligent routing to appropriate AI models
- **Transaction Categorizer:** Automated expense categorization
- **Financial Calculator:** Complex financial computations
- **AI Agent Service:** Conversational financial assistant

### Data Processing
- **Notification Transaction Service:** Extract transactions from bank notifications
- **PDF Parser:** Extract data from financial documents
- **Contact Service:** Merchant identification from contacts

### Security
- **Secure Storage Service:** Encrypted credential storage
- **Auth Service:** User authentication and session management

## Permissions Required

### Android
- **Notification Access:** Read bank notification content for transaction detection
- **Contacts:** Merchant identification
- **Storage:** Document upload/download
- **Camera:** Document scanning
- **Microphone:** Voice input
- **Internet:** Data synchronization

## Setup Instructions

### Prerequisites
1. Flutter SDK 3.32.0 or higher
2. Dart SDK 3.8.0 or higher
3. Android Studio / VS Code
4. Supabase account (for backend services)

### Installation

1. Clone the repository
```bash
git clone https://github.com/nikhil49023/Wealthin_release.git
cd wealthin_flutter
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Supabase
- Create a `assets/config.json` file with your Supabase credentials
```json
{
  "supabase_url": "YOUR_SUPABASE_URL",
  "supabase_anon_key": "YOUR_SUPABASE_ANON_KEY"
}
```

4. Configure secrets (safe Android key management)
- Add API keys in `android/local.properties` (gitignored):
```properties
SARVAM_API_KEY=sk_xxx
SCRAPINGDOG_API_KEY=sd_xxx
GROQ_API_KEY=gsk_xxx
```
- The app migrates these to secure storage (Android KeyStore-backed) on first launch.

5. Run the app
```bash
flutter run
```

### Build APK
```bash
flutter build apk --release
```

### Build App Bundle
```bash
flutter build appbundle --release
```

## Localization

The app supports 4 languages with generated localization classes:

1. Generate localizations:
```bash
flutter gen-l10n
```

2. Localization files are in `lib/l10n/`:
   - `app_en.arb` - English
   - `app_hi.arb` - Hindi
   - `app_ta.arb` - Tamil
   - `app_te.arb` - Telugu

## Architecture

### Design Pattern
- **Feature-first architecture:** Each feature is self-contained
- **Service layer:** Business logic separated from UI
- **Repository pattern:** Data access abstraction
- **Provider pattern:** State management using providers

### Data Flow
1. **UI Layer:** Flutter widgets
2. **Provider Layer:** State management
3. **Service Layer:** Business logic
4. **Repository Layer:** Data access (Local DB + Supabase)

### Offline-First Strategy
- Local SQLite database for core data
- Background sync with Supabase
- Conflict resolution for offline changes
- Cached network images

## Key Screens

1. **Splash Screen:** App initialization
2. **Onboarding:** First-time user experience
3. **Authentication:** Login/Register
4. **Dashboard:** Main financial overview
5. **Transactions:** Transaction list and management
6. **Budget Management:** Create and track budgets
7. **Goals:** Financial goal tracking
8. **Analytics:** Financial health and insights
9. **AI Advisor:** Chat with financial advisor
10. **Profile:** User settings and preferences
11. **Documents:** Document storage and management
12. **Payments:** Scheduled payments and subscriptions

## Development

### Code Quality
- **flutter_lints:** Enforced linting rules
- **Material Design 3:** Modern UI components
- **Responsive design:** Adapts to different screen sizes

### Testing
```bash
flutter test
```

### Analyze Code
```bash
flutter analyze
```

## Performance Optimizations

1. **Image Caching:** Uses `cached_network_image`
2. **Lazy Loading:** Paginated transaction lists
3. **Database Indexing:** Optimized queries
4. **Widget Rebuilding:** Minimal rebuilds with providers
5. **Asset Optimization:** Compressed images and assets

## Security Considerations

1. **Encrypted Storage:** Sensitive data encrypted locally
2. **Secure Communication:** HTTPS for all network requests
3. **Authentication:** JWT-based session management
4. **Permission Handling:** Runtime permission requests
5. **Data Privacy:** User data stored securely

## Known Limitations

1. Notification transaction detection works best when bank/fintech apps expose full notification content
2. PDF parsing accuracy depends on document structure
3. AI features require active internet connection
4. Some features may require specific Android permissions

## Future Enhancements

- [ ] Multi-currency support
- [ ] Investment portfolio tracking
- [ ] Tax calculation and filing
- [ ] Family account sharing
- [ ] Advanced data visualization
- [ ] Widget support for quick access
- [ ] Wear OS companion app
- [ ] Voice-controlled transactions

## Contributing

This is a private project. For any queries, contact the development team.

## License

Private and proprietary. All rights reserved.

## Support

For issues or feature requests, please contact:
- Email: [Contact Email]
- Repository: https://github.com/nikhil49023/Wealthin_release

## Acknowledgments

- Flutter framework and community
- Supabase for backend services
- Syncfusion for PDF processing
- FL Chart for data visualization

---

**Last Updated:** February 13, 2026
**Version:** 1.0.0+1
**Platform:** Android
**Minimum SDK:** Android 21 (Lollipop)
