import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// DebtEndpoint: Manage loans, EMIs, and credit tracking
class DebtEndpoint extends Endpoint {
  
  /// Get all debts for a user
  Future<List<Debt>> getDebts(Session session, int userId) async {
    return await Debt.db.find(
      session,
      where: (d) => d.userProfileId.equals(userId),
      orderBy: (d) => d.nextDueDate,
    );
  }

  /// Get active debts only
  Future<List<Debt>> getActiveDebts(Session session, int userId) async {
    return await Debt.db.find(
      session,
      where: (d) => d.userProfileId.equals(userId) & d.status.equals('active'),
      orderBy: (d) => d.nextDueDate,
    );
  }

  /// Create a new debt
  Future<Debt> createDebt(Session session, Debt debt) async {
    debt.createdAt = DateTime.now();
    debt.remainingAmount = debt.principal;
    debt.status = 'active';
    return await Debt.db.insertRow(session, debt);
  }

  /// Update a debt
  Future<Debt> updateDebt(Session session, Debt debt) async {
    debt.updatedAt = DateTime.now();
    return await Debt.db.updateRow(session, debt);
  }

  /// Record a payment towards a debt
  Future<Debt> recordPayment(
    Session session,
    int debtId,
    double paymentAmount,
  ) async {
    final debt = await Debt.db.findById(session, debtId);
    if (debt == null) {
      throw Exception('Debt not found');
    }
    
    debt.remainingAmount -= paymentAmount;
    if (debt.remainingAmount <= 0) {
      debt.remainingAmount = 0;
      debt.status = 'paid_off';
    }
    debt.updatedAt = DateTime.now();
    
    return await Debt.db.updateRow(session, debt);
  }

  /// Delete a debt
  Future<bool> deleteDebt(Session session, int debtId) async {
    final deleted = await Debt.db.deleteWhere(
      session,
      where: (d) => d.id.equals(debtId),
    );
    return deleted.isNotEmpty;
  }

  /// Calculate EMI for a loan
  Future<Map<String, dynamic>> calculateEmi(
    Session session,
    double principal,
    double annualRate,
    int tenureMonths,
  ) async {
    final monthlyRate = annualRate / 12 / 100;
    
    double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      final powFactor = _pow(1 + monthlyRate, tenureMonths);
      emi = principal * monthlyRate * powFactor / (powFactor - 1);
    }
    
    final totalPayment = emi * tenureMonths;
    final totalInterest = totalPayment - principal;
    
    return {
      'emi': emi.round(),
      'total_payment': totalPayment.round(),
      'total_interest': totalInterest.round(),
      'principal': principal.round(),
    };
  }

  /// Get debt summary for a user
  Future<Map<String, dynamic>> getDebtSummary(Session session, int userId) async {
    final debts = await getActiveDebts(session, userId);
    
    double totalPrincipal = 0;
    double totalRemaining = 0;
    double monthlyEmiTotal = 0;
    
    for (final debt in debts) {
      totalPrincipal += debt.principal;
      totalRemaining += debt.remainingAmount;
      monthlyEmiTotal += debt.emi ?? 0;
    }
    
    return {
      'total_debts': debts.length,
      'total_principal': totalPrincipal,
      'total_remaining': totalRemaining,
      'total_paid': totalPrincipal - totalRemaining,
      'monthly_emi_total': monthlyEmiTotal,
    };
  }

  double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
