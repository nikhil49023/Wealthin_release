import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/data_service.dart';
import '../../core/theme/wealthin_theme.dart';

/// Daily Streak Card - Shows user's engagement streak with Race Track visualization
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
  List<bool> _weekDaysActive = List.filled(7, false); // Mon-Sun
  
  @override
  void initState() {
    super.initState();
    _loadStreak();
  }
  
  Future<void> _loadStreak() async {
    try {
      final streakData = await dataService.initStreak();
      await _loadWeekActivity();
      
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
  
  /// Load which days this week user was active
  Future<void> _loadWeekActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Find Monday of current week
      final monday = now.subtract(Duration(days: now.weekday - 1));
      
      final weekActive = <bool>[];
      for (int i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final dayKey = 'active_${day.year}_${day.month}_${day.day}';
        final wasActive = prefs.getBool(dayKey) ?? false;
        
        // Also mark today as active if we're on it
        if (day.year == now.year && day.month == now.month && day.day == now.day) {
          weekActive.add(true); // Today is active (user opened app)
          await prefs.setBool(dayKey, true);
        } else if (day.isBefore(now)) {
          weekActive.add(wasActive);
        } else {
          weekActive.add(false); // Future day
        }
      }
      
      _weekDaysActive = weekActive;
    } catch (e) {
      debugPrint('Error loading week activity: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentDayIndex = DateTime.now().weekday - 1; // 0 = Mon, 6 = Sun
    
    if (_isLoading) {
      return Card(
        child: Container(
          height: 140,
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
              _getStreakColor(_currentStreak).withValues(alpha: 0.85),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _currentStreak >= 7 ? '🔥' : '⭐',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_currentStreak Day Streak',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Best: $_longestStreak 🏆',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Race Track Visualization
            _buildRaceTrack(currentDayIndex),
            
            const SizedBox(height: 12),
            
            // Motivational Message
            Text(
              _getMotivationalMessage(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }
  
  /// Build the Race Track UI with 7 day checkpoints
  Widget _buildRaceTrack(int currentDayIndex) {
    const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // Road/Track background
          Positioned(
            left: 20,
            right: 20,
            top: 22,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          // Dashed road markings
          Positioned(
            left: 25,
            right: 25,
            top: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(12, (i) => Container(
                width: 8,
                height: 2,
                color: Colors.white.withValues(alpha: 0.5),
              )),
            ),
          ),
          
          // Day checkpoints
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isToday = index == currentDayIndex;
              final isActive = _weekDaysActive[index];
              final isPast = index < currentDayIndex;
              final isSunday = index == 6;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkpoint circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isToday ? 36 : 28,
                    height: isToday ? 36 : 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive 
                          ? Colors.white
                          : (isPast 
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.15)),
                      border: isToday 
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isToday ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: isSunday && isActive
                          ? const Text('🏁', style: TextStyle(fontSize: 14))
                          : (isActive
                              ? Icon(
                                  Icons.check,
                                  size: isToday ? 20 : 16,
                                  color: _getStreakColor(_currentStreak),
                                )
                              : (isSunday
                                  ? const Text('🏁', style: TextStyle(fontSize: 12))
                                  : null)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Day label
                  Text(
                    weekDays[index],
                    style: TextStyle(
                      color: isToday 
                          ? Colors.white 
                          : Colors.white.withValues(alpha: 0.7),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: isToday ? 13 : 11,
                    ),
                  ),
                ],
              );
            }),
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
    final daysUntilSunday = 7 - DateTime.now().weekday;
    final activeDays = _weekDaysActive.where((a) => a).length;
    
    if (daysUntilSunday == 0) {
      return activeDays >= 5 
          ? '🎉 Finish line reached! $_totalDays total active days!'
          : 'Complete the week strong! 💪';
    }
    
    if (_currentStreak == 0) {
      return 'Start your streak today! 💪';
    } else if (activeDays >= 5) {
      return '$daysUntilSunday day${daysUntilSunday > 1 ? 's' : ''} to the finish line! 🏁';
    } else if (_currentStreak < 7) {
      return '${7 - _currentStreak} more days to a week streak!';
    } else if (_currentStreak < 30) {
      return '${30 - _currentStreak} days to monthly streak! 🎯';
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
