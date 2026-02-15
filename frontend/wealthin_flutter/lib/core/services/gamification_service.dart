import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// WealthIn Gamification Engine
/// ============================================================
/// Provides:
///  • 10 named levels with themed titles & gradient colors
///  • Tiered achievements (Bronze → Silver → Gold → Platinum)
///  • Local XP tracking via SharedPreferences
///  • Progress computation from real user data
/// ============================================================

// ─── Level Definitions ───────────────────────────────────────

class LevelInfo {
  final int level;
  final String title;
  final String emoji;
  final int xpRequired;  // Cumulative XP to reach this level
  final List<int> gradientColors; // Two colors for badge gradient

  const LevelInfo({
    required this.level,
    required this.title,
    required this.emoji,
    required this.xpRequired,
    required this.gradientColors,
  });
}

const List<LevelInfo> allLevels = [
  LevelInfo(level: 1,  title: 'Novice',      emoji: '🌱', xpRequired: 0,    gradientColors: [0xFF78909C, 0xFF546E7A]),
  LevelInfo(level: 2,  title: 'Apprentice',   emoji: '📘', xpRequired: 100,  gradientColors: [0xFF42A5F5, 0xFF1E88E5]),
  LevelInfo(level: 3,  title: 'Tracker',      emoji: '📊', xpRequired: 300,  gradientColors: [0xFF26C6DA, 0xFF00ACC1]),
  LevelInfo(level: 4,  title: 'Planner',      emoji: '🗺️', xpRequired: 600,  gradientColors: [0xFF66BB6A, 0xFF43A047]),
  LevelInfo(level: 5,  title: 'Strategist',   emoji: '♟️', xpRequired: 1000, gradientColors: [0xFFAB47BC, 0xFF8E24AA]),
  LevelInfo(level: 6,  title: 'Expert',       emoji: '🎯', xpRequired: 1500, gradientColors: [0xFFEF5350, 0xFFE53935]),
  LevelInfo(level: 7,  title: 'Master',       emoji: '🏅', xpRequired: 2200, gradientColors: [0xFFFF7043, 0xFFF4511E]),
  LevelInfo(level: 8,  title: 'Guru',         emoji: '🧘', xpRequired: 3000, gradientColors: [0xFFFFCA28, 0xFFFFA000]),
  LevelInfo(level: 9,  title: 'Legend',        emoji: '⚡', xpRequired: 4000, gradientColors: [0xFFFFD54F, 0xFFFFB300]),
  LevelInfo(level: 10, title: 'Sovereign',     emoji: '👑', xpRequired: 5500, gradientColors: [0xFFFFD700, 0xFFFF8F00]),
];

LevelInfo getLevelInfo(int totalXP) {
  LevelInfo current = allLevels.first;
  for (final lvl in allLevels) {
    if (totalXP >= lvl.xpRequired) {
      current = lvl;
    } else {
      break;
    }
  }
  return current;
}

/// Returns XP needed to reach *next* level, and current progress fraction.
({int xpInLevel, int xpForNext, double progress, LevelInfo? nextLevel}) getLevelProgress(int totalXP) {
  final current = getLevelInfo(totalXP);
  final nextIdx = current.level; // levels are 1-indexed, so index = level
  if (nextIdx >= allLevels.length) {
    return (xpInLevel: 0, xpForNext: 1, progress: 1.0, nextLevel: null); // Max level
  }
  final next = allLevels[nextIdx];
  final xpInLevel = totalXP - current.xpRequired;
  final xpForNext = next.xpRequired - current.xpRequired;
  final progress = xpForNext > 0 ? (xpInLevel / xpForNext).clamp(0.0, 1.0) : 1.0;
  return (xpInLevel: xpInLevel, xpForNext: xpForNext, progress: progress, nextLevel: next);
}

// ─── Achievement Tiers ───────────────────────────────────────

enum AchievementTier { bronze, silver, gold, platinum }

extension AchievementTierExt on AchievementTier {
  String get label {
    switch (this) {
      case AchievementTier.bronze:   return 'Bronze';
      case AchievementTier.silver:   return 'Silver';
      case AchievementTier.gold:     return 'Gold';
      case AchievementTier.platinum: return 'Platinum';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementTier.bronze:   return '🥉';
      case AchievementTier.silver:   return '🥈';
      case AchievementTier.gold:     return '🥇';
      case AchievementTier.platinum: return '💎';
    }
  }

  List<int> get gradientColors {
    switch (this) {
      case AchievementTier.bronze:   return [0xFFCD7F32, 0xFFA05A2C];
      case AchievementTier.silver:   return [0xFFC0C0C0, 0xFF808080];
      case AchievementTier.gold:     return [0xFFFFD700, 0xFFDAA520];
      case AchievementTier.platinum: return [0xFFE5E4E2, 0xFF8FD8D2];
    }
  }

  int get sortOrder {
    switch (this) {
      case AchievementTier.bronze:   return 0;
      case AchievementTier.silver:   return 1;
      case AchievementTier.gold:     return 2;
      case AchievementTier.platinum: return 3;
    }
  }
}

// ─── Achievement Categories ──────────────────────────────────

enum AchievementCategory { savings, tracking, goals, planning, streaks, mastery }

extension AchievementCategoryExt on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.savings:  return 'Savings';
      case AchievementCategory.tracking: return 'Tracking';
      case AchievementCategory.goals:    return 'Goals';
      case AchievementCategory.planning: return 'Planning';
      case AchievementCategory.streaks:  return 'Streaks';
      case AchievementCategory.mastery:  return 'Mastery';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementCategory.savings:  return '💰';
      case AchievementCategory.tracking: return '📊';
      case AchievementCategory.goals:    return '🎯';
      case AchievementCategory.planning: return '💡';
      case AchievementCategory.streaks:  return '🔥';
      case AchievementCategory.mastery:  return '🏆';
    }
  }

  int get iconCodePoint {
    switch (this) {
      case AchievementCategory.savings:  return 0xf04b9; // savings
      case AchievementCategory.tracking: return 0xe070;  // analytics
      case AchievementCategory.goals:    return 0xe157;  // flag
      case AchievementCategory.planning: return 0xe3a2;  // lightbulb
      case AchievementCategory.streaks:  return 0xe3e7;  // local_fire_department
      case AchievementCategory.mastery:  return 0xe1c8;  // emoji_events
    }
  }
}

// ─── Achievement Definition ──────────────────────────────────

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final int xpReward;

  /// Progress target (e.g., 10 transactions, 30% savings rate).
  /// The actual progress is computed from user data.
  final double targetValue;

  /// Key used to compute progress from user stats
  final String progressKey;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    required this.xpReward,
    required this.targetValue,
    required this.progressKey,
  });
}

