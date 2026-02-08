import 'package:flutter/material.dart';
import '../theme/wealthin_theme.dart';

/// Centralized category definitions for the entire app.
/// Use these constants throughout the app to ensure consistency
/// between transactions, budgets, and analytics.
class Categories {
  Categories._(); // Private constructor to prevent instantiation

  // ==================== EXPENSE CATEGORIES ====================
  
  static const List<String> expense = [
    'Food & Dining',
    'Groceries',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Education',
    'Investment',
    'Insurance',
    'EMI & Loans',
    'Rent & Housing',
    'Personal Care',
    'Travel',
    'Subscriptions',
    'Transfer',
    'Other',
  ];

  // ==================== INCOME CATEGORIES ====================
  
  static const List<String> income = [
    'Salary & Income',
    'Business',
    'Freelance',
    'Investment Returns',
    'Rental Income',
    'Dividend',
    'Interest',
    'Gift',
    'Refund',
    'Other Income',
  ];

  // ==================== ALL CATEGORIES ====================
  
  /// Combined list of all categories
  static List<String> get all => [...expense, ...income];

  // ==================== BUDGET CATEGORIES ====================
  
  /// Categories suitable for budgeting (expense categories only)
  static List<String> get budgetable => expense.where((c) => c != 'Transfer').toList();

  // ==================== ICONS ====================
  
  static const Map<String, IconData> icons = {
    // Expense
    'Food & Dining': Icons.restaurant,
    'Groceries': Icons.local_grocery_store,
    'Transportation': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Entertainment': Icons.movie,
    'Utilities': Icons.lightbulb,
    'Healthcare': Icons.medical_services,
    'Education': Icons.school,
    'Investment': Icons.trending_up,
    'Insurance': Icons.security,
    'EMI & Loans': Icons.credit_card,
    'Rent & Housing': Icons.home,
    'Personal Care': Icons.face,
    'Travel': Icons.flight,
    'Subscriptions': Icons.subscriptions,
    'Transfer': Icons.compare_arrows,
    'Other': Icons.category,
    // Income
    'Salary & Income': Icons.attach_money,
    'Business': Icons.business,
    'Freelance': Icons.work,
    'Investment Returns': Icons.show_chart,
    'Rental Income': Icons.apartment,
    'Dividend': Icons.pie_chart,
    'Interest': Icons.percent,
    'Gift': Icons.card_giftcard,
    'Refund': Icons.replay,
    'Other Income': Icons.add_circle,
  };

  /// Get icon for a category, with fallback
  static IconData getIcon(String category) {
    return icons[category] ?? Icons.category;
  }

  // ==================== COLORS ====================
  
  static Map<String, Color> get colors => {
    // Expense
    'Food & Dining': Colors.orange,
    'Groceries': Colors.green,
    'Transportation': Colors.blue,
    'Shopping': Colors.pink,
    'Entertainment': Colors.purple,
    'Utilities': Colors.yellow.shade700,
    'Healthcare': Colors.red,
    'Education': Colors.teal,
    'Investment': WealthInTheme.emerald,
    'Insurance': Colors.indigo,
    'EMI & Loans': Colors.deepOrange,
    'Rent & Housing': Colors.brown,
    'Personal Care': Colors.pinkAccent,
    'Travel': Colors.cyan,
    'Subscriptions': Colors.deepPurple,
    'Transfer': Colors.grey,
    'Other': Colors.blueGrey,
    // Income
    'Salary & Income': Colors.green.shade800,
    'Business': Colors.teal.shade700,
    'Freelance': Colors.blue.shade700,
    'Investment Returns': WealthInTheme.emerald,
    'Rental Income': Colors.amber.shade700,
    'Dividend': Colors.purple.shade700,
    'Interest': Colors.cyan.shade700,
    'Gift': Colors.pink.shade400,
    'Refund': Colors.lime.shade700,
    'Other Income': Colors.grey.shade600,
  };

  /// Get color for a category, with fallback
  static Color getColor(String category) {
    return colors[category] ?? Colors.grey;
  }

  // ==================== CATEGORY KEYWORDS (for auto-categorization) ====================
  
