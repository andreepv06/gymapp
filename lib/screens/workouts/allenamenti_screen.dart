import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../providers/session_provider.dart';
import '../../widgets/glass_card.dart';
import 'workouts_screen.dart';
import '../session/session_selector_screen.dart';
import '../session/active_session_screen.dart';
import '../exercises/exercises_screen.dart';

class AllenamentiScreen extends StatelessWidget {
  const AllenamentiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sp = context.watch<SessionProvider>();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Allenamenti'),
        actions: [
          IconButton(
            tooltip: 'Libreria esercizi',
            icon: Icon(Icons.fitness_center_outlined,
                color: cs.tertiary),
            onPressed: () => pushPage(context, const ExercisesScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sessione in pausa ──────────────────────────────
          if (sp.hasActiveSession) ...[
            _PausedSessionCard(sp: sp),
            const SizedBox(height: 8),
            Divider(color: cs.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
          ],

          // ── Le mie schede ──────────────────────────────────
          GlassCard(
            onTap: () => pushPage(context, const WorkoutsScreen()),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded,
                    color: cs.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Le mie schede',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gestisci e modifica le schede',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.outline),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Avvia sessione ─────────────────────────────────
          GlassCard(
            onTap: () =>
                pushPage(context, const SessionSelectorScreen()),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    color: cs.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avvia sessione',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Seleziona una scheda e inizia',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.outline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedSessionCard
// ─────────────────────────────────────────────────────────────

class _PausedSessionCard extends StatelessWidget {
  final SessionProvider sp;

  const _PausedSessionCard({required this.sp});

  String _fmtElapsed(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workoutName =
        sp.currentWorkout?.name ?? 'Sessione in pausa';
    final elapsed = sp.elapsedSeconds;
    final completed = sp.completedSetsCount;
    final total = sp.totalSetsCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Sessione in pausa',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Info sessione
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pause_circle_outline_rounded,
                  color: Colors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workoutName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 12, color: cs.outline),
                            const SizedBox(width: 4),
                            Text(
                              _fmtElapsed(elapsed),
                              style: TextStyle(
                                  fontSize: 12, color: cs.outline),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                Icons
                                    .check_circle_outline_rounded,
                                size: 12,
                                color: cs.outline),
                            const SizedBox(width: 4),
                            Text(
                              '$completed/$total serie',
                              style: TextStyle(
                                  fontSize: 12, color: cs.outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pulsante Riprendi
          GestureDetector(
            onTap: () {
              final workoutId = sp.currentWorkout?.key;
              final name = sp.currentWorkout?.name ??
                  'Allenamento';
              if (workoutId == null) return;
              pushPage(
                context,
                ActiveSessionScreen(
                  workoutId: workoutId,
                  workoutName: name,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Riprendi allenamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}