/// All achievement definitions
const List<AchievementDef> allAchievements = [
  // ── TRACKING ──
  AchievementDef(
    id: 'first_transaction',
    name: 'First Step',
    description: 'Record your first transaction',
    category: AchievementCategory.tracking,
    tier: AchievementTier.bronze,
    xpReward: 10,
    targetValue: 1,
    progressKey: 'transaction_count',
  ),
  AchievementDef(
    id: 'tracker_10',
    name: 'Getting Started',
    description: 'Record 10 transactions',
    category: AchievementCategory.tracking,
    tier: AchievementTier.bronze,
    xpReward: 25,
    targetValue: 10,
    progressKey: 'transaction_count',
  ),
  AchievementDef(
    id: 'tracker_50',
    name: 'Diligent Tracker',
    description: 'Record 50 transactions',
    category: AchievementCategory.tracking,
    tier: AchievementTier.silver,
    xpReward: 50,
    targetValue: 50,
    progressKey: 'transaction_count',
  ),
  AchievementDef(
    id: 'tracker_200',
    name: 'Data Maestro',
    description: 'Record 200 transactions',
    category: AchievementCategory.tracking,
    tier: AchievementTier.gold,
    xpReward: 100,
    targetValue: 200,
    progressKey: 'transaction_count',
  ),
  AchievementDef(
    id: 'tracker_500',
    name: 'Ledger Legend',
    description: 'Record 500 transactions',
    category: AchievementCategory.tracking,
    tier: AchievementTier.platinum,
    xpReward: 200,
    targetValue: 500,
    progressKey: 'transaction_count',
  ),

  // ── SAVINGS ──
  AchievementDef(
    id: 'saver_10',
    name: 'Penny Saver',
    description: 'Achieve 10% savings rate',
    category: AchievementCategory.savings,
    tier: AchievementTier.bronze,
    xpReward: 25,
    targetValue: 10,
    progressKey: 'savings_rate',
  ),
  AchievementDef(
    id: 'saver_20',
    name: 'Smart Saver',
    description: 'Achieve 20% savings rate',
    category: AchievementCategory.savings,
    tier: AchievementTier.silver,
    xpReward: 50,
    targetValue: 20,
    progressKey: 'savings_rate',
  ),
  AchievementDef(
    id: 'saver_30',
    name: 'Savings Champion',
    description: 'Achieve 30% savings rate',
    category: AchievementCategory.savings,
    tier: AchievementTier.gold,
    xpReward: 100,
    targetValue: 30,
    progressKey: 'savings_rate',
  ),
  AchievementDef(
    id: 'saver_50',
    name: 'Wealth Builder',
    description: 'Achieve 50% savings rate',
    category: AchievementCategory.savings,
    tier: AchievementTier.platinum,
    xpReward: 200,
    targetValue: 50,
    progressKey: 'savings_rate',
  ),

  // ── GOALS ──
  AchievementDef(
    id: 'first_goal',
    name: 'Goal Setter',
    description: 'Create your first savings goal',
    category: AchievementCategory.goals,
    tier: AchievementTier.bronze,
    xpReward: 15,
    targetValue: 1,
    progressKey: 'goals_created',
  ),
  AchievementDef(
    id: 'goals_3',
    name: 'Ambitious Planner',
    description: 'Create 3 savings goals',
    category: AchievementCategory.goals,
    tier: AchievementTier.silver,
    xpReward: 40,
    targetValue: 3,
    progressKey: 'goals_created',
  ),
  AchievementDef(
    id: 'goal_achieved',
    name: 'Dream Achiever',
    description: 'Complete your first savings goal',
    category: AchievementCategory.goals,
    tier: AchievementTier.gold,
    xpReward: 80,
    targetValue: 1,
    progressKey: 'goals_completed',
  ),
  AchievementDef(
    id: 'goals_5_completed',
    name: 'Unstoppable',
    description: 'Complete 5 savings goals',
    category: AchievementCategory.goals,
    tier: AchievementTier.platinum,
    xpReward: 200,
    targetValue: 5,
    progressKey: 'goals_completed',
  ),

  // ── PLANNING ──
  AchievementDef(
    id: 'first_budget',
    name: 'Budget Beginner',
    description: 'Create your first budget',
    category: AchievementCategory.planning,
    tier: AchievementTier.bronze,
    xpReward: 15,
    targetValue: 1,
    progressKey: 'budgets_created',
  ),
  AchievementDef(
    id: 'budgets_3',
    name: 'Budget Architect',
    description: 'Create 3 budgets',
    category: AchievementCategory.planning,
    tier: AchievementTier.silver,
    xpReward: 40,
    targetValue: 3,
    progressKey: 'budgets_created',
  ),
  AchievementDef(
    id: 'under_budget',
    name: 'Budget Master',
    description: 'Stay under budget for a full month',
    category: AchievementCategory.planning,
    tier: AchievementTier.gold,
    xpReward: 100,
    targetValue: 1,
    progressKey: 'months_under_budget',
  ),
  AchievementDef(
    id: 'idea_evaluated',
    name: 'Idea Explorer',
    description: 'Evaluate a business idea',
    category: AchievementCategory.planning,
    tier: AchievementTier.bronze,
    xpReward: 20,
    targetValue: 1,
    progressKey: 'ideas_evaluated',
  ),
  AchievementDef(
    id: 'dpr_created',
    name: 'DPR Champion',
    description: 'Generate your first DPR report',
    category: AchievementCategory.planning,
    tier: AchievementTier.gold,
    xpReward: 120,
    targetValue: 1,
    progressKey: 'dprs_created',
  ),

  // ── STREAKS ──
  AchievementDef(
    id: 'streak_3',
    name: 'Getting Consistent',
    description: '3-day tracking streak',
    category: AchievementCategory.streaks,
    tier: AchievementTier.bronze,
    xpReward: 15,
    targetValue: 3,
    progressKey: 'current_streak',
  ),
  AchievementDef(
    id: 'streak_7',
    name: 'Weeklong Warrior',
    description: '7-day tracking streak',
    category: AchievementCategory.streaks,
    tier: AchievementTier.silver,
    xpReward: 40,
    targetValue: 7,
    progressKey: 'current_streak',
  ),
  AchievementDef(
    id: 'streak_30',
    name: 'Monthly Master',
    description: '30-day tracking streak',
    category: AchievementCategory.streaks,
    tier: AchievementTier.gold,
    xpReward: 100,
    targetValue: 30,
    progressKey: 'current_streak',
  ),
  AchievementDef(
    id: 'streak_90',
    name: 'Iron Discipline',
    description: '90-day tracking streak',
    category: AchievementCategory.streaks,
    tier: AchievementTier.platinum,
    xpReward: 250,
    targetValue: 90,
    progressKey: 'current_streak',
  ),

  // ── MASTERY ──
  AchievementDef(
    id: 'health_60',
    name: 'Healthy Finances',
    description: 'Achieve 60+ health score',
    category: AchievementCategory.mastery,
    tier: AchievementTier.bronze,
    xpReward: 30,
    targetValue: 60,
    progressKey: 'health_score',
  ),
  AchievementDef(
    id: 'health_80',
    name: 'Financial Fitness',
    description: 'Achieve 80+ health score',
    category: AchievementCategory.mastery,
    tier: AchievementTier.silver,
    xpReward: 60,
    targetValue: 80,
    progressKey: 'health_score',
  ),
  AchievementDef(
    id: 'health_95',
    name: 'Peak Performance',
    description: 'Achieve 95+ health score',
    category: AchievementCategory.mastery,
    tier: AchievementTier.gold,
    xpReward: 150,
    targetValue: 95,
    progressKey: 'health_score',
  ),
  AchievementDef(
    id: 'pdf_exported',
    name: 'Report Pro',
    description: 'Export your first PDF report',
    category: AchievementCategory.mastery,
    tier: AchievementTier.bronze,
    xpReward: 20,
    targetValue: 1,
    progressKey: 'pdfs_exported',
  ),
  AchievementDef(
    id: 'analysis_3',
    name: 'Deep Analyst',
    description: 'Run 3 financial analyses',
    category: AchievementCategory.mastery,
    tier: AchievementTier.silver,
    xpReward: 50,
    targetValue: 3,
    progressKey: 'analyses_run',
  ),
  AchievementDef(
    id: 'level_5',
    name: 'Rising Star',
    description: 'Reach Level 5 (Strategist)',
    category: AchievementCategory.mastery,
    tier: AchievementTier.gold,
    xpReward: 100,
    targetValue: 5,
    progressKey: 'user_level',
  ),
  AchievementDef(
    id: 'level_10',
    name: 'Sovereign',
    description: 'Reach the maximum Level 10',
    category: AchievementCategory.mastery,
    tier: AchievementTier.platinum,
    xpReward: 300,
    targetValue: 10,
    progressKey: 'user_level',
  ),
];

