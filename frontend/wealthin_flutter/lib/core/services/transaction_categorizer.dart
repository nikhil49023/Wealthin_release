import 'package:flutter/material.dart';
import '../../core/theme/wealthin_theme.dart';

/// Service for categorizing transactions based on description keywords.
/// Runs natively in Dart (offline).
class TransactionCategorizer {
  
  static const String otherParams = "Other";

  static const Map<String, List<String>> _categoryKeywords = {
    "Food & Dining": [
      "swiggy", "zomato", "restaurant", "cafe", "food", "dining", "lunch", "dinner",
      "breakfast", "biryani", "pizza", "burger", "chai", "coffee", "tea", "snacks",
      "mess", "canteen", "dhaba", "hotel", "eatsure", "dominos", "kfc", "mcdonalds",
      "subway", "haldiram", "barbeque", "freshmen", "behrouz", "starbucks", "burger king",
      "pizza hut", "bistro", "diner", "coffee day", "ccd", "tim hortons", "taco bell",
      "oven story", "faasos", "box8", "wow momo"
    ],
    "Groceries": [
      "bigbasket", "grofers", "blinkit", "zepto", "dmart", "reliance fresh",
      "more megastore", "grocery", "vegetables", "fruits", "kirana", "supermarket",
      "provision", "ration", "jiomart", "amazon fresh", "nature's basket", "spencer's",
      "daily needs", "milk", "dairy", "bakery", "meat", "fish"
    ],
    "Transportation": [
      "uber", "ola", "rapido", "metro", "bus", "railway", "irctc", "petrol", "diesel",
      "fuel", "parking", "toll", "fastag", "auto", "cab", "taxi", "flight", "air",
      "indigo", "spicejet", "vistara", "redbus", "makemytrip", "cleartrip", "goibibo",
      "yatra", "ixigo", "blue smart", "indriver", "rly", "rail", "shell", "hpcl", "bpcl", "ioc"
    ],
    "Shopping": [
      "amazon", "flipkart", "myntra", "ajio", "nykaa", "meesho", "snapdeal",
      "shopclues", "paytm mall", "tata cliq", "lifestyle", "westside", "pantaloons",
      "max", "h&m", "zara", "uniqlo", "decathlon", "croma", "reliance digital",
      "trends", "zudio", "nike", "adidas", "puma", "skechers", "levi's", "marks & spencer"
    ],
    "Entertainment": [
      "netflix", "prime video", "hotstar", "disney", "youtube", "spotify", "gaana",
      "jio saavn", "pvr", "inox", "bookmyshow", "cinema", "movie", "games", "pubg",
      "dream11", "fantasy", "subscription", "ott", "cinepolis", "apple music", "audible",
      "sony liv", "zee5", "gaming", "steam", "playstation", "xbox"
    ],
    "Utilities": [
      "electricity", "water", "gas", "broadband", "internet", "wifi", "jio", "airtel",
      "vi", "vodafone", "bsnl", "act fibernet", "tata sky", "dish tv", "dth",
      "mobile recharge", "postpaid", "prepaid", "phone bill", "bescom", "bwssb",
      "mahavitaran", "adhani", "torrent power", "billdesk", "razorpay"
    ],
    "Healthcare": [
      "hospital", "clinic", "doctor", "pharma", "pharmacy", "medicine", "apollo",
      "medplus", "netmeds", "1mg", "pharmeasy", "tata 1mg", "diagnostic", "lab",
      "pathology", "consultation", "health", "medical", "dental", "eye", "practo",
      "cult.fit", "gym", "fitness"
    ],
    "Education": [
      "school", "college", "university", "course", "udemy", "coursera", "unacademy",
      "byju", "vedantu", "books", "stationery", "tuition", "coaching", "exam",
      "fees", "library", "kindle", "skillshare"
    ],
    "Investment": [
      "mutual fund", "sip", "zerodha", "groww", "upstox", "angel", "stocks", "shares",
      "trading", "demat", "nse", "bse", "investment", "fd", "fixed deposit",
      "ppf", "nps", "bonds", "gold", "sovereign", "smallcase", "kuvera", "indmoney"
    ],
    "Insurance": [
      "insurance", "lic", "hdfc life", "icici pru", "max life", "term", "health insurance",
      "motor insurance", "policy", "premium", "policybazaar", "digit", "acko", "navi"
    ],
    "EMI & Loans": [
      "emi", "loan", "installment", "credit card", "bajaj", "hdfc", "icici", "sbi",
      "home loan", "car loan", "personal loan", "education loan", "bnpl", "simpl", "lazypay"
    ],
    "Salary & Income": [
      "salary", "wages", "income", "payroll", "credit", "inward", "received",
      "payment received", "freelance", "bonus", "incentive", "commission", "refund", "interest"
    ],
    "Transfer": [
      "transfer", "neft", "imps", "rtgs", "upi", "gpay", "phonepe", "paytm",
      "bhim", "self transfer", "fund transfer", "account transfer", "cred"
    ],
    "Rent & Housing": [
      "rent", "house rent", "pg", "hostel", "accommodation", "maintenance",
      "society", "apartment", "flat", "deposit", "caution", "nobroker"
    ],
    "Personal Care": [
      "salon", "spa", "parlour", "haircut", "beauty", "cosmetics", "skincare",
      "grooming", "urban company", "looks", "javed habib"
    ]
  };

  /// Get list of all supported categories
  static List<String> get categories => _categoryKeywords.keys.toList();

  /// Categorize transaction based on description
  static String categorize(String description) {
    if (description.isEmpty) return otherParams;
    
    final descLower = description.toLowerCase();
    
    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        if (descLower.contains(keyword)) {
          return category;
        }
      }
    }
    
    return otherParams;
  }

  /// Get icon for category
  static IconData getIcon(String category) {
    switch (category) {
      case "Food & Dining": return Icons.restaurant;
      case "Groceries": return Icons.local_grocery_store;
      case "Transportation": return Icons.directions_car;
      case "Shopping": return Icons.shopping_bag;
      case "Entertainment": return Icons.movie;
      case "Utilities": return Icons.lightbulb;
      case "Healthcare": return Icons.medical_services;
      case "Education": return Icons.school;
      case "Investment": return Icons.trending_up;
      case "Insurance": return Icons.security;
      case "EMI & Loans": return Icons.credit_card;
      case "Salary & Income": return Icons.attach_money;
      case "Transfer": return Icons.compare_arrows;
      case "Rent & Housing": return Icons.home;
      case "Personal Care": return Icons.face;
      default: return Icons.category;
    }
  }

  /// Get color for category
  static Color getColor(String category) {
    switch (category) {
      case "Food & Dining": return Colors.orange;
      case "Groceries": return Colors.green;
      case "Transportation": return Colors.blue;
      case "Shopping": return Colors.pink;
      case "Entertainment": return Colors.purple;
      case "Utilities": return Colors.yellow[700]!;
      case "Healthcare": return Colors.red;
      case "Education": return Colors.teal;
      case "Investment": return WealthInTheme.emerald;
      case "Insurance": return Colors.indigo;
      case "EMI & Loans": return Colors.deepOrange;
      case "Salary & Income": return Colors.green[800]!;
      case "Transfer": return Colors.grey;
      case "Rent & Housing": return Colors.brown;
      case "Personal Care": return Colors.pinkAccent;
      default: return Colors.grey;
    }
  }
}
