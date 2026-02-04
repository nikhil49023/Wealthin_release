import 'dart:convert';
import 'dart:math' as math;
import 'package:serverpod/serverpod.dart';
import 'package:http/http.dart' as http;

/// Investment Calculator Endpoint
/// Connects to Python sidecar for advanced financial calculations
class InvestmentEndpoint extends Endpoint {
  // Python sidecar URL - configurable via environment
  static const String _sidecarUrl = 'http://localhost:8000';

  /// Calculate SIP (Systematic Investment Plan) returns
  Future<Map<String, dynamic>> calculateSIP(
    Session session,
    double monthlyInvestment,
    double expectedRate,
    int durationMonths,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/sip'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'monthly_investment': monthlyInvestment,
          'expected_rate': expectedRate,
          'duration_months': durationMonths,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // Fallback calculation
        return _calculateSIPLocal(
          monthlyInvestment,
          expectedRate,
          durationMonths,
        );
      }
    } catch (e) {
      session.log('SIP calculation error, using local: $e');
      return _calculateSIPLocal(
        monthlyInvestment,
        expectedRate,
        durationMonths,
      );
    }
  }

  /// Calculate FD (Fixed Deposit) maturity
  Future<Map<String, dynamic>> calculateFD(
    Session session,
    double principal,
    double rate,
    int tenureMonths, {
    String compounding = 'quarterly',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/fd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'principal': principal,
          'rate': rate,
          'tenure_months': tenureMonths,
          'compounding': compounding,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _calculateFDLocal(principal, rate, tenureMonths, compounding);
      }
    } catch (e) {
      session.log('FD calculation error, using local: $e');
      return _calculateFDLocal(principal, rate, tenureMonths, compounding);
    }
  }

  /// Calculate EMI (Equated Monthly Installment)
  Future<Map<String, dynamic>> calculateEMI(
    Session session,
    double principal,
    double rate,
    int tenureMonths, {
    bool includeAmortization = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/emi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'principal': principal,
          'rate': rate,
          'tenure_months': tenureMonths,
          'include_amortization': includeAmortization,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _calculateEMILocal(principal, rate, tenureMonths);
      }
    } catch (e) {
      session.log('EMI calculation error, using local: $e');
      return _calculateEMILocal(principal, rate, tenureMonths);
    }
  }

  /// Calculate RD (Recurring Deposit) maturity
  Future<Map<String, dynamic>> calculateRD(
    Session session,
    double monthlyDeposit,
    double rate,
    int tenureMonths,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/rd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'monthly_deposit': monthlyDeposit,
          'rate': rate,
          'tenure_months': tenureMonths,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _calculateRDLocal(monthlyDeposit, rate, tenureMonths);
      }
    } catch (e) {
      session.log('RD calculation error, using local: $e');
      return _calculateRDLocal(monthlyDeposit, rate, tenureMonths);
    }
  }

  /// Calculate required SIP for a goal
  Future<Map<String, dynamic>> calculateGoalSIP(
    Session session,
    double targetAmount,
    int durationMonths,
    double expectedRate,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/goal-sip'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target_amount': targetAmount,
          'duration_months': durationMonths,
          'expected_rate': expectedRate,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _calculateGoalSIPLocal(
          targetAmount,
          durationMonths,
          expectedRate,
        );
      }
    } catch (e) {
      session.log('Goal SIP calculation error, using local: $e');
      return _calculateGoalSIPLocal(targetAmount, durationMonths, expectedRate);
    }
  }

  /// Calculate CAGR (Compound Annual Growth Rate)
  Future<Map<String, dynamic>> calculateCAGR(
    Session session,
    double initialValue,
    double finalValue,
    double years,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_sidecarUrl/calculator/cagr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initial_value': initialValue,
          'final_value': finalValue,
          'years': years,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _calculateCAGRLocal(initialValue, finalValue, years);
      }
    } catch (e) {
      session.log('CAGR calculation error, using local: $e');
      return _calculateCAGRLocal(initialValue, finalValue, years);
    }
  }

  // ============== Local Fallback Calculations ==============

  Map<String, dynamic> _calculateSIPLocal(
    double monthlyInvestment,
    double expectedRate,
    int durationMonths,
  ) {
    final monthlyRate = expectedRate / 12 / 100;
    double futureValue;

    if (monthlyRate == 0) {
      futureValue = monthlyInvestment * durationMonths;
    } else {
      futureValue =
          monthlyInvestment *
          ((math.pow(1 + monthlyRate, durationMonths.toDouble()) - 1) /
              monthlyRate) *
          (1 + monthlyRate);
    }

    final totalInvested = monthlyInvestment * durationMonths;
    final wealthGained = futureValue - totalInvested;

    return {
      'monthly_investment': monthlyInvestment,
      'duration_months': durationMonths,
      'expected_rate': expectedRate,
      'total_invested': totalInvested.round(),
      'future_value': futureValue.round(),
      'wealth_gained': wealthGained.round(),
      'returns_percentage': totalInvested > 0
          ? ((wealthGained / totalInvested) * 100).round()
          : 0,
    };
  }

  Map<String, dynamic> _calculateFDLocal(
    double principal,
    double rate,
    int tenureMonths,
    String compounding,
  ) {
    final compoundingFreq = {
      'monthly': 12,
      'quarterly': 4,
      'half-yearly': 2,
      'yearly': 1,
    };

    final n = compoundingFreq[compounding] ?? 4;
    final r = rate / 100;
    final t = tenureMonths / 12;

    final maturityAmount = principal * math.pow(1 + r / n, n * t);
    final interestEarned = maturityAmount - principal;
    final effectiveRate = (math.pow(1 + r / n, n.toDouble()) - 1) * 100;

    return {
      'principal': principal,
      'rate': rate,
      'tenure_months': tenureMonths,
      'maturity_amount': maturityAmount.round(),
      'interest_earned': interestEarned.round(),
      'effective_annual_rate': effectiveRate.round(),
    };
  }

  Map<String, dynamic> _calculateEMILocal(
    double principal,
    double rate,
    int tenureMonths,
  ) {
    final monthlyRate = rate / 12 / 100;
    double emi;

    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      emi =
          principal *
          monthlyRate *
          math.pow(1 + monthlyRate, tenureMonths.toDouble()) /
          (math.pow(1 + monthlyRate, tenureMonths.toDouble()) - 1);
    }

    final totalPayment = emi * tenureMonths;
    final totalInterest = totalPayment - principal;

    return {
      'principal': principal,
      'rate': rate,
      'tenure_months': tenureMonths,
      'emi': emi.round(),
      'total_payment': totalPayment.round(),
      'total_interest': totalInterest.round(),
    };
  }

  Map<String, dynamic> _calculateRDLocal(
    double monthlyDeposit,
    double rate,
    int tenureMonths,
  ) {
    final quarterlyRate = rate / 4 / 100;
    double maturityAmount = 0;

    for (int month = 0; month < tenureMonths; month++) {
      final remainingQuarters = (tenureMonths - month) / 3;
      final amount =
          monthlyDeposit * math.pow(1 + quarterlyRate, remainingQuarters);
      maturityAmount += amount;
    }

    final totalDeposited = monthlyDeposit * tenureMonths;
    final interestEarned = maturityAmount - totalDeposited;

    return {
      'monthly_deposit': monthlyDeposit,
      'rate': rate,
      'tenure_months': tenureMonths,
      'maturity_amount': maturityAmount.round(),
      'total_deposited': totalDeposited.round(),
      'interest_earned': interestEarned.round(),
    };
  }

  Map<String, dynamic> _calculateGoalSIPLocal(
    double targetAmount,
    int durationMonths,
    double expectedRate,
  ) {
    final monthlyRate = expectedRate / 12 / 100;
    double monthlySIP;

    if (monthlyRate == 0) {
      monthlySIP = targetAmount / durationMonths;
    } else {
      monthlySIP =
          targetAmount /
          (((math.pow(1 + monthlyRate, durationMonths.toDouble()) - 1) /
                  monthlyRate) *
              (1 + monthlyRate));
    }

    return {
      'target_amount': targetAmount,
      'duration_months': durationMonths,
      'expected_rate': expectedRate,
      'required_monthly_sip': monthlySIP.round(),
    };
  }

  Map<String, dynamic> _calculateCAGRLocal(
    double initialValue,
    double finalValue,
    double years,
  ) {
    if (initialValue <= 0 || years <= 0) {
      return {
        'initial_value': initialValue,
        'final_value': finalValue,
        'years': years,
        'cagr': 0.0,
      };
    }

    final cagr = (math.pow(finalValue / initialValue, 1 / years) - 1) * 100;

    return {
      'initial_value': initialValue,
      'final_value': finalValue,
      'years': years,
      'cagr': cagr.round(),
    };
  }
}
