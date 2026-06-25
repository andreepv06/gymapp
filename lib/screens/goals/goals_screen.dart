import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_action_buttons.dart';
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalFormScreen()),
        ),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GoalFormScreen(existing: goal)),
        ),
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
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                final provider = context.read<GoalProvider>();
                if (v == 'pause') provider.setStatus(goal, 'paused');
                if (v == 'active') provider.setStatus(goal, 'active');
                if (v == 'complete') provider.setStatus(goal, 'completed');
                if (v == 'delete') provider.deleteGoal(goal.key);
              },
              itemBuilder: (_) => [
                if (goal.status != 'active')
                  const PopupMenuItem(value: 'active', child: Text('Riattiva')),
                if (goal.status == 'active')
                  const PopupMenuItem(value: 'pause', child: Text('Metti in pausa')),
                const PopupMenuItem(value: 'complete', child: Text('Segna completato')),
                const PopupMenuItem(value: 'delete', child: Text('Elimina')),
              ],
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