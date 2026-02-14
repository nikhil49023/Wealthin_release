import 'dart:math' as math;

/// Financial Calculator Service
/// Pure Dart implementation of financial formulas.
/// Replaces the Python backend calculator service for instant, offline results.
class FinancialCalculator {
  
  // ==================== INVESTMENT CALCULATORS ====================

  /// Calculate SIP (Systematic Investment Plan) Returns
  static Map<String, dynamic> calculateSIP({
    required double monthlyInvestment,
    required double expectedRate, // Annual rate in %
    required int durationMonths,
  }) {
    final monthlyRate = expectedRate / 12 / 100;
    
    double futureValue;
    if (monthlyRate == 0) {
      futureValue = monthlyInvestment * durationMonths;
    } else {
      // FV = P × ((1 + r)^n - 1) / r × (1 + r)
      futureValue = monthlyInvestment * 
                   ((math.pow(1 + monthlyRate, durationMonths) - 1) / monthlyRate) * 
                   (1 + monthlyRate);
    }

    final totalInvested = monthlyInvestment * durationMonths;
    final wealthGained = futureValue - totalInvested;

    return {
      'monthly_investment': monthlyInvestment,
      'duration_months': durationMonths,
      'expected_rate': expectedRate,
      'total_invested': totalInvested.roundToDouble(),
      'future_value': futureValue.roundToDouble(),
      'wealth_gained': wealthGained.roundToDouble(),
      'returns_percentage': totalInvested > 0 
          ? ((wealthGained / totalInvested) * 100).toStringAsFixed(2) 
          : "0.00"
    };
  }

  /// Calculate FD (Fixed Deposit) Maturity
  static Map<String, dynamic> calculateFD({
    required double principal,
    required double rate, // Annual rate in %
    required int tenureMonths,
    String compounding = "quarterly", // Not used in simple formula, assuming quarterly by default standards
  }) {
    // Standard quarterly compounding for Indian FDs
    const n = 4.0; 
    final r = rate / 100;
    final t = tenureMonths / 12;

    // A = P(1 + r/n)^(nt)
    final maturityAmount = principal * math.pow(1 + r / n, n * t);
    final interestEarned = maturityAmount - principal;
    final effectiveAnnualRate = (math.pow(1 + r / n, n) - 1) * 100;

    return {
      'principal': principal,
      'rate': rate,
      'tenure_months': tenureMonths,
      'maturity_amount': maturityAmount.roundToDouble(),
      'interest_earned': interestEarned.roundToDouble(),
      'effective_annual_rate': effectiveAnnualRate.toStringAsFixed(2)
    };
  }

  /// Calculate RD (Recurring Deposit) Maturity
  static Map<String, dynamic> calculateRD({
    required double monthlyDeposit,
    required double rate, // Annual rate in %
    required int tenureMonths,
  }) {
    // RD Formula with Quarterly Compounding
    final quarterlyRate = rate / 4 / 100;
    double maturityAmount = 0;

    for (int month = 0; month < tenureMonths; month++) {
      // Each installment earns interest for the remaining period
      // This is a simplified iterative approach accurate for standard RDs
      final remainingQuarters = (tenureMonths - month) / 3;
      final amount = monthlyDeposit * math.pow(1 + quarterlyRate, remainingQuarters);
      maturityAmount += amount;
    }

    final totalDeposited = monthlyDeposit * tenureMonths;
    final interestEarned = maturityAmount - totalDeposited;

    return {
      'monthly_deposit': monthlyDeposit,
      'rate': rate,
      'tenure_months': tenureMonths,
      'maturity_amount': maturityAmount.roundToDouble(),
      'total_deposited': totalDeposited.roundToDouble(),
      'interest_earned': interestEarned.roundToDouble()
    };
  }

