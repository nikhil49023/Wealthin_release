import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Transaction Categorizer — RegExp-based pipeline with confidence scoring
/// Runs offline in Dart. Categories aligned with Indian spending patterns.
class TransactionCategorizer {

  static const String other = 'Other';

  // Each entry: category → list of regex patterns (compiled once)
  // Brand/merchant exact names have higher rank (checked first)
  static final Map<String, List<RegExp>> _categoryRegex = _buildRegex({
    'Food & Dining': [
      r'\b(swiggy|zomato|eatsure|faasos|box8|wow[ -]?momo|behrouz|oven[ -]?story)\b',
      r'\b(dominos?|kfc|mcdonalds?|subway|pizza[ -]?hut|burger[ -]?king|taco[ -]?bell)\b',
      r'\b(starbucks|ccd|coffee[ -]?day|bistro|diner|haldiram|barbeque[ -]?nation)\b',
      r'\b(restaurant|cafe|food|dining|lunch|dinner|breakfast|snack|canteen|dhaba|mess)\b',
      r'\b(biryani|pizza|burger|chai|coffee|tea)\b',
    ],
    'Groceries': [
      r'\b(bigbasket|grofers|blinkit|zepto|jiomart|amazon[ -]?fresh|nature.?s[ -]?basket)\b',
      r'\b(dmart|reliance[ -]?fresh|more[ -]?megastore|spencer.?s)\b',
      r'\b(grocery|groceries|vegetable|fruit|kirana|supermarket|provision|ration|dairy|bakery)\b',
      r'\b(milk|meat|fish|eggs?)\b',
    ],
    'Transportation': [
      r'\b(uber|ola|rapido|indriver|blue[ -]?smart)\b',
      r'\b(irctc|redbus|makemytrip|cleartrip|goibibo|yatra|ixigo)\b',
      r'\b(indigo|spicejet|vistara|air[ -]?india|go[ -]?air)\b',
      r'\b(fastag|petrol|diesel|fuel|hpcl|bpcl|ioc|shell)\b',
      r'\b(metro|bus|railway|rly|auto|cab|taxi|parking|toll)\b',
    ],
    'Shopping': [
      r'\b(amazon|flipkart|myntra|ajio|nykaa|meesho|snapdeal|shopclues|tata[ -]?cliq)\b',
      r'\b(lifestyle|westside|pantaloons|max|h&m|zara|uniqlo|levi.?s|marks?[ -]?spencer)\b',
      r'\b(decathlon|croma|reliance[ -]?digital|trends|zudio)\b',
      r'\b(nike|adidas|puma|skechers)\b',
      r'\b(shopping|purchase)\b',
    ],
    'Entertainment': [
      r'\b(netflix|prime[ -]?video|hotstar|disney|youtube|spotify|gaana|jio[ -]?saavn|apple[ -]?music|audible)\b',
      r'\b(pvr|inox|bookmyshow|cinepolis|cinema|movie)\b',
      r'\b(dream11|fantasy|pubg|steam|playstation|xbox|gaming)\b',
      r'\b(sony[ -]?liv|zee5|ott|subscription)\b',
    ],
    'Utilities': [
      r'\b(jio|airtel|vi|vodafone|bsnl|act[ -]?fibernet)\b',
      r'\b(tata[ -]?sky|dish[ -]?tv|dth)\b',
      r'\b(bescom|bwssb|mahavitaran|torrent[ -]?power|adani[ -]?electricity)\b',
      r'\b(electricity|water[ -]?bill|gas[ -]?bill|broadband|internet|wifi)\b',
      r'\b(mobile[ -]?recharge|postpaid|prepaid|phone[ -]?bill|billdesk)\b',
    ],
    'Healthcare': [
      r'\b(apollo|medplus|netmeds|1mg|pharmeasy|tata[ -]?1mg|practo|cult\.?fit)\b',
      r'\b(hospital|clinic|doctor|pharmacy|pharma|medicine|diagnostic|lab|patholog)\b',
      r'\b(dental|optical|gym|fitness|health|medical|consultation)\b',
    ],
    'Education': [
      r'\b(udemy|coursera|unacademy|byjus?|vedantu|skillshare|kindle)\b',
      r'\b(school|college|university|coaching|tuition|exam[ -]?fee)\b',
      r'\b(books?|stationer|library|course[ -]?fee)\b',
    ],
    'SIP / Mutual Fund': [
      r'\b(sip|systematic[ -]?investment|mutual[ -]?fund|zerodha|groww|upstox|angel[ -]?one)\b',
      r'\b(smallcase|kuvera|indmoney|paytm[ -]?money|coin[ -]?zerodha)\b',
    ],
    'Investment': [
      r'\b(ppf|nps|elss|sgb|sovereign[ -]?gold|scss|nsc|fixed[ -]?deposit|fd|rd)\b',
      r'\b(stocks?|shares?|trading|demat|nse|bse|bonds?|gold[ -]?fund)\b',
      r'\b(investment|invest)\b',
    ],
    'Insurance': [
      r'\b(lic|hdfc[ -]?life|icici[ -]?pru|max[ -]?life|term[ -]?plan|health[ -]?insurance)\b',
      r'\b(motor[ -]?insurance|policybazaar|digit[ -]?insurance|acko|navi)\b',
      r'\b(insurance|insured|premium[ -]?paid|policy)\b',
    ],
    'EMI & Loans': [
      r'\b(emi|equated[ -]?monthly|home[ -]?loan|car[ -]?loan|personal[ -]?loan|education[ -]?loan)\b',
      r'\b(bajaj[ -]?finance|hdfc[ -]?bank|icici[ -]?bank|sbi|kotak|axis[ -]?bank)\b',
      r'\b(bnpl|simpl|lazypay|installment|repayment|loan[ -]?repay)\b',
    ],
    'Salary & Income': [
      r'\b(salary|wages|payroll|stipend|remuneration)\b',
      r'\b(interest[ -]?credit|dividend|bonus|incentive|commission)\b',
      r'\b(refund|cashback|reward|payment[ -]?received)\b',
    ],
    'Transfer': [
      r'\b(neft|imps|rtgs|upi|gpay|google[ -]?pay|phonepe|paytm|bhim|cred)\b',
      r'\b(fund[ -]?transfer|self[ -]?transfer|account[ -]?transfer)\b',
    ],
    'Rent & Housing': [
      r'\b(house[ -]?rent|pg|paying[ -]?guest|hostel|accommodation|society[ -]?maintenance)\b',
      r'\b(nobroker|magicbricks|99acres|flat[ -]?rent|apartment[ -]?rent|deposit)\b',
      r'\b(rent)\b',
    ],
    'Personal Care': [
      r'\b(urban[ -]?company|looks|javed[ -]?habib|naturals[ -]?salon)\b',
      r'\b(salon|spa|parlour|haircut|beauty|cosmetics?|skincare|grooming)\b',
    ],
    'ATM / Cash': [
      r'\b(atm[ -]?withdrawal|cash[ -]?withdrawal|atm)\b',
    ],
    'Crypto': [
      r'\b(bitcoin|btc|ethereum|eth|crypto|wazirx|coindcx|binance|usdt)\b',
    ],
  });

  static Map<String, List<RegExp>> _buildRegex(Map<String, List<String>> raw) {
    return raw.map((cat, patterns) => MapEntry(
      cat,
      patterns.map((p) => RegExp(p, caseSensitive: false)).toList(),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// All supported category names
  static List<String> get categories => _categoryRegex.keys.toList();

  /// Categorize a transaction description, returning category + confidence.
  static CategorizeResult categorize(String description) {
    if (description.isEmpty) return CategorizeResult(category: other, confidence: 0.0);

    // Check each category in order; first-match wins within a category
    for (final entry in _categoryRegex.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].hasMatch(description)) {
          // Earlier patterns = brand-level match = higher confidence
          final confidence = i == 0 ? 1.0 : (i == 1 ? 0.9 : 0.75);
          return CategorizeResult(category: entry.key, confidence: confidence);
        }
      }
    }
    return CategorizeResult(category: other, confidence: 0.0);
  }

  /// Convenience: returns just the category string (backwards compatible)
  static String categorizeSimple(String description) =>
      categorize(description).category;

  /// Get icon for category
  static IconData getIcon(String category) {
    switch (category) {
      case 'Food & Dining':        return Icons.restaurant_rounded;
      case 'Groceries':            return Icons.local_grocery_store_rounded;
      case 'Transportation':       return Icons.directions_car_rounded;
      case 'Shopping':             return Icons.shopping_bag_rounded;
      case 'Entertainment':        return Icons.movie_rounded;
      case 'Utilities':            return Icons.bolt_rounded;
      case 'Healthcare':           return Icons.medical_services_rounded;
      case 'Education':            return Icons.school_rounded;
      case 'SIP / Mutual Fund':    return Icons.trending_up_rounded;
      case 'Investment':           return Icons.show_chart_rounded;
      case 'Insurance':            return Icons.security_rounded;
      case 'EMI & Loans':          return Icons.credit_card_rounded;
      case 'Salary & Income':      return Icons.account_balance_rounded;
      case 'Transfer':             return Icons.compare_arrows_rounded;
      case 'Rent & Housing':       return Icons.home_rounded;
      case 'Personal Care':        return Icons.face_rounded;
      case 'ATM / Cash':           return Icons.local_atm_rounded;
      case 'Crypto':               return Icons.currency_bitcoin_rounded;
      default:                     return Icons.category_rounded;
    }
  }

  /// Get theme-palette colour for category
  static Color getColor(String category) {
    switch (category) {
      case 'Food & Dining':        return AppTheme.saffron;
      case 'Groceries':            return AppTheme.success;
      case 'Transportation':       return AppTheme.peacockTeal;
      case 'Shopping':             return AppTheme.lotusPink;
      case 'Entertainment':        return const Color(0xFF9966CC);
      case 'Utilities':            return AppTheme.warning;
      case 'Healthcare':           return AppTheme.error;
      case 'Education':            return AppTheme.peacockLight;
      case 'SIP / Mutual Fund':    return AppTheme.successLight;
      case 'Investment':           return AppTheme.success;
      case 'Insurance':            return const Color(0xFF5C6BC0);
      case 'EMI & Loans':          return const Color(0xFFEF6C00);
      case 'Salary & Income':      return AppTheme.champagneGold;
      case 'Transfer':             return AppTheme.silverMist;
      case 'Rent & Housing':       return const Color(0xFF795548);
      case 'Personal Care':        return AppTheme.lotusPink;
      case 'ATM / Cash':           return const Color(0xFF78909C);
      case 'Crypto':               return const Color(0xFFF7931A);
      default:                     return AppTheme.silverMist;
    }
  }
}

/// Result of a categorization operation
class CategorizeResult {
  final String category;
  /// Confidence: 1.0 = brand-exact match, 0.75 = keyword match, 0.0 = unmatched
  final double confidence;

  const CategorizeResult({required this.category, required this.confidence});

  bool get isConfident => confidence >= 0.75;
  bool get isMatched   => category != TransactionCategorizer.other;
}
