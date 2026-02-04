import 'package:serverpod/serverpod.dart' hide Transaction;
import 'package:wealthin_server/src/generated/protocol.dart';

/// Goal Endpoint - CRUD operations for savings goals
class GoalEndpoint extends Endpoint {
  /// Get all goals for a user
  Future<List<Goal>> getGoals(Session session, int userProfileId) async {
    return await Goal.db.find(
      session,
      where: (g) => g.userProfileId.equals(userProfileId),
    );
  }

  /// Create a new goal
  Future<Goal> createGoal(Session session, Goal goal) async {
    return await Goal.db.insertRow(session, goal);
  }

  /// Update a goal (e.g., add to currentAmount)
  Future<Goal> updateGoal(Session session, Goal goal) async {
    return await Goal.db.updateRow(session, goal);
  }

  /// Delete a goal
  Future<bool> deleteGoal(Session session, int goalId) async {
    final deleted = await Goal.db.deleteWhere(
      session,
      where: (g) => g.id.equals(goalId),
    );
    return deleted.isNotEmpty;
  }

  /// Create default emergency fund goal for new users
  Future<Goal> createDefaultEmergencyFund(Session session, int userProfileId, double monthlyExpenses) async {
    final targetAmount = monthlyExpenses > 0 ? monthlyExpenses * 3 : 50000.0;
    
    final goal = Goal(
      name: 'Emergency Fund (3 months)',
      targetAmount: targetAmount,
      currentAmount: 0,
      isDefault: true,
      userProfileId: userProfileId,
    );
    
    return await Goal.db.insertRow(session, goal);
  }

  /// Calculate overall savings progress towards all goals
  Future<Map<String, dynamic>> getSavingsProgress(Session session, int userProfileId) async {
    final goals = await Goal.db.find(
      session,
      where: (g) => g.userProfileId.equals(userProfileId),
    );

    double totalTarget = 0;
    double totalCurrent = 0;
    int completedGoals = 0;

    for (final goal in goals) {
      totalTarget += goal.targetAmount;
      totalCurrent += goal.currentAmount;
      if (goal.currentAmount >= goal.targetAmount) {
        completedGoals++;
      }
    }

    return {
      'totalGoals': goals.length,
      'completedGoals': completedGoals,
      'totalTarget': totalTarget,
      'totalCurrent': totalCurrent,
      'overallProgress': totalTarget > 0 ? (totalCurrent / totalTarget * 100).round() : 0,
    };
  }
}
