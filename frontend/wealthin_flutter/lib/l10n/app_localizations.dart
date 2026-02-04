import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'WealthIn'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navAdvisor.
  ///
  /// In en, this message translates to:
  /// **'Advisor'**
  String get navAdvisor;

  /// No description provided for @navDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get navDocuments;

  /// No description provided for @navIdeas.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get navIdeas;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @greeting_morning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greeting_morning;

  /// No description provided for @greeting_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greeting_afternoon;

  /// No description provided for @greeting_evening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greeting_evening;

  /// No description provided for @dashboard_title.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard_title;

  /// No description provided for @dashboard_netWorth.
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get dashboard_netWorth;

  /// No description provided for @dashboard_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get dashboard_income;

  /// No description provided for @dashboard_expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get dashboard_expenses;

  /// No description provided for @dashboard_savingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings Rate'**
  String get dashboard_savingsRate;

  /// No description provided for @dashboard_financialHealth.
  ///
  /// In en, this message translates to:
  /// **'Financial Health'**
  String get dashboard_financialHealth;

  /// No description provided for @dashboard_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboard_quickActions;

  /// No description provided for @dashboard_aiFinBite.
  ///
  /// In en, this message translates to:
  /// **'AI FinBite'**
  String get dashboard_aiFinBite;

  /// No description provided for @action_scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get action_scan;

  /// No description provided for @action_advisor.
  ///
  /// In en, this message translates to:
  /// **'Advisor'**
  String get action_advisor;

  /// No description provided for @action_brainstorm.
  ///
  /// In en, this message translates to:
  /// **'Brainstorm'**
  String get action_brainstorm;

  /// No description provided for @action_addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get action_addTransaction;

  /// No description provided for @transactions_title.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions_title;

  /// No description provided for @transactions_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get transactions_all;

  /// No description provided for @transactions_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactions_income;

  /// No description provided for @transactions_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactions_expense;

  /// No description provided for @transactions_noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get transactions_noTransactions;

  /// No description provided for @transactions_importPdf.
  ///
  /// In en, this message translates to:
  /// **'Import PDF'**
  String get transactions_importPdf;

  /// No description provided for @advisor_title.
  ///
  /// In en, this message translates to:
  /// **'AI Advisor'**
  String get advisor_title;

  /// No description provided for @advisor_askQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your finances...'**
  String get advisor_askQuestion;

  /// No description provided for @advisor_send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get advisor_send;

  /// No description provided for @advisor_thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get advisor_thinking;

  /// No description provided for @documents_title.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents_title;

  /// No description provided for @documents_create.
  ///
  /// In en, this message translates to:
  /// **'Create Document'**
  String get documents_create;

  /// No description provided for @documents_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate professional financial documents with AI assistance'**
  String get documents_subtitle;

  /// No description provided for @documents_loanApplication.
  ///
  /// In en, this message translates to:
  /// **'Loan Application'**
  String get documents_loanApplication;

  /// No description provided for @documents_loanDesc.
  ///
  /// In en, this message translates to:
  /// **'Apply for personal, home, or vehicle loans'**
  String get documents_loanDesc;

  /// No description provided for @documents_invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get documents_invoice;

  /// No description provided for @documents_invoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate professional invoices for goods or services'**
  String get documents_invoiceDesc;

  /// No description provided for @documents_receipt.
  ///
  /// In en, this message translates to:
  /// **'Payment Receipt'**
  String get documents_receipt;

  /// No description provided for @documents_receiptDesc.
  ///
  /// In en, this message translates to:
  /// **'Issue receipts for payments received'**
  String get documents_receiptDesc;

  /// No description provided for @documents_projectReport.
  ///
  /// In en, this message translates to:
  /// **'Project Report'**
  String get documents_projectReport;

  /// No description provided for @documents_projectDesc.
  ///
  /// In en, this message translates to:
  /// **'Create detailed project or business reports'**
  String get documents_projectDesc;

  /// No description provided for @documents_generatePdf.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get documents_generatePdf;

  /// No description provided for @documents_generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get documents_generating;

  /// No description provided for @documents_saved.
  ///
  /// In en, this message translates to:
  /// **'Document saved'**
  String get documents_saved;

  /// No description provided for @documents_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get documents_open;

  /// No description provided for @brainstorm_title.
  ///
  /// In en, this message translates to:
  /// **'Brainstorm'**
  String get brainstorm_title;

  /// No description provided for @brainstorm_subtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered financial brainstorming'**
  String get brainstorm_subtitle;

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile_title;

  /// No description provided for @profile_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profile_settings;

  /// No description provided for @profile_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profile_language;

  /// No description provided for @profile_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get profile_theme;

  /// No description provided for @profile_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profile_notifications;

  /// No description provided for @profile_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profile_about;

  /// No description provided for @profile_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profile_logout;

  /// No description provided for @profile_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get profile_version;

  /// No description provided for @auth_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auth_login;

  /// No description provided for @auth_register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get auth_register;

  /// No description provided for @auth_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email;

  /// No description provided for @auth_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_password;

  /// No description provided for @auth_confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get auth_confirmPassword;

  /// No description provided for @auth_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get auth_forgotPassword;

  /// No description provided for @auth_noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get auth_noAccount;

  /// No description provided for @auth_hasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get auth_hasAccount;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// No description provided for @common_success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get common_success;

  /// No description provided for @common_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get common_required;

  /// No description provided for @common_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get common_amount;

  /// No description provided for @common_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get common_description;

  /// No description provided for @common_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get common_date;

  /// No description provided for @common_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get common_category;

  /// No description provided for @common_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get common_type;

  /// No description provided for @currency_symbol.
  ///
  /// In en, this message translates to:
  /// **'₹'**
  String get currency_symbol;

  /// No description provided for @currency_format.
  ///
  /// In en, this message translates to:
  /// **'₹{amount}'**
  String currency_format(String amount);

  /// No description provided for @insight_excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent savings this month!'**
  String get insight_excellent;

  /// No description provided for @insight_onTrack.
  ///
  /// In en, this message translates to:
  /// **'You\'re on track with your goals!'**
  String get insight_onTrack;

  /// No description provided for @insight_needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Spending alert'**
  String get insight_needsAttention;

  /// No description provided for @insight_steady.
  ///
  /// In en, this message translates to:
  /// **'Steady progress'**
  String get insight_steady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'ta', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
