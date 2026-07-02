import 'package:flutter/material.dart';
import '../../core/navigation/app_router.dart';
import '../../widgets/glass_card.dart';
import 'workouts_screen.dart';
import '../session/session_selector_screen.dart';
import '../exercises/exercises_screen.dart';

class AllenamentiScreen extends StatelessWidget {
  const AllenamentiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Allenamenti'),
        actions: [
          IconButton(
            tooltip: 'Libreria esercizi',
            icon: Icon(Icons.fitness_center_outlined, color: cs.tertiary),
            onPressed: () => pushPage(context, const ExercisesScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              onTap: () => pushPage(context, const WorkoutsScreen()),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.list_alt_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Le mie schede',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Icon(Icons.chevron_right, color: cs.outline),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              onTap: () => pushPage(context, const SessionSelectorScreen()),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Avvia sessione',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Icon(Icons.chevron_right, color: cs.outline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}