// ─── Achievement State (runtime) ─────────────────────────────

class AchievementState {
  final AchievementDef definition;
  final double currentValue;
  final bool achieved;
  final DateTime? achievedAt;

  AchievementState({
    required this.definition,
    required this.currentValue,
    required this.achieved,
    this.achievedAt,
  });

  double get progress => definition.targetValue > 0
      ? (currentValue / definition.targetValue).clamp(0.0, 1.0)
      : 0.0;
}

// ─── User Stats (for achievement computation) ────────────────

class UserStats {
  final int transactionCount;
  final double savingsRate;
  final int goalsCreated;
  final int goalsCompleted;
  final int budgetsCreated;
  final int monthsUnderBudget;
  final int ideasEvaluated;
  final int dprsCreated;
  final int currentStreak;
  final double healthScore;
  final int pdfsExported;
  final int analysesRun;

  const UserStats({
    this.transactionCount = 0,
    this.savingsRate = 0,
    this.goalsCreated = 0,
    this.goalsCompleted = 0,
    this.budgetsCreated = 0,
    this.monthsUnderBudget = 0,
    this.ideasEvaluated = 0,
    this.dprsCreated = 0,
    this.currentStreak = 0,
    this.healthScore = 0,
    this.pdfsExported = 0,
    this.analysesRun = 0,
  });