  static const Map<String, List<String>> keywords = {
    'Food & Dining': [
      'swiggy', 'zomato', 'restaurant', 'cafe', 'food', 'dining', 'lunch', 'dinner',
      'breakfast', 'biryani', 'pizza', 'burger', 'chai', 'coffee', 'tea', 'snacks',
      'mess', 'canteen', 'dhaba', 'hotel', 'eatsure', 'dominos', 'kfc', 'mcdonalds',
      'subway', 'haldiram', 'barbeque', 'freshmen', 'behrouz', 'starbucks', 'burger king',
      'pizza hut', 'bistro', 'diner', 'coffee day', 'ccd', 'tim hortons', 'taco bell',
      'oven story', 'faasos', 'box8', 'wow momo'
    ],
    'Groceries': [
      'bigbasket', 'grofers', 'blinkit', 'zepto', 'dmart', 'reliance fresh',
      'more megastore', 'grocery', 'vegetables', 'fruits', 'kirana', 'supermarket',
      'provision', 'ration', 'jiomart', 'amazon fresh', "nature's basket", "spencer's",
      'daily needs', 'milk', 'dairy', 'bakery', 'meat', 'fish'
    ],
    'Transportation': [
      'uber', 'ola', 'rapido', 'metro', 'bus', 'railway', 'irctc', 'petrol', 'diesel',
      'fuel', 'parking', 'toll', 'fastag', 'auto', 'cab', 'taxi', 'flight', 'air',
      'indigo', 'spicejet', 'vistara', 'redbus', 'makemytrip', 'cleartrip', 'goibibo',
      'yatra', 'ixigo', 'blue smart', 'indriver', 'rly', 'rail', 'shell', 'hpcl', 'bpcl', 'ioc'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'snapdeal',
      'shopclues', 'paytm mall', 'tata cliq', 'lifestyle', 'westside', 'pantaloons',
      'max', 'h&m', 'zara', 'uniqlo', 'decathlon', 'croma', 'reliance digital',
      'trends', 'zudio', 'nike', 'adidas', 'puma', 'skechers', "levi's", 'marks & spencer'
    ],
    'Entertainment': [
      'netflix', 'prime video', 'hotstar', 'disney', 'youtube', 'spotify', 'gaana',
      'jio saavn', 'pvr', 'inox', 'bookmyshow', 'cinema', 'movie', 'games', 'pubg',
      'dream11', 'fantasy', 'subscription', 'ott', 'cinepolis', 'apple music', 'audible',
      'sony liv', 'zee5', 'gaming', 'steam', 'playstation', 'xbox'
    ],
    'Utilities': [
      'electricity', 'water', 'gas', 'broadband', 'internet', 'wifi', 'jio', 'airtel',
      'vi', 'vodafone', 'bsnl', 'act fibernet', 'tata sky', 'dish tv', 'dth',
      'mobile recharge', 'postpaid', 'prepaid', 'phone bill', 'bescom', 'bwssb',
      'mahavitaran', 'adhani', 'torrent power', 'billdesk', 'razorpay'
    ],
    'Healthcare': [
      'hospital', 'clinic', 'doctor', 'pharma', 'pharmacy', 'medicine', 'apollo',
      'medplus', 'netmeds', '1mg', 'pharmeasy', 'tata 1mg', 'diagnostic', 'lab',
      'pathology', 'consultation', 'health', 'medical', 'dental', 'eye', 'practo',
      'cult.fit', 'gym', 'fitness'
    ],
    'Education': [
      'school', 'college', 'university', 'course', 'udemy', 'coursera', 'unacademy',
      'byju', 'vedantu', 'books', 'stationery', 'tuition', 'coaching', 'exam',
      'fees', 'library', 'kindle', 'skillshare'
    ],
    'Investment': [
      'mutual fund', 'sip', 'zerodha', 'groww', 'upstox', 'angel', 'stocks', 'shares',
      'trading', 'demat', 'nse', 'bse', 'investment', 'fd', 'fixed deposit',
      'ppf', 'nps', 'bonds', 'gold', 'sovereign', 'smallcase', 'kuvera', 'indmoney'
    ],
    'Insurance': [
      'insurance', 'lic', 'hdfc life', 'icici pru', 'max life', 'term', 'health insurance',
      'motor insurance', 'policy', 'premium', 'policybazaar', 'digit', 'acko', 'navi'
    ],
    'EMI & Loans': [
      'emi', 'loan', 'installment', 'credit card', 'bajaj', 'hdfc', 'icici', 'sbi',
      'home loan', 'car loan', 'personal loan', 'education loan', 'bnpl', 'simpl', 'lazypay'
    ],
    'Salary & Income': [
      'salary', 'wages', 'income', 'payroll', 'credit', 'inward', 'received',
      'payment received', 'freelance', 'bonus', 'incentive', 'commission', 'refund', 'interest'
    ],
    'Transfer': [
      'transfer', 'neft', 'imps', 'rtgs', 'upi', 'gpay', 'phonepe', 'paytm',
      'bhim', 'self transfer', 'fund transfer', 'account transfer', 'cred'
    ],
    'Rent & Housing': [
      'rent', 'house rent', 'pg', 'hostel', 'accommodation', 'maintenance',
      'society', 'apartment', 'flat', 'deposit', 'caution', 'nobroker'
    ],
    'Personal Care': [
      'salon', 'spa', 'parlour', 'haircut', 'beauty', 'cosmetics', 'skincare',
      'grooming', 'urban company', 'looks', 'javed habib'
    ],
    'Travel': [
      'trip', 'vacation', 'holiday', 'oyo', 'airbnb', 'booking.com', 'agoda',
      'trivago', 'hotels', 'resort', 'travel', 'tourism'
    ],
    'Subscriptions': [
      'subscription', 'membership', 'premium', 'annual', 'monthly plan',
      'cloud storage', 'icloud', 'google one', 'dropbox'
    ],
  };

  /// Categorize a transaction description
  static String categorize(String description) {
    if (description.isEmpty) return 'Other';
    
    final descLower = description.toLowerCase();
    
    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (descLower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    
    return 'Other';
  }

  // ==================== CATEGORY TYPE HELPERS ====================
  
  /// Check if a category is an income category
  static bool isIncome(String category) {
    return income.contains(category);
  }

  /// Check if a category is an expense category
  static bool isExpense(String category) {
    return expense.contains(category);
  }

  /// Get categories for a transaction type
  static List<String> getForType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'income' || lowerType == 'credit' || lowerType == 'deposit') {
      return income;
    }
    return expense;
  }

  // ==================== CATEGORY NORMALIZATION ====================
  
  /// Normalize category name to match standard categories
  /// Handles legacy category names and variations
  static String normalize(String category) {
    final lower = category.toLowerCase().trim();
    
    // Handle legacy/alternate names
    final mappings = {
      'food': 'Food & Dining',
      'food & dining': 'Food & Dining',
      'transport': 'Transportation',
      'transportation': 'Transportation',
      'bills': 'Utilities',
      'bills & utilities': 'Utilities',
      'utilities': 'Utilities',
      'health': 'Healthcare',
      'healthcare': 'Healthcare',
      'medical': 'Healthcare',
      'shopping': 'Shopping',
      'entertainment': 'Entertainment',
      'education': 'Education',
      'investment': 'Investment',
      'salary': 'Salary & Income',
      'income': 'Salary & Income',
      'salary & income': 'Salary & Income',
      'rent': 'Rent & Housing',
      'rent/housing': 'Rent & Housing',
      'rent & housing': 'Rent & Housing',
      'housing': 'Rent & Housing',
      'personal': 'Personal Care',
      'personal care': 'Personal Care',
      'groceries': 'Groceries',
      'grocery': 'Groceries',
      'emi': 'EMI & Loans',
      'emi & loans': 'EMI & Loans',
      'loans': 'EMI & Loans',
      'insurance': 'Insurance',
      'transfer': 'Transfer',
      'travel': 'Travel',
      'subscriptions': 'Subscriptions',
      'other': 'Other',
      'other income': 'Other Income',
    };
    
    return mappings[lower] ?? category;
  }
}
