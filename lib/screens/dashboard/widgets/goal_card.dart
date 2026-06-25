import 'package:flutter/material.dart';
import '../../../models/goal_models.dart';
import '../../../widgets/glass_card.dart';
import 'streak_badge.dart';

class GoalCard extends StatelessWidget {
  final HiveGoal goal;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.completed,
    required this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? cs.primary : Colors.transparent,
                  border: Border.all(
                    color: completed ? cs.primary : cs.outline,
                    width: 2,
                  ),
                ),
                child: completed
                    ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? cs.outline : cs.onSurface,
                    ),
                  ),
                  Text(goal.category,
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              ),
            ),
            StreakBadge(streak: goal.currentStreak),
          ],
        ),
      ),
    );
  }
}