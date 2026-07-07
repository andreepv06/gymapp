import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../dashboard/widgets/streak_badge.dart';
import 'goal_form_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<GoalProvider>().loadGoals());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goals = context.watch<GoalProvider>().goals;

    return Scaffold(
      appBar: AppBar(title: const Text('I miei obiettivi')),
      floatingActionButton: FloatingActionButton(
        // FIX: CupertinoPageRoute via pushPage
        onPressed: () => pushPage(context, const GoalFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: goals.isEmpty
          ? Center(
              child: Text('Nessun obiettivo creato',
                  style: TextStyle(color: cs.outline)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: goals.length,
              itemBuilder: (_, i) => _GoalListTile(goal: goals[i]),
            ),
    );
  }
}

class _GoalListTile extends StatelessWidget {
  final HiveGoal goal;
  const _GoalListTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        // FIX: CupertinoPageRoute via pushPage
        onTap: () => pushPage(context, GoalFormScreen(existing: goal)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(goal.category,
                      style: TextStyle(fontSize: 12, color: cs.outline)),
                  const SizedBox(height: 4),
                  Text(_statusLabel(goal.status),
                      style: TextStyle(fontSize: 11, color: cs.primary)),
                ],
              ),
            ),
            StreakBadge(streak: goal.currentStreak),
            const SizedBox(width: 4),
            // MODIFICA 4: sostituito PopupMenuButton con Glass bottom sheet
            IconButton(
              icon: Icon(Icons.more_vert, color: cs.outline),
              onPressed: () => _showGlassOptionsSheet(context, goal),
            ),
          ],
        ),
      ),
    );
  }

  // MODIFICA 4: Glass bottom sheet identico per stile a workouts_screen.dart
  void _showGlassOptionsSheet(BuildContext context, HiveGoal goal) {
    final provider = context.read<GoalProvider>();
    final cs = Theme.of(context).colorScheme;

    showGlassBottomSheet(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassSheetHandle(),
            const SizedBox(height: 16),
            // Titolo obiettivo come header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flag_rounded,
                      color: cs.onPrimaryContainer, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Metti in pausa (solo se attivo)
            if (goal.status == 'active') ...[
              _GoalOptionTile(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Metti in pausa',
                color: cs.tertiary,
                onTap: () {
                  Navigator.pop(context);
                  provider.setStatus(goal, 'paused');
                },
              ),
              const SizedBox(height: 10),
            ],

            // ── Riprendi (solo se in pausa)
            if (goal.status == 'paused') ...[
              _GoalOptionTile(
                icon: Icons.play_circle_outline_rounded,
                label: 'Riprendi',
                color: cs.primary,
                onTap: () {
                  Navigator.pop(context);
                  provider.setStatus(goal, 'active');
                },
              ),
              const SizedBox(height: 10),
            ],

            // ── Segna completato
            _GoalOptionTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Segna completato',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                provider.setStatus(goal, 'completed');
              },
            ),
            const SizedBox(height: 10),

            // ── Elimina (con dialog di conferma glass)
            _GoalOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Elimina obiettivo',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteGoal(context, goal, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialog di conferma eliminazione — usa lo stesso sistema Glass
  void _confirmDeleteGoal(
      BuildContext context, HiveGoal goal, GoalProvider provider) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Elimina obiettivo',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
                'Eliminare "${goal.title}"? Questa azione è permanente.'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                provider.deleteGoal(goal.key);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed':
        return 'Completato';
      case 'paused':
        return 'In pausa';
      default:
        return 'Attivo';
    }
  }
}

/// Tile di azione per il Glass menu — stesso stile di _OptionTile
/// in workouts_screen.dart: blur + border + icon container + label.
class _GoalOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GoalOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: color),
              ),
            ),
            Icon(Icons.chevron_right,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}