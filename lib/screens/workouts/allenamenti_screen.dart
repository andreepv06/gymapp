import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
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
            onPressed: () =>
                pushPage(context, const ExercisesScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sessione crash-recovery (in-memory attiva) ────
          // Visibile quando l'app è stata chiusa durante una
          // sessione e viene ripristinata automaticamente.
          if (sp.hasActiveSession) ...[
            _ActiveRecoveryBanner(sp: sp),
            const SizedBox(height: 8),
            Divider(
                color: cs.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
          ],

          // ── Sessioni esplicitamente messe in pausa ────────
          // FIX 1: queste sono indipendenti dalla sessione
          // in-memory; vengono mostrate anche quando
          // hasActiveSession è false.
          if (sp.hasPausedSessions) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sessioni in pausa',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...sp.pausedSessions.map(
              (data) => _PausedSessionCard(
                data: data,
                sp: sp,
              ),
            ),
            const SizedBox(height: 8),
            Divider(
                color: cs.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
          ],

          // ── Le mie schede ─────────────────────────────────
          GlassCard(
            onTap: () =>
                pushPage(context, const WorkoutsScreen()),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded,
                    color: cs.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                Icon(Icons.chevron_right,
                    color: cs.outline),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Avvia sessione ────────────────────────────────
          GlassCard(
            onTap: () => pushPage(
                context, const SessionSelectorScreen()),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    color: cs.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                Icon(Icons.chevron_right,
                    color: cs.outline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActiveRecoveryBanner — sessione in-memory (crash recovery)
// Visibile solo quando hasActiveSession == true, ovvero quando
// la sessione non è stata esplicitamente messa in pausa ma
// è rimasta in memoria (ripristino dopo crash).
// ─────────────────────────────────────────────────────────────

class _ActiveRecoveryBanner extends StatelessWidget {
  final SessionProvider sp;

  const _ActiveRecoveryBanner({required this.sp});

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
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final workoutName =
        sp.currentWorkout?.name ?? 'Sessione attiva';
    // FIX: usa i getter corretti del nuovo SessionProvider
    final elapsed = sp.elapsedSeconds;
    final completed = sp.completedSetsCount;
    final total = sp.totalSetsCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.primaryContainer.withOpacity(0.2)
            : cs.primaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Sessione interrotta',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_gymnastics_rounded,
                  color: cs.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                                  fontSize: 12,
                                  color: cs.outline),
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
                              color: cs.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$completed/$total serie',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.outline),
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
          GestureDetector(
            onTap: () {
              final workout = sp.currentWorkout;
              if (workout == null) return;
              pushPage(
                context,
                ActiveSessionScreen(workout: workout),
              );
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.3),
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
                    'Riprendi sessione',
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

// ─────────────────────────────────────────────────────────────
// _PausedSessionCard — sessione esplicitamente messa in pausa.
// Legge i dati dalla mappa serializzata (non dall'in-memory).
// ─────────────────────────────────────────────────────────────

class _PausedSessionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final SessionProvider sp;

  const _PausedSessionCard({
    required this.data,
    required this.sp,
  });

  String _fmtElapsed(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  String _fmtAge() {
    final startStr = data['startTime'] as String?;
    if (startStr == null) return '';
    final dt = DateTime.tryParse(startStr);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    return '${diff.inDays} giorni fa';
  }

  /// Recupera il nome della scheda dal DB se non è nel data.
  String _workoutName() {
    final stored = data['workoutName'] as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    // Fallback: cerca nel DB
    final wk = data['workoutKey'];
    if (wk == null) return 'Sessione in pausa';
    try {
      final workouts = HiveDatabase.instance.getWorkouts();
      return workouts.firstWhere((w) => w.key == wk).name;
    } catch (_) {
      return 'Sessione in pausa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final id = data['id'] as String? ?? '';
    final workoutName = _workoutName();
    final elapsed =
        (data['elapsedAtPause'] as num?)?.toInt() ?? 0;
    final completed = sp.getPausedCompletedSets(data);
    final total = sp.getPausedTotalSets(data);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.withOpacity(0.1)
              : Colors.orange.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.orange.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con pulsante elimina
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    workoutName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (id.isEmpty) return;
                    await sp.deletePausedSession(id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:
                          Colors.red.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Elimina',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Info: tempo, età, serie
            Wrap(
              spacing: 14,
              runSpacing: 4,
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
                    Icon(Icons.access_time_rounded,
                        size: 12, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      _fmtAge(),
                      style: TextStyle(
                          fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 12,
                      color: cs.outline,
                    ),
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
            const SizedBox(height: 14),

            // Pulsante Riprendi
            GestureDetector(
              onTap: () async {
                if (id.isEmpty) return;
                final success =
                    await sp.resumePausedSession(id);
                if (!success) return;
                if (!context.mounted) return;
                // Cerca il workout per costruire ActiveSessionScreen
                final wk = data['workoutKey'];
                if (wk == null) return;
                try {
                  final workout = HiveDatabase.instance
                      .getWorkouts()
                      .firstWhere((w) => w.key == wk);
                  pushPage(
                    context,
                    ActiveSessionScreen(workout: workout),
                  );
                } catch (_) {}
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 11),
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
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}