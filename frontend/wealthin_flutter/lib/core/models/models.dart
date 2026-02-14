class TransactionModel {
  final int? id;
  final double amount;
  final String description;
  final DateTime date;
  final String? time;
  final String? merchant;
  final String type; // 'income' or 'expense'
  final String category;
  final String? paymentMethod;
  final String? notes;
  final String? receiptUrl;
  final bool isRecurring;
  final DateTime? createdAt;
  final int? userProfileId;

  TransactionModel({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
    this.time,
    this.merchant,
    required this.type,
    required this.category,
    this.paymentMethod,
    this.notes,
    this.receiptUrl,
    this.isRecurring = false,
    this.createdAt,
    this.userProfileId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String?,
      merchant: json['merchant'] as String?,
      type: json['type'] as String,
      category: json['category'] as String,
      paymentMethod: json['paymentMethod'] as String? ?? json['payment_method'] as String?,
      notes: json['notes'] as String?,
      receiptUrl: json['receiptUrl'] as String? ?? json['receipt_url'] as String?,
      isRecurring: (json['isRecurring'] ?? json['is_recurring']) == 1 || (json['isRecurring'] ?? json['is_recurring']) == true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : 
                 (json['created_at'] != null ? DateTime.parse(json['created_at']) : null),
      userProfileId: json['userProfileId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'merchant': merchant,
      'type': type,
      'category': category,
      'paymentMethod': paymentMethod, // SQLite expects this or snake case? We used paymentMethod in createTable
      'notes': notes,
      'receiptUrl': receiptUrl,
      'isRecurring': isRecurring ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'userProfileId': userProfileId,
    };
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}

/// Budget model
class BudgetModel {
  final int? id;
  final String name; // Computed or from DB
  final String category; // Category identifier
  final double amount;
  final double spent;
  final String icon;
  final int? userProfileId;

  BudgetModel({
    this.id,
    required this.name,
    required this.category,
    required this.amount,
    this.spent = 0,
    this.icon = 'Default',
    this.userProfileId,
  });

  double get remaining => amount - spent;
  double get progress => amount > 0 ? (spent / amount).clamp(0, 1) : 0;
  bool get isOverBudget => spent > amount;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    // Handle both API (camelCase/custom) and SQLite (snake_case)
    // SQLite: category, limit_amount, spent_amount
    final category = json['category'] as String? ?? json['name'] as String? ?? 'other';
    return BudgetModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? category,
      category: category,
      amount: ((json['amount'] ?? json['limit_amount']) as num?)?.toDouble() ?? 0.0,
      spent: ((json['spent'] ?? json['spent_amount']) as num?)?.toDouble() ?? 0,
      icon: json['icon'] as String? ?? 'Default',
      userProfileId: json['userProfileId'] as int?,
    );
  }
}

/// Goal model
class GoalModel {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? deadline;
  final String status;
  final String icon;
  final String? notes;
  final bool isDefault;
  final int? userProfileId;

  GoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.status = 'active',
    this.icon = 'flag',
    this.notes,
    this.isDefault = false,
    this.userProfileId,
  });

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;
  bool get isCompleted => currentAmount >= targetAmount;

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      targetAmount: ((json['targetAmount'] ?? json['target_amount']) as num).toDouble(),
      currentAmount: ((json['currentAmount'] ?? json['saved_amount']) as num?)?.toDouble() ?? 0,
      deadline: json['deadline'] as String?,
      status: json['status'] as String? ?? 'active',
      icon: json['icon'] as String? ?? 'flag',
      notes: json['notes'] as String?,
      isDefault: (json['isDefault'] ?? json['is_default']) == 1 || (json['isDefault'] ?? json['is_default']) == true,
      userProfileId: json['userProfileId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline,
      'status': status,
      'icon': icon,
      'notes': notes,
      'isDefault': isDefault,
      'userProfileId': userProfileId,
    };
  }
}

/// Dashboard summary model
class DashboardSummary {
  final double totalIncome;
  final double totalExpenses;
  final int savingsRate;
  final String suggestion;

  DashboardSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.savingsRate,
    required this.suggestion,
  });

  double get netSavings => totalIncome - totalExpenses;
}

