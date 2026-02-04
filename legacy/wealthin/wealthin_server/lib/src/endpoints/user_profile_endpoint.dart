import 'package:serverpod/serverpod.dart' hide Transaction;
import 'package:wealthin_server/src/generated/protocol.dart';

/// UserProfile Endpoint - User management and gamification
class UserProfileEndpoint extends Endpoint {
  /// Get or create user profile
  Future<UserProfile> getOrCreateProfile(Session session, String uid) async {
    final existing = await UserProfile.db.findFirstRow(
      session,
      where: (u) => u.uid.equals(uid),
    );

    if (existing != null) {
      return existing;
    }

    final newProfile = UserProfile(
      uid: uid,
      credits: 5,
      completedGoals: [],
    );

    return await UserProfile.db.insertRow(session, newProfile);
  }

  /// Award credits to user
  Future<UserProfile> awardCredits(
    Session session,
    int userProfileId,
    int amount,
    String reason,
  ) async {
    final profile = await UserProfile.db.findById(session, userProfileId);
    if (profile == null) {
      throw Exception('User profile not found');
    }

    profile.credits += amount;
    session.log('Awarded $amount credits to user ${profile.uid} for: $reason');

    return await UserProfile.db.updateRow(session, profile);
  }

  /// Mark a goal as completed
  Future<UserProfile> markGoalCompleted(
    Session session,
    int userProfileId,
    int goalId,
  ) async {
    final profile = await UserProfile.db.findById(session, userProfileId);
    if (profile == null) {
      throw Exception('User profile not found');
    }

    final goalIdStr = goalId.toString();
    if (profile.completedGoals != null && !profile.completedGoals!.contains(goalIdStr)) {
      profile.completedGoals!.add(goalIdStr);
      return await UserProfile.db.updateRow(session, profile);
    }

    return profile;
  }

  /// Get user's credit balance
  Future<int> getCreditBalance(Session session, int userProfileId) async {
    final profile = await UserProfile.db.findById(session, userProfileId);
    return profile?.credits ?? 0;
  }

  /// Check and award savings rate bonus (if rate >= 60%)
  Future<bool> checkAndAwardSavingsBonus(
    Session session,
    int userProfileId,
    int savingsRate,
  ) async {
    if (savingsRate >= 60) {
      await awardCredits(session, userProfileId, 3, 'High Savings Rate ($savingsRate%)');
      return true;
    }
    return false;
  }
}
