import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../session/active_session_screen.dart';
import '../workouts/allenamenti_screen.dart';
import '../workouts/workout_detail_screen.dart';

const _teal   = Color(0xFF00D4AA);
const _cyan   = Color(0xFF00E5FF);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);
const _blue   = Color(0xFF3B82F6);

// ─────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<WorkoutProvider>().loadWorkouts();
      context.read<ExerciseProvider>().loadExercises();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  String _formattedDate() {
    const days = [
      'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì',
      'Venerdì', 'Sabato', 'Domenica',
    ];
    const months = [
      'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
      'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final wp = context.watch<WorkoutProvider>();
    final ep = context.watch<ExerciseProvider>();
    final workouts = wp.workouts;
    final exerciseCount = ep.exercises.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────
                _HomeHeader(
                  greeting: _greeting(),
                  date: _formattedDate(),
                ),
                const SizedBox(height: 24),

                // ── Banner sessione attiva ────────────────────
                if (sp.hasActiveSession) ...[
                  _ActiveSessionBanner(sp: sp, fmt: _fmt),
                  const SizedBox(height: 16),
                ],

                // ── Banner sessioni in pausa ──────────────────
                if (sp.hasPausedSessions) ...[
                  _PausedSessionsMini(sp: sp, fmt: _fmt),
                  const SizedBox(height: 16),
                ],

                // ── Stats rapide ──────────────────────────────
                _QuickStatsRow(
                  workoutCount: workouts.length,
                  exerciseCount: exerciseCount,
                ),
                const SizedBox(height: 16),

                // ── Avvio rapido ──────────────────────────────
                _QuickStartPanel(
                  workouts: workouts,
                  sp: sp,
                  onViewAll: () =>
                      pushPage(context, const AllenamentiScreen()),
                  onPlay: (w) {
                    context
                        .read<WorkoutProvider>()
                        .loadWorkoutExercises(w.key);
                    pushPage(
                        context, ActiveSessionScreen(workout: w));
                  },
                  onEdit: (w) {
                    context
                        .read<WorkoutProvider>()
                        .loadWorkoutExercises(w.key);
                    pushPage(
                      context,
                      WorkoutDetailScreen(
                        workoutId: w.key,
                        workoutName: w.name,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Azioni rapide ─────────────────────────────
                _QuickActionsGrid(
                  onAllenamenti: () =>
                      pushPage(context, const AllenamentiScreen()),
                  workoutCount: workouts.length,
                  exerciseCount: exerciseCount,
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
// _HomeHeader
// ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final String greeting, date;
  const _HomeHeader({required this.greeting, required this.date});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _cyan.withOpacity(0.2), width: 0.8),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _teal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: _teal.withOpacity(0.6),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('MarkFit',
                        style: TextStyle(
                            color: _teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 10),
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(date,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13)),
                ],
              ),
            ),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_teal.withOpacity(0.3), _cyan.withOpacity(0.15)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _teal.withOpacity(0.5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: _teal.withOpacity(0.25),
                      blurRadius: 16)
                ],
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 26),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActiveSessionBanner
// ─────────────────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _ActiveSessionBanner(
      {required this.sp, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final name = sp.currentWorkout?.name ?? 'Sessione attiva';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _blue.withOpacity(0.25),
                _blue.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _blue.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.15),
                  blurRadius: 20)
            ],
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.sports_gymnastics_rounded,
                  color: Color(0xFF60A5FA), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Sessione attiva',
                    style: TextStyle(
                        color: const Color(0xFF60A5FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.timer_rounded,
                      size: 11,
                      color: const Color(0xFF60A5FA)
                          .withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(fmt(sp.elapsedSeconds),
                      style: TextStyle(
                          color: const Color(0xFF60A5FA)
                              .withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Icon(Icons.check_rounded,
                      size: 11,
                      color: const Color(0xFF60A5FA)
                          .withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(
                      '${sp.completedSetsCount}/${sp.totalSetsCount} serie',
                      style: TextStyle(
                          color: const Color(0xFF60A5FA)
                              .withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            GestureDetector(
              onTap: () {
                final w = sp.currentWorkout;
                if (w == null) return;
                pushPage(context, ActiveSessionScreen(workout: w));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Text('Riprendi',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedSessionsMini
// ─────────────────────────────────────────────────────────────

class _PausedSessionsMini extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _PausedSessionsMini(
      {required this.sp, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final paused = sp.pausedSessions;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _orange.withOpacity(0.15),
                _orange.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _orange.withOpacity(0.35), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _orange.withOpacity(0.6),
                          blurRadius: 4)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('SESSIONI IN PAUSA (${paused.length})',
                    style: TextStyle(
                        color: _orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
              ]),
              const SizedBox(height: 12),
              ...paused.take(2).map((data) {
                final name =
                    data['workoutName'] as String? ?? 'Sessione';
                final elapsed =
                    (data['elapsedAtPause'] as num?)?.toInt() ??
                        0;
                final id = data['id'] as String?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: _orange.withOpacity(0.5),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(fmt(elapsed),
                            style: TextStyle(
                                color:
                                    Colors.white.withOpacity(0.45),
                                fontSize: 11)),
                      ]),
                    ),
                    if (id != null)
                      GestureDetector(
                        onTap: () async {
                          final ok = await sp.resumePausedSession(id);
                          if (!ok || !context.mounted) return;
                          final wk = data['workoutKey'];
                          if (wk == null) return;
                          try {
                            final workout = HiveDatabase.instance
                                .getWorkouts()
                                .firstWhere((w) => w.key == wk);
                            pushPage(context,
                                ActiveSessionScreen(workout: workout));
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color: _orange.withOpacity(0.4)),
                          ),
                          child: const Text('Riprendi',
                              style: TextStyle(
                                  color: _orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]),
                );
              }),
              if (paused.length > 2)
                Text('+ ${paused.length - 2} altre in pausa',
                    style: TextStyle(
                        color: _orange.withOpacity(0.6),
                        fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickStatsRow
// ─────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final int workoutCount, exerciseCount;
  const _QuickStatsRow(
      {required this.workoutCount, required this.exerciseCount});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Icons.fitness_center_rounded,
          label: 'Schede',
          value: '$workoutCount',
          color: _teal,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatCard(
          icon: Icons.list_alt_rounded,
          label: 'Esercizi',
          value: '$exerciseCount',
          color: _cyan,
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withOpacity(0.3), width: 0.8),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.08), blurRadius: 12)
            ],
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickStartPanel
// ─────────────────────────────────────────────────────────────

class _QuickStartPanel extends StatefulWidget {
  final List<HiveWorkout> workouts;
  final SessionProvider sp;
  final VoidCallback onViewAll;
  final void Function(HiveWorkout) onPlay;
  final void Function(HiveWorkout) onEdit;

  const _QuickStartPanel({
    required this.workouts, required this.sp,
    required this.onViewAll, required this.onPlay,
    required this.onEdit,
  });

  @override
  State<_QuickStartPanel> createState() =>
      _QuickStartPanelState();
}

class _QuickStartPanelState extends State<_QuickStartPanel> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: _teal.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                  color: _teal.withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 1)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: _green, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Avvio rapido',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (widget.workouts.isNotEmpty)
                    GestureDetector(
                      onTap: widget.onViewAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _teal.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tutte',
                                style: TextStyle(
                                    color: _teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 9, color: _teal),
                          ],
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                if (widget.workouts.isEmpty)
                  _EmptyWorkoutsPlaceholder(
                      onViewAll: widget.onViewAll)
                else ...[
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.workouts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final w = widget.workouts[i];
                        final sel = _selectedIndex == i;
                        final hasPaused =
                            widget.sp.hasPausedSessionForWorkout(w.key);
                        final hasActive =
                            widget.sp.hasActiveSession &&
                                widget.sp.currentWorkout?.key == w.key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIndex = i),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: sel
                                  ? LinearGradient(colors: [
                                      _teal.withOpacity(0.2),
                                      _cyan.withOpacity(0.08),
                                    ])
                                  : null,
                              color: sel
                                  ? null
                                  : Colors.white.withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: sel
                                    ? _teal.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.1),
                                width: sel ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                WorkoutAvatar(
                                  iconId: w.iconId ?? 'dumbbell',
                                  iconColorIndex:
                                      w.iconColorIndex ?? 0,
                                  customImagePath: w.customImagePath,
                                  size: 36,
                                  iconSize: 18,
                                  borderRadius: 9,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(w.name,
                                        style: TextStyle(
                                            color: sel
                                                ? Colors.white
                                                : Colors.white
                                                    .withOpacity(0.7),
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w700),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis),
                                    if (hasPaused || hasActive)
                                      Row(children: [
                                        Container(
                                          width: 5, height: 5,
                                          decoration: BoxDecoration(
                                            color: hasPaused
                                                ? _orange
                                                : _green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasPaused
                                              ? 'In pausa'
                                              : 'In corso',
                                          style: TextStyle(
                                            color: hasPaused
                                                ? _orange
                                                : _green,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedIndex < widget.workouts.length)
                    _SelectedWorkoutActions(
                      workout: widget.workouts[_selectedIndex],
                      sp: widget.sp,
                      onPlay: () =>
                          widget.onPlay(widget.workouts[_selectedIndex]),
                      onEdit: () =>
                          widget.onEdit(widget.workouts[_selectedIndex]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedWorkoutActions extends StatelessWidget {
  final HiveWorkout workout;
  final SessionProvider sp;
  final VoidCallback onPlay, onEdit;

  const _SelectedWorkoutActions({
    required this.workout, required this.sp,
    required this.onPlay, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasPaused = sp.hasPausedSessionForWorkout(workout.key);
    final hasActive = sp.hasActiveSession &&
        sp.currentWorkout?.key == workout.key;
    final playColor = hasPaused
        ? _orange
        : hasActive
            ? _blue
            : _green;
    final playLabel = hasPaused
        ? 'Riprendi sessione'
        : hasActive
            ? 'Continua sessione'
            : 'Inizia allenamento';
    final playIcon = hasPaused || hasActive
        ? Icons.play_circle_rounded
        : Icons.play_arrow_rounded;

    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: onPlay,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                playColor,
                Color.lerp(playColor, Colors.black, 0.2) ??
                    playColor,
              ]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: playColor.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(playIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(playLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onEdit,
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: Colors.white.withOpacity(0.15), width: 0.8),
          ),
          child: Icon(Icons.edit_outlined,
              color: Colors.white.withOpacity(0.6), size: 18),
        ),
      ),
    ]);
  }
}

class _EmptyWorkoutsPlaceholder extends StatelessWidget {
  final VoidCallback onViewAll;
  const _EmptyWorkoutsPlaceholder({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _teal.withOpacity(0.2),
              width: 1,
              style: BorderStyle.solid),
        ),
        child: Column(children: [
          Icon(Icons.add_circle_outline_rounded,
              color: _teal.withOpacity(0.6), size: 32),
          const SizedBox(height: 8),
          Text('Nessuna scheda',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Vai ad Allenamenti per creare la prima',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickActionsGrid
// ─────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onAllenamenti;
  final int workoutCount, exerciseCount;

  const _QuickActionsGrid({
    required this.onAllenamenti,
    required this.workoutCount,
    required this.exerciseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _QuickActionTile(
        icon: Icons.bolt_rounded,
        title: 'Allenamenti',
        subtitle: '$workoutCount schede disponibili',
        color: _teal,
        onTap: onAllenamenti,
      ),
      const SizedBox(height: 10),
      _QuickActionTile(
        icon: Icons.list_alt_rounded,
        title: 'Libreria esercizi',
        subtitle: '$exerciseCount esercizi salvati',
        color: _cyan,
        onTap: onAllenamenti, // navigazione alla tab corretta
      ),
    ]);
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon, required this.title,
    required this.subtitle, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withOpacity(0.2), width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                ],
              )),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: color.withOpacity(0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}