/// Transaction model for the Flutter app
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
      paymentMethod: json['payment_method'] as String?,
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
      'payment_method': paymentMethod,
      'userProfileId': userProfileId,
    };
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}

/// Budget model
class BudgetModel {
  final int? id;
  final String name;
  final double amount;
  final double spent;
  final String icon;
  final int? userProfileId;

  BudgetModel({
    this.id,
    required this.name,
    required this.amount,
    this.spent = 0,
    this.icon = 'Default',
    this.userProfileId,
  });

  double get remaining => amount - spent;
  double get progress => amount > 0 ? (spent / amount).clamp(0, 1) : 0;
  bool get isOverBudget => spent > amount;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
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
  final bool isDefault;
  final int? userProfileId;

  GoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.isDefault = false,
    this.userProfileId,
  });

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0, 1) : 0;
  bool get isCompleted => currentAmount >= targetAmount;

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      userProfileId: json['userProfileId'] as int?,
    );
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