/// Merchant Rule model - for One-Click Flagging
class MerchantRule {
  final int? id;
  final String keyword;
  final String category;
  final bool isAuto;

  MerchantRule({
    this.id,
    required this.keyword,
    required this.category,
    this.isAuto = true,
  });

  factory MerchantRule.fromJson(Map<String, dynamic> json) {
    return MerchantRule(
      id: json['id'] as int?,
      keyword: json['keyword'] as String,
      category: json['category'] as String,
      isAuto: json['is_auto'] == true || json['is_auto'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'category': category,
      'is_auto': isAuto,
    };
  }
}

/// NCM (National Contribution Milestone) Score - Viksit Bharat 2047
class NCMScore {
  final double score;
  final String milestone;
  final String nextMilestone;
  final double progress;
  final double consumptionPoints;
  final double savingsPoints;
  final double taxPoints;

  NCMScore({
    required this.score,
    required this.milestone,
    required this.nextMilestone,
    required this.progress,
    this.consumptionPoints = 0,
    this.savingsPoints = 0,
    this.taxPoints = 0,
  });

  factory NCMScore.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    return NCMScore(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      milestone: json['milestone'] as String? ?? 'Citizen',
      nextMilestone: json['next_milestone'] as String? ?? 'Contributor',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      consumptionPoints: (breakdown['consumption'] as num?)?.toDouble() ?? 0,
      savingsPoints: (breakdown['savings'] as num?)?.toDouble() ?? 0,
      taxPoints: (breakdown['tax'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Insight Chip - Explainability for Investment Nudges
class InsightChip {
  final String type;  // surplus, yield, safety, goal, viksit
  final String icon;  // Material icon name
  final String label;
  final String value;

  InsightChip({
    required this.type,
    required this.icon,
    required this.label,
    required this.value,
  });

  factory InsightChip.fromJson(Map<String, dynamic> json) {
    return InsightChip(
      type: json['type'] as String? ?? '',
      icon: json['icon'] as String? ?? 'info',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

/// Investment Nudge - RBI Compliant (Information Only)
class InvestmentNudge {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String instrument; // RD, SGB, FD, liquid_fund, ppf
  final double expectedYield;
  final String actionText;
  final List<InsightChip> insightChips;

  InvestmentNudge({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.instrument,
    required this.expectedYield,
    required this.actionText,
    required this.insightChips,
  });

  factory InvestmentNudge.fromJson(Map<String, dynamic> json) {
    return InvestmentNudge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      instrument: json['instrument'] as String? ?? '',
      expectedYield: (json['expected_yield'] as num?)?.toDouble() ?? 0,
      actionText: json['action_text'] as String? ?? 'Open Bank App',
      insightChips: (json['insight_chips'] as List<dynamic>?)
              ?.map((c) => InsightChip.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Comprehensive Financial Health Score (0-100)
class HealthScore {
  final double totalScore;
  final String grade; // Excellent, Good, Fair, Poor
  final Map<String, double> breakdown;
  final List<String> insights;
  final String? aiAnalysis; // GPT-generated analysis from Groq

  HealthScore({
    required this.totalScore,
    required this.grade,
    required this.breakdown,
    required this.insights,
    this.aiAnalysis,
  });

  /// Create a copy with AI analysis added
  HealthScore withAiAnalysis(String analysis) {
    return HealthScore(
      totalScore: totalScore,
      grade: grade,
      breakdown: breakdown,
      insights: insights,
      aiAnalysis: analysis,
    );
  }

  factory HealthScore.fromJson(Map<String, dynamic> json) {
    final breakdownJson = json['breakdown'] as Map<String, dynamic>? ?? {};
    return HealthScore(
      totalScore: (json['score'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] as String? ?? 'Fair',
      breakdown: {
        'savings': (breakdownJson['savings'] as num?)?.toDouble() ?? 0,
        'debt': (breakdownJson['debt'] as num?)?.toDouble() ?? 0,
        'liquidity': (breakdownJson['liquidity'] as num?)?.toDouble() ?? 0,
        'investment': (breakdownJson['investment'] as num?)?.toDouble() ?? 0,
      },
      insights: (json['insights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aiAnalysis: json['ai_analysis'] as String?,
    );
  }
}