  /// Calculate Compound Interest (Lumpsum with optional monthly contribution)
  static Map<String, dynamic> calculateCompoundInterest({
    required double principal,
    required double rate, // Annual rate in %
    required int years,
    double monthlyContribution = 0,
  }) {
    final r = rate / 100;
    const n = 12; // Monthly compounding standard
    final t = years;

    // Future Value of Initial Principal
    final fvPrincipal = principal * math.pow(1 + r / n, n * t);

    // Future Value of Monthly Contributions
    // FV = PMT * (((1 + r/n)^(n*t) - 1) / (r/n))
    double fvContributions = 0;
    if (monthlyContribution > 0) {
      if (r > 0) {
        fvContributions = monthlyContribution * (((math.pow(1 + r / n, n * t) - 1) / (r / n)));
      } else {
        fvContributions = monthlyContribution * n * t;
      }
    }

    final totalAmount = fvPrincipal + fvContributions;
    final totalContributed = principal + (monthlyContribution * n * t);
    final interestEarned = totalAmount - totalContributed;

    return {
      'total_amount': totalAmount.roundToDouble(),
      'interest_earned': interestEarned.roundToDouble(),
      'total_contributed': totalContributed.roundToDouble(),
      'years': years
    };
  }

  // ==================== LOAN CALCULATORS ====================

  /// Calculate EMI (Equated Monthly Installment)
  static Map<String, dynamic> calculateEMI({
    required double principal,
    required double rate, // Annual rate in %
    required int tenureMonths,
  }) {
    final monthlyRate = rate / 12 / 100;
    
    double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      // E = P * r * (1+r)^n / ((1+r)^n - 1)
      emi = principal * monthlyRate * 
            (math.pow(1 + monthlyRate, tenureMonths)) / 
            ((math.pow(1 + monthlyRate, tenureMonths) - 1));
    }

    final totalPayment = emi * tenureMonths;
    final totalInterest = totalPayment - principal;

    return {
      'principal': principal,
      'rate': rate,
      'tenure_months': tenureMonths,
      'emi': emi.roundToDouble(),
      'total_payment': totalPayment.roundToDouble(),
      'total_interest': totalInterest.roundToDouble()
    };
  }

  // ==================== FINANCIAL HEALTH CALCULATORS ====================

  /// Calculate Savings Rate (%)
  static double calculateSavingsRate(double income, double expenses) {
    if (income <= 0) return 0.0;
    final rate = ((income - expenses) / income) * 100;
    return double.parse(rate.toStringAsFixed(2));
  }

  /// Calculate Per Capita Income (Income per family member)
  static double calculatePerCapitaIncome(double totalIncome, int familySize) {
    if (familySize <= 0) return 0.0;
    return double.parse((totalIncome / familySize).toStringAsFixed(2));
  }

  /// Evaluate Emergency Fund Status
  static Map<String, dynamic> calculateEmergencyFundStatus({
    required double currentSavings,
    required double monthlyExpenses,
    int targetMonths = 6,
  }) {
    final targetAmount = monthlyExpenses * targetMonths;
    if (targetAmount == 0) {
      return {
        "status": "Complete", 
        "percentage": 100.0, 
        "shortfall": 0.0,
        "months_covered": 0.0,
        "health_status": "Complete"
      };
    }

    final percentComplete = (currentSavings / targetAmount) * 100;
    final shortfall = math.max(0.0, targetAmount - currentSavings);
    final monthsCovered = monthlyExpenses > 0 ? (currentSavings / monthlyExpenses) : 0.0;

    String status = "Critical";
    if (percentComplete >= 100) {
      status = "Excellent";
    } else if (percentComplete >= 80) status = "Good";
    else if (percentComplete >= 50) status = "Fair";
    else if (percentComplete >= 20) status = "Poor";

    return {
      "target_amount": targetAmount,
      "current_amount": currentSavings,
      "shortfall": shortfall,
      "percentage": double.parse(percentComplete.toStringAsFixed(1)),
      "health_status": status,
      "months_covered": double.parse(monthsCovered.toStringAsFixed(1))
    };
  }
}
