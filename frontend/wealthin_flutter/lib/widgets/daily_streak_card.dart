import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/data_service.dart';
import '../../core/theme/wealthin_theme.dart';

/// Daily Streak Card - Shows user's engagement streak
class DailyStreakCard extends StatefulWidget {
  const DailyStreakCard({super.key});

  @override
  State<DailyStreakCard> createState() => _DailyStreakCardState();
}

class _DailyStreakCardState extends State<DailyStreakCard> {
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalDays = 0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStreak();
  }
  
  Future<void> _loadStreak() async {
    try {
      final streakData = await dataService.initStreak();
      if (mounted) {
        setState(() {
          _currentStreak = streakData['current_streak'] as int? ?? 0;
          _longestStreak = streakData['longest_streak'] as int? ?? 0;
          _totalDays = streakData['total_days_active'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading streak: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Card(
        child: Container(
          height: 100,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getStreakColor(_currentStreak),
              _getStreakColor(_currentStreak).withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Streak fire icon with animation
            _buildStreakIcon(),
            const SizedBox(width: 16),
            
            // Streak info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_currentStreak',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Day${_currentStreak != 1 ? 's' : ''} Streak',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMotivationalMessage(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniStat('Best', '$_longestStreak 🏆'),
                const SizedBox(height: 4),
                _buildMiniStat('Total', '$_totalDays days'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }
  
  Widget _buildStreakIcon() {
    final bool isHot = _currentStreak >= 7;
    final bool isOnFire = _currentStreak >= 30;
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow for streaks
          if (isOnFire)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          // Fire icon
          Text(
            isOnFire ? '🔥' : (isHot ? '🔥' : '⭐'),
            style: const TextStyle(fontSize: 32),
          ),
        ],
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 2.seconds,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }
  
  Widget _buildMiniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStreakColor(int streak) {
    if (streak >= 30) {
      return const Color(0xFFFF6B00); // Bright orange for 30+
    } else if (streak >= 14) {
      return const Color(0xFFFF9500); // Orange for 14+
    } else if (streak >= 7) {
      return const Color(0xFFFFB300); // Amber for 7+
    } else if (streak >= 3) {
      return WealthInTheme.regalGold; // Gold for 3+
    }
    return WealthInTheme.trueEmerald; // Primary for new users
  }
  
  String _getMotivationalMessage() {
    if (_currentStreak == 0) {
      return 'Start your streak today! 💪';
    } else if (_currentStreak == 1) {
      return 'Great start! Keep it going! 🌟';
    } else if (_currentStreak < 7) {
      return '${7 - _currentStreak} more days to a week streak!';
    } else if (_currentStreak < 14) {
      return 'Awesome week! Keep pushing! 🚀';
    } else if (_currentStreak < 30) {
      return '${30 - _currentStreak} days to monthly streak! 🎯';
    } else if (_currentStreak < 100) {
      return 'You\'re on fire! ${100 - _currentStreak} to 100! 🔥';
    }
    return 'Legendary! $_currentStreak days strong! 👑';
  }
}

/// Compact streak badge for header display
class StreakBadge extends StatelessWidget {
  final int streak;
  
  const StreakBadge({super.key, required this.streak});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            streak >= 7 ? Colors.orange : WealthInTheme.regalGold,
            streak >= 7 ? Colors.deepOrange : WealthInTheme.vintageGold,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (streak >= 7 ? Colors.orange : WealthInTheme.regalGold)
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            streak >= 7 ? '🔥' : '⭐',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
