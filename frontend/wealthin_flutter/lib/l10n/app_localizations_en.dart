// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WealthIn';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navAdvisor => 'Advisor';

  @override
  String get navDocuments => 'Documents';

  @override
  String get navIdeas => 'Ideas';

  @override
  String get navProfile => 'Profile';

  @override
  String get greeting_morning => 'Good Morning';

  @override
  String get greeting_afternoon => 'Good Afternoon';

  @override
  String get greeting_evening => 'Good Evening';

  @override
  String get dashboard_title => 'Dashboard';

  @override
  String get dashboard_netWorth => 'Net Worth';

  @override
  String get dashboard_income => 'Income';

  @override
  String get dashboard_expenses => 'Expenses';

  @override
  String get dashboard_savingsRate => 'Savings Rate';

  @override
  String get dashboard_financialHealth => 'Financial Health';

  @override
  String get dashboard_quickActions => 'Quick Actions';

  @override
  String get dashboard_aiFinBite => 'AI FinBite';

  @override
  String get action_scan => 'Scan';

  @override
  String get action_advisor => 'Advisor';

  @override
  String get action_brainstorm => 'Brainstorm';

  @override
  String get action_addTransaction => 'Add Transaction';

  @override
  String get transactions_title => 'Transactions';

  @override
  String get transactions_all => 'All';

  @override
  String get transactions_income => 'Income';

  @override
  String get transactions_expense => 'Expense';

  @override
  String get transactions_noTransactions => 'No transactions yet';

  @override
  String get transactions_importPdf => 'Import PDF';

  @override
  String get advisor_title => 'AI Advisor';

  @override
  String get advisor_askQuestion => 'Ask me anything about your finances...';

  @override
  String get advisor_send => 'Send';

  @override
  String get advisor_thinking => 'Thinking...';

  @override
  String get documents_title => 'Documents';

  @override
  String get documents_create => 'Create Document';

  @override
  String get documents_subtitle =>
      'Generate professional financial documents with AI assistance';

  @override
  String get documents_loanApplication => 'Loan Application';

  @override
  String get documents_loanDesc => 'Apply for personal, home, or vehicle loans';

  @override
  String get documents_invoice => 'Invoice';

  @override
  String get documents_invoiceDesc =>
      'Generate professional invoices for goods or services';

  @override
  String get documents_receipt => 'Payment Receipt';

  @override
  String get documents_receiptDesc => 'Issue receipts for payments received';

  @override
  String get documents_projectReport => 'Project Report';

  @override
  String get documents_projectDesc =>
      'Create detailed project or business reports';

  @override
  String get documents_generatePdf => 'Generate PDF';

  @override
  String get documents_generating => 'Generating...';

  @override
  String get documents_saved => 'Document saved';

  @override
  String get documents_open => 'Open';

  @override
  String get brainstorm_title => 'Brainstorm';

  @override
  String get brainstorm_subtitle => 'AI-powered financial brainstorming';

  @override
  String get profile_title => 'Profile';

  @override
  String get profile_settings => 'Settings';

  @override
  String get profile_language => 'Language';

  @override
  String get profile_theme => 'Theme';

  @override
  String get profile_notifications => 'Notifications';

  @override
  String get profile_about => 'About';

  @override
  String get profile_logout => 'Logout';

  @override
  String get profile_version => 'Version';

  @override
  String get auth_login => 'Login';

  @override
  String get auth_register => 'Register';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_confirmPassword => 'Confirm Password';

  @override
  String get auth_forgotPassword => 'Forgot Password?';

  @override
  String get auth_noAccount => 'Don\'t have an account?';

  @override
  String get auth_hasAccount => 'Already have an account?';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_error => 'Error';

  @override
  String get common_success => 'Success';

  @override
  String get common_required => 'Required';

  @override
  String get common_amount => 'Amount';

  @override
  String get common_description => 'Description';

  @override
  String get common_date => 'Date';

  @override
  String get common_category => 'Category';

  @override
  String get common_type => 'Type';

  @override
  String get currency_symbol => '₹';

  @override
  String currency_format(String amount) {
    return '₹$amount';
  }

  @override
  String get insight_excellent => 'Excellent savings this month!';

  @override
  String get insight_onTrack => 'You\'re on track with your goals!';

  @override
  String get insight_needsAttention => 'Spending alert';

  @override
  String get insight_steady => 'Steady progress';
}
