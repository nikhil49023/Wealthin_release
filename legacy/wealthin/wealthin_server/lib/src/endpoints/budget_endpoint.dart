import 'package:serverpod/serverpod.dart' hide Transaction;
import 'package:wealthin_server/src/generated/protocol.dart';

/// Budget Endpoint - CRUD operations for budgets
class BudgetEndpoint extends Endpoint {
  /// Get all budgets for a user
  Future<List<Budget>> getBudgets(Session session, int userProfileId) async {
    return await Budget.db.find(
      session,
      where: (b) => b.userProfileId.equals(userProfileId),
    );
  }

  /// Create a new budget
  Future<Budget> createBudget(Session session, Budget budget) async {
    return await Budget.db.insertRow(session, budget);
  }

  /// Update a budget
  Future<Budget> updateBudget(Session session, Budget budget) async {
    return await Budget.db.updateRow(session, budget);
  }

  /// Delete a budget
  Future<bool> deleteBudget(Session session, int budgetId) async {
    final deleted = await Budget.db.deleteWhere(
      session,
      where: (b) => b.id.equals(budgetId),
    );
    return deleted.isNotEmpty;
  }

  /// Update budget spent amount based on transactions
  Future<void> recalculateBudgetSpending(Session session, int userProfileId) async {
    final budgets = await Budget.db.find(
      session,
      where: (b) => b.userProfileId.equals(userProfileId),
    );

    final transactions = await Transaction.db.find(
      session,
      where: (t) => t.userProfileId.equals(userProfileId) & t.type.equals('expense'),
    );

    for (final budget in budgets) {
      double spent = 0;
      for (final tx in transactions) {
        if (tx.category.toLowerCase() == budget.name.toLowerCase() ||
            tx.description.toLowerCase().contains(budget.name.toLowerCase())) {
          spent += tx.amount;
        }
      }
      
      budget.spent = spent;
      await Budget.db.updateRow(session, budget);
    }
  }
}
