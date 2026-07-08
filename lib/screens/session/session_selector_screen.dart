import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import corretto: ActiveSessionScreen (tracker live) è in questo
// stesso file active_session_screen.dart, nella stessa cartella.
import 'active_session_screen.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/workout_icon.dart';

class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});

  @override
  State<SessionSelectorScreen> createState() =>
      _SessionSelectorScreenState();
}

class _SessionSelectorScreenState
    extends State<SessionSelectorScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<WorkoutProvider>().loadWorkouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final workouts = context.watch<WorkoutProvider>().workouts;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Seleziona scheda'),
        centerTitle: true,
      ),
      body: workouts.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: workouts.length,
              itemBuilder: (_, i) {
                final w = workouts[i];
                return _WorkoutTile(
                  workout: w,
                  // Avvia ActiveSessionScreen — tracker sessione live.
                  // NON WorkoutDetailScreen (quello è l'editor scheda).
                  onTap: () => pushPage(
                    context,
                    ActiveSessionScreen(
                      workoutId: w.key,
                      workoutName: w.name,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutTile
// ─────────────────────────────────────────────────────────────

class _WorkoutTile extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onTap;

  const _WorkoutTile(
      {required this.workout, required this.onTap});

  int get _exerciseCount => HiveDatabase.instance
      .getWorkoutExercises(workout.key)
      .where((e) => !e.isInCircuit)
      .length;

  int get _circuitCount =>
      HiveDatabase.instance.getCircuits(workout.key).length;

  int get _totalSets => HiveDatabase.instance
      .getWorkoutExercises(workout.key)
      .fold(0, (s, e) => s + e.sets);

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String? _lastSessionLabel() {
    final sessions = HiveDatabase.instance
        .getSessions()
        .where((s) => s.workoutKey == workout.key)
        .toList();
    if (sessions.isEmpty) return null;
    sessions.sort((a, b) => b.date.compareTo(a.date));
    final dt = DateTime.tryParse(sessions.first.date);
    if (dt == null) return null;
    final diff = DateTime.now()
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Ultima: Oggi';
    if (diff == 1) return 'Ultima: Ieri';
    return 'Ultima: $diff giorni fa';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final exCount = _exerciseCount;
    final ciCount = _circuitCount;
    final sets = _totalSets;
    final lastLabel = _lastSessionLabel();

    final infoText = [
      if (exCount > 0) '$exCount eserc.',
      if (ciCount > 0)
        '$ciCount circuit${ciCount == 1 ? 'o' : 'i'}',
      if (sets > 0) '$sets serie',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surface.withOpacity(0.75)
                      : cs.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : cs.outlineVariant.withOpacity(0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    WorkoutAvatar(
                      iconId: workout.iconId,
                      iconColorIndex: workout.iconColorIndex,
                      customImagePath: workout.customImagePath,
                      size: 56,
                      iconSize: 28,
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (infoText.isNotEmpty)
                            Row(children: [
                              Icon(
                                  Icons.fitness_center_outlined,
                                  size: 12,
                                  color: cs.outline),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  infoText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(
                              lastLabel != null
                                  ? Icons.history_rounded
                                  : Icons.calendar_today_outlined,
                              size: 12,
                              color: lastLabel != null
                                  ? cs.primary.withOpacity(0.7)
                                  : cs.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lastLabel ??
                                    'Creata il ${_fmtDate(workout.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: lastLabel != null
                                      ? cs.primary
                                          .withOpacity(0.7)
                                      : cs.outline,
                                  fontWeight: lastLabel != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: cs.primary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.outlineVariant.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.list_alt_outlined,
                  size: 44, color: cs.outline),
            ),
            const SizedBox(height: 20),
            Text(
              'Nessuna scheda',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea prima una scheda\nnella sezione Allenamenti',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.outline,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}