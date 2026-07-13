import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/workout_icon.dart';
import '../session/active_session_screen.dart';

const _teal = Color(0xFF00D4AA);
const _orange = Color(0xFFFF8C00);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFFF3B30);

// ─────────────────────────────────────────────────────────────
// SessionSelectorScreen — selezione scheda per avviare sessione
// FIX 4: redesign Glass coerente con la dashboard Allenamenti
// ─────────────────────────────────────────────────────────────

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
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  // ── Logica avvio sessione con gestione pausa ───────────────
  // Mantenuta identica alla versione precedente.

  Future<void> _handleWorkoutTap(
    HiveWorkout workout,
    WorkoutProvider workoutProvider,
    SessionProvider sessionProvider,
  ) async {
    workoutProvider.loadWorkoutExercises(workout.key);
    if (!mounted) return;

    if (sessionProvider.hasActiveSession &&
        sessionProvider.currentWorkout?.key == workout.key) {
      final result = await showCupertinoModalPopup<String>(
        context: context,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Sessione in corso'),
          message: Text(
              'Hai una sessione attiva per "${workout.name}".'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, 'continue'),
              child: const Text('Continua sessione'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(c, 'new'),
              child: const Text('Avvia nuova sessione'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Annulla'),
          ),
        ),
      );
      if (!mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'new') await sessionProvider.abandonSession();
      if (!mounted) return;
      pushPage(context, ActiveSessionScreen(workout: workout));
      return;
    }

    if (sessionProvider.hasPausedSessionForWorkout(workout.key)) {
      final paused = sessionProvider
          .getMostRecentPausedForWorkout(workout.key);
      final result = await showCupertinoModalPopup<String>(
        context: context,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Sessione in pausa'),
          message: Text(
              'Hai una sessione in pausa per "${workout.name}".\nCosa vuoi fare?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, 'resume'),
              child: const Text('Riprendi sessione'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, 'new'),
              child: const Text('Avvia nuova sessione'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Annulla'),
          ),
        ),
      );
      if (!mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'resume' && paused != null) {
        await sessionProvider
            .resumePausedSession(paused['id'] as String);
        if (!mounted) return;
      }
      pushPage(context, ActiveSessionScreen(workout: workout));
      return;
    }

    pushPage(context, ActiveSessionScreen(workout: workout));
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final workouts = workoutProvider.workouts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AppBar Glass ──────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                              sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.15)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avvia sessione',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Scegli la tua scheda',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Banner crash-recovery ─────────────────────
              if (sessionProvider.hasActiveSession)
                _InMemorySessionBanner(
                  sp: sessionProvider,
                  onResume: () {
                    final w = sessionProvider.currentWorkout;
                    if (w == null) return;
                    pushPage(context,
                        ActiveSessionScreen(workout: w));
                  },
                  onAbandon: () async {
                    await sessionProvider.abandonSession();
                  },
                ),

              const SizedBox(height: 12),

              // ── Contenuto ─────────────────────────────────
              Expanded(
                child: workouts.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 4, 16, 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: workouts.length,
                        itemBuilder: (_, i) {
                          final workout = workouts[i];
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: 12),
                            child: _SessionWorkoutCard(
                              workout: workout,
                              hasPaused: sessionProvider
                                  .hasPausedSessionForWorkout(
                                      workout.key),
                              hasActive: sessionProvider
                                      .hasActiveSession &&
                                  sessionProvider
                                          .currentWorkout
                                          ?.key ==
                                      workout.key,
                              onTap: () => _handleWorkoutTap(
                                workout,
                                workoutProvider,
                                sessionProvider,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _InMemorySessionBanner (crash-recovery)
// ─────────────────────────────────────────────────────────────

class _InMemorySessionBanner extends StatelessWidget {
  final SessionProvider sp;
  final VoidCallback onResume;
  final VoidCallback onAbandon;

  const _InMemorySessionBanner({
    required this.sp,
    required this.onResume,
    required this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final workout = sp.currentWorkout;
    if (workout == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A8A).withOpacity(0.35),
                  const Color(0xFF1D4ED8).withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                WorkoutAvatar(
                  iconId: workout.iconId ?? 'dumbbell',
                  iconColorIndex: workout.iconColorIndex ?? 0,
                  customImagePath: workout.customImagePath,
                  size: 36,
                  iconSize: 18,
                  borderRadius: 9,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Sessione in corso',
                          style: TextStyle(
                              color: const Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      Text(workout.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onAbandon,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Text('Elimina',
                        style: TextStyle(
                            color: _red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onResume,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Riprendi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionWorkoutCard — card Glass per selezione sessione
// ─────────────────────────────────────────────────────────────

class _SessionWorkoutCard extends StatelessWidget {
  final HiveWorkout workout;
  final bool hasPaused;
  final bool hasActive;
  final VoidCallback onTap;

  const _SessionWorkoutCard({
    required this.workout,
    required this.hasPaused,
    required this.hasActive,
    required this.onTap,
  });

  Map<String, int> _stats() {
    final allEx =
        HiveDatabase.instance.getWorkoutExercises(workout.key);
    final circuits =
        HiveDatabase.instance.getCircuits(workout.key);
    return {
      'free': allEx.where((e) => !e.isInCircuit).length,
      'circuits': circuits.length,
      'sets': allEx.fold(0, (s, e) => s + e.sets),
    };
  }

  Color get _borderColor {
    if (hasPaused) return _orange;
    if (hasActive) return const Color(0xFF3B82F6);
    return _teal;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final freeEx = stats['free'] ?? 0;
    final circuits = stats['circuits'] ?? 0;
    final sets = stats['sets'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _borderColor.withOpacity(
                    hasPaused || hasActive ? 0.5 : 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _borderColor.withOpacity(0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icona scheda
                  WorkoutAvatar(
                    iconId: workout.iconId ?? 'dumbbell',
                    iconColorIndex: workout.iconColorIndex ?? 0,
                    customImagePath: workout.customImagePath,
                    size: 52,
                    iconSize: 26,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Badge stato
                        if (hasPaused || hasActive)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _borderColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: _borderColor
                                              .withOpacity(0.6),
                                          blurRadius: 4)
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasPaused
                                      ? 'Sessione in pausa'
                                      : 'Sessione in corso',
                                  style: TextStyle(
                                    color: _borderColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Text(workout.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: [
                            if (freeEx > 0)
                              _InfoTag(
                                icon: Icons
                                    .fitness_center_outlined,
                                label: '$freeEx esercizi',
                              ),
                            if (circuits > 0)
                              _InfoTag(
                                icon: Icons.loop_rounded,
                                label: '$circuits circuiti',
                              ),
                            if (sets > 0)
                              _InfoTag(
                                icon: Icons.repeat_rounded,
                                label: '$sets serie tot.',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Play button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: hasPaused
                            ? [_orange, const Color(0xFFFF6B00)]
                            : hasActive
                                ? [
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF2563EB)
                                  ]
                                : [
                                    const Color(0xFF22C55E),
                                    const Color(0xFF16A34A)
                                  ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (hasPaused
                                  ? _orange
                                  : hasActive
                                      ? const Color(0xFF3B82F6)
                                      : _green)
                              .withOpacity(0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white38),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _teal.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.fitness_center_outlined,
                  size: 38, color: _teal),
            ),
            const SizedBox(height: 20),
            const Text('Nessuna scheda disponibile',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Crea prima una scheda\nper iniziare una sessione',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}