  double getStatForKey(String key) {
    switch (key) {
      case 'transaction_count': return transactionCount.toDouble();
      case 'savings_rate':      return savingsRate;
      case 'goals_created':     return goalsCreated.toDouble();
      case 'goals_completed':   return goalsCompleted.toDouble();
      case 'budgets_created':   return budgetsCreated.toDouble();
      case 'months_under_budget': return monthsUnderBudget.toDouble();
      case 'ideas_evaluated':   return ideasEvaluated.toDouble();
      case 'dprs_created':      return dprsCreated.toDouble();
      case 'current_streak':    return currentStreak.toDouble();
      case 'health_score':      return healthScore;
      case 'pdfs_exported':     return pdfsExported.toDouble();
      case 'analyses_run':      return analysesRun.toDouble();
      case 'user_level':        return getLevelInfo(_cachedTotalXP).level.toDouble();
      default: return 0;
    }
  }
}

int _cachedTotalXP = 0;

// ─── Gamification Service (singleton) ────────────────────────

class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  static const String _xpKey = 'wealthin_total_xp';
  static const String _achievedKey = 'wealthin_achieved_ids';
  static const String _statsKey = 'wealthin_user_stats';

  int _totalXP = 0;
  Set<String> _achievedIds = {};
  UserStats _stats = const UserStats();

  int get totalXP => _totalXP;
  LevelInfo get currentLevel => getLevelInfo(_totalXP);
  UserStats get stats => _stats;

  /// Initialize from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalXP = prefs.getInt(_xpKey) ?? 0;
      _cachedTotalXP = _totalXP;
      final achievedList = prefs.getStringList(_achievedKey) ?? [];
      _achievedIds = achievedList.toSet();

      // Load persisted stats
      final statsJson = prefs.getString(_statsKey);
      if (statsJson != null) {
        _stats = _parseStats(statsJson);
      }
    } catch (e) {
      debugPrint('[Gamification] Init error: $e');
    }
  }

  /// Update user stats and check new achievements
  Future<List<AchievementState>> updateStats(UserStats newStats) async {
    _stats = newStats;
    _cachedTotalXP = _totalXP;

    final newlyAchieved = <AchievementState>[];

    for (final def in allAchievements) {
      if (_achievedIds.contains(def.id)) continue;

      final currentValue = newStats.getStatForKey(def.progressKey);
      if (currentValue >= def.targetValue) {
        // Achievement unlocked!
        _achievedIds.add(def.id);
        _totalXP += def.xpReward;
        _cachedTotalXP = _totalXP;
        newlyAchieved.add(AchievementState(
          definition: def,
          currentValue: currentValue,
          achieved: true,
          achievedAt: DateTime.now(),
        ));
      }
    }

    // Persist
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_xpKey, _totalXP);
      await prefs.setStringList(_achievedKey, _achievedIds.toList());
      await prefs.setString(_statsKey, _serializeStats(newStats));
    } catch (e) {
      debugPrint('[Gamification] Persist error: $e');
    }

    return newlyAchieved;
  }

  /// Manually award XP (for one-off events)
  Future<void> awardXP(int amount) async {
    _totalXP += amount;
    _cachedTotalXP = _totalXP;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_xpKey, _totalXP);
    } catch (e) {
      debugPrint('[Gamification] Award XP error: $e');
    }
  }

  /// Increment a specific stat counter
  Future<void> incrementStat(String key, {int by = 1}) async {
    final current = _stats;
    late UserStats updated;
    switch (key) {
      case 'pdfs_exported':
        updated = UserStats(
          transactionCount: current.transactionCount,
          savingsRate: current.savingsRate,
          goalsCreated: current.goalsCreated,
          goalsCompleted: current.goalsCompleted,
          budgetsCreated: current.budgetsCreated,
          monthsUnderBudget: current.monthsUnderBudget,
          ideasEvaluated: current.ideasEvaluated,
          dprsCreated: current.dprsCreated,
          currentStreak: current.currentStreak,
          healthScore: current.healthScore,
          pdfsExported: current.pdfsExported + by,
          analysesRun: current.analysesRun,
        );
        break;
      case 'analyses_run':
        updated = UserStats(
          transactionCount: current.transactionCount,
          savingsRate: current.savingsRate,
          goalsCreated: current.goalsCreated,
          goalsCompleted: current.goalsCompleted,
          budgetsCreated: current.budgetsCreated,
          monthsUnderBudget: current.monthsUnderBudget,
          ideasEvaluated: current.ideasEvaluated,
          dprsCreated: current.dprsCreated,
          currentStreak: current.currentStreak,
          healthScore: current.healthScore,
          pdfsExported: current.pdfsExported,
          analysesRun: current.analysesRun + by,
        );
        break;
      case 'dprs_created':
        updated = UserStats(
          transactionCount: current.transactionCount,
          savingsRate: current.savingsRate,
          goalsCreated: current.goalsCreated,
          goalsCompleted: current.goalsCompleted,
          budgetsCreated: current.budgetsCreated,
          monthsUnderBudget: current.monthsUnderBudget,
          ideasEvaluated: current.ideasEvaluated,
          dprsCreated: current.dprsCreated + by,
          currentStreak: current.currentStreak,
          healthScore: current.healthScore,
          pdfsExported: current.pdfsExported,
          analysesRun: current.analysesRun,
        );
        break;
      case 'ideas_evaluated':
        updated = UserStats(
          transactionCount: current.transactionCount,
          savingsRate: current.savingsRate,
          goalsCreated: current.goalsCreated,
          goalsCompleted: current.goalsCompleted,
          budgetsCreated: current.budgetsCreated,
          monthsUnderBudget: current.monthsUnderBudget,
          ideasEvaluated: current.ideasEvaluated + by,
          dprsCreated: current.dprsCreated,
          currentStreak: current.currentStreak,
          healthScore: current.healthScore,
          pdfsExported: current.pdfsExported,
          analysesRun: current.analysesRun,
        );
        break;
      default:
        updated = current;
    }
    await updateStats(updated);
  }

  /// Get all achievement states (for UI)
  List<AchievementState> getAllAchievementStates() {
    return allAchievements.map((def) {
      final currentValue = _stats.getStatForKey(def.progressKey);
      return AchievementState(
        definition: def,
        currentValue: currentValue,
        achieved: _achievedIds.contains(def.id),
      );
    }).toList();
  }

  /// Get achievements by category
  Map<AchievementCategory, List<AchievementState>> getAchievementsByCategory() {
    final all = getAllAchievementStates();
    final map = <AchievementCategory, List<AchievementState>>{};
    for (final cat in AchievementCategory.values) {
      map[cat] = all.where((a) => a.definition.category == cat).toList();
    }
    return map;
  }

  /// Summary stats
  int get achievedCount => _achievedIds.length;
  int get totalCount => allAchievements.length;

  // ─── Serialization helpers ──────────────────────────────────

  String _serializeStats(UserStats s) {
    return '${s.transactionCount}|${s.savingsRate}|${s.goalsCreated}|${s.goalsCompleted}'
        '|${s.budgetsCreated}|${s.monthsUnderBudget}|${s.ideasEvaluated}|${s.dprsCreated}'
        '|${s.currentStreak}|${s.healthScore}|${s.pdfsExported}|${s.analysesRun}';
  }

  UserStats _parseStats(String raw) {
    try {
      final parts = raw.split('|');
      return UserStats(
        transactionCount: int.tryParse(parts[0]) ?? 0,
        savingsRate: double.tryParse(parts[1]) ?? 0,
        goalsCreated: int.tryParse(parts[2]) ?? 0,
        goalsCompleted: int.tryParse(parts[3]) ?? 0,
        budgetsCreated: int.tryParse(parts[4]) ?? 0,
        monthsUnderBudget: int.tryParse(parts[5]) ?? 0,
        ideasEvaluated: int.tryParse(parts[6]) ?? 0,
        dprsCreated: int.tryParse(parts[7]) ?? 0,
        currentStreak: int.tryParse(parts[8]) ?? 0,
        healthScore: double.tryParse(parts[9]) ?? 0,
        pdfsExported: int.tryParse(parts.length > 10 ? parts[10] : '0') ?? 0,
        analysesRun: int.tryParse(parts.length > 11 ? parts[11] : '0') ?? 0,
      );
    } catch (e) {
      return const UserStats();
    }
  }
}
