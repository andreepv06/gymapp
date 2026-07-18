import 'dart:ui';
import 'package:flutter/cupertino.dart';
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
import '../exercises/exercises_screen.dart';
import '../session/active_session_screen.dart';
import 'workout_detail_screen.dart';
import 'workouts_screen.dart';

const _teal       = Color(0xFF00D4AA);
const _tealDark   = Color(0xFF00A880);
const _green      = Color(0xFF22C55E);
const _orange     = Color(0xFFFF8C00);
const _orangeWarm = Color(0xFFFF6B00);
const _red        = Color(0xFFFF3B30);
const _cyan       = Color(0xFF00E5FF);

class AllenamentiScreen extends StatefulWidget {
  const AllenamentiScreen({super.key});

  @override
  State<AllenamentiScreen> createState() =>
      _AllenamentiScreenState();
}

class _AllenamentiScreenState
    extends State<AllenamentiScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(viewportFraction: 0.88);
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── FIX TASTIERA: usa showKeyboardSafeSheet da shared_sheets ──

  Future<void> _handlePlayTap(
      BuildContext ctx, HiveWorkout workout) async {
    final wp = ctx.read<WorkoutProvider>();
    final sp = ctx.read<SessionProvider>();
    wp.loadWorkoutExercises(workout.key);

    if (sp.hasActiveSession &&
        sp.currentWorkout?.key == workout.key) {
      final result = await showCupertinoModalPopup<String>(
        context: ctx,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Sessione in corso'),
          message: Text(
              'Hai una sessione attiva per "${workout.name}".'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(c, 'continue'),
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
      if (!ctx.mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'new') await sp.abandonSession();
      if (!ctx.mounted) return;
      pushPage(ctx, ActiveSessionScreen(workout: workout));
      return;
    }

    if (sp.hasPausedSessionForWorkout(workout.key)) {
      final paused =
          sp.getMostRecentPausedForWorkout(workout.key);
      final result = await showCupertinoModalPopup<String>(
        context: ctx,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Sessione in pausa'),
          message: Text(
              'Hai una sessione in pausa per "${workout.name}".'),
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
      if (!ctx.mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'resume' && paused != null) {
        await sp.resumePausedSession(
            paused['id'] as String);
        if (!ctx.mounted) return;
      }
      pushPage(ctx, ActiveSessionScreen(workout: workout));
      return;
    }

    pushPage(ctx, ActiveSessionScreen(workout: workout));
  }

  void _handleEditTap(HiveWorkout workout) {
    context
        .read<WorkoutProvider>()
        .loadWorkoutExercises(workout.key);
    pushPage(
      context,
      WorkoutDetailScreen(
        workoutId: workout.key,
        workoutName: workout.name,
      ),
    );
  }

  // PUNTO 2: popup UNIFICATO creazione scheda — stesso di WorkoutsScreen
  Future<void> _showCreateWorkoutSheet() async {
    await showKeyboardSafeSheet(
      context,
      WorkoutCreateSheet(
        onConfirm: (name) {
          HiveDatabase.instance.addWorkout(HiveWorkout(
            name: name,
            iconId: 'dumbbell',
            iconColorIndex: 0,
            createdAt: DateTime.now().toIso8601String(),
          ));
          if (mounted) {
            context.read<WorkoutProvider>().loadWorkouts();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // PUNTO 1: popup UNIFICATO creazione esercizio — stesso di ExercisesScreen
  Future<void> _showNewExerciseSheet() async {
    final exercises =
        context.read<ExerciseProvider>().exercises;
    await showKeyboardSafeSheet(
      context,
      ExerciseFormSheet(
        existingNames: exercises
            .map((e) => e.name.toLowerCase())
            .toSet(),
        onConfirm: (name, muscleGroup, notes) {
          HiveDatabase.instance.addExercise(HiveExercise(
            name: name,
            muscleGroup: muscleGroup,
            notes: notes.isNotEmpty ? notes : null,
          ));
          if (mounted) {
            context
                .read<ExerciseProvider>()
                .loadExercises();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // PUNTO 4: elimina scheda con conferma
  Future<void> _deleteWorkout(HiveWorkout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: _red, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text('Eliminare questa scheda?',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare definitivamente '
          '"${workout.name}"?',
          style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(
                    color: _red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await HiveDatabase.instance
          .deleteWorkout(workout.key);
      context.read<WorkoutProvider>().loadWorkouts();
      // Resetta il carosello se necessario
      final workouts =
          context.read<WorkoutProvider>().workouts;
      if (_currentPage >= workouts.length &&
          workouts.isNotEmpty) {
        setState(
            () => _currentPage = workouts.length - 1);
        _pageController.jumpToPage(_currentPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final workouts =
        context.watch<WorkoutProvider>().workouts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allenamenti',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Il tuo spazio fitness',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _GestioneEserciziPill(
                      onLibrary: () => pushPage(
                          context,
                          const ExercisesScreen()),
                      onNewExercise:
                          _showNewExerciseSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Banner sessione attiva
                if (sp.hasActiveSession) ...[
                  _ActiveRecoveryBanner(sp: sp),
                  const SizedBox(height: 16),
                ],

                // Sessioni in pausa
                if (sp.hasPausedSessions) ...[
                  _SectionLabel(
                    label: 'PAUSED SESSION',
                    color: _orange,
                    icon: Icons
                        .pause_circle_filled_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...sp.pausedSessions.map((data) =>
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 12),
                        child: _PausedSessionPanel(
                          data: data,
                          sp: sp,
                          onResume: () async {
                            final id =
                                data['id'] as String?;
                            if (id == null) return;
                            await sp.resumePausedSession(
                                id);
                            if (!mounted) return;
                            final wk =
                                data['workoutKey'];
                            if (wk == null) return;
                            try {
                              final workout =
                                  HiveDatabase
                                      .instance
                                      .getWorkouts()
                                      .firstWhere(
                                          (w) =>
                                              w.key ==
                                              wk);
                              pushPage(
                                context,
                                ActiveSessionScreen(
                                    workout: workout),
                              );
                            } catch (_) {}
                          },
                          onDelete: () async {
                            final id =
                                data['id'] as String?;
                            if (id != null) {
                              await sp
                                  .deletePausedSession(
                                      id);
                            }
                          },
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Nuova sessione panel
                _NuovaSessionePanel(
                  workouts: workouts,
                  currentPage: _currentPage,
                  pageController: _pageController,
                  onPageChanged: (i) =>
                      setState(() => _currentPage = i),
                  onPlay: (w) =>
                      _handlePlayTap(context, w),
                  onEdit: _handleEditTap,
                  onDelete: _deleteWorkout,
                  onViewAll: () => pushPage(
                      context, const WorkoutsScreen()),
                  onCreateNew: _showCreateWorkoutSheet,
                  sp: sp,
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
// _GestioneEserciziPill
// ─────────────────────────────────────────────────────────────

class _GestioneEserciziPill extends StatelessWidget {
  final VoidCallback onLibrary;
  final VoidCallback onNewExercise;

  const _GestioneEserciziPill({
    required this.onLibrary,
    required this.onNewExercise,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillButton(
                icon: Icons.list_alt_rounded,
                color: Colors.white70,
                onTap: onLibrary,
                tooltip: 'Libreria esercizi',
              ),
              Container(
                width: 1,
                height: 20,
                color: Colors.white.withOpacity(0.15),
              ),
              _PillButton(
                icon: Icons.add_rounded,
                color: _teal,
                onTap: onNewExercise,
                tooltip: 'Nuovo esercizio',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _PillButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () =>
            setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.color.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon,
                size: 20, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SectionLabel
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActiveRecoveryBanner
// ─────────────────────────────────────────────────────────────

class _ActiveRecoveryBanner extends StatelessWidget {
  final SessionProvider sp;

  const _ActiveRecoveryBanner({required this.sp});

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final name = sp.currentWorkout?.name ?? 'Sessione attiva';
    final elapsed = sp.elapsedSeconds;
    final completed = sp.completedSetsCount;
    final total = sp.totalSetsCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A8A).withOpacity(0.4),
                const Color(0xFF1D4ED8).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  const Color(0xFF3B82F6).withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6)
                    .withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6)
                      .withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.sports_gymnastics_rounded,
                    color: Color(0xFF60A5FA),
                    size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessione interrotta',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.timer_outlined,
                          label: _fmt(elapsed),
                          color: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.check_rounded,
                          label: '$completed/$total serie',
                          color: const Color(0xFF60A5FA),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final workout = sp.currentWorkout;
                  if (workout == null) return;
                  pushPage(context,
                      ActiveSessionScreen(workout: workout));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6)
                            .withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text('Riprendi',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
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
// _PausedSessionPanel
// ─────────────────────────────────────────────────────────────

class _PausedSessionPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final SessionProvider sp;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _PausedSessionPanel({
    required this.data,
    required this.sp,
    required this.onResume,
    required this.onDelete,
  });

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  String _age() {
    final str = data['startTime'] as String?;
    if (str == null) return '';
    final dt = DateTime.tryParse(str);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ora';
    if (diff.inHours < 1) return '${diff.inMinutes} min fa';
    if (diff.inDays < 1) return '${diff.inHours} ore fa';
    return '${diff.inDays} giorni fa';
  }

  String _name() {
    final stored = data['workoutName'] as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    final wk = data['workoutKey'];
    if (wk == null) return 'Sessione in pausa';
    try {
      return HiveDatabase.instance
          .getWorkouts()
          .firstWhere((w) => w.key == wk)
          .name;
    } catch (_) {
      return 'Sessione in pausa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        (data['elapsedAtPause'] as num?)?.toInt() ?? 0;
    final completed = sp.getPausedCompletedSets(data);
    final total = sp.getPausedTotalSets(data);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _orange.withOpacity(0.18),
                _orangeWarm.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _orange.withOpacity(0.45),
                width: 1.3),
            boxShadow: [
              BoxShadow(
                  color: _orange.withOpacity(0.2),
                  blurRadius: 28,
                  spreadRadius: 1)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    _orange.withOpacity(0.7),
                                blurRadius: 6)
                          ],
                        )),
                    const SizedBox(width: 8),
                    Text('PAUSED SESSION',
                        style: TextStyle(
                          color: _orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        )),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  _red.withOpacity(0.35)),
                        ),
                        child: const Text('Elimina',
                            style: TextStyle(
                                color: _red,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(_name(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatChip(
                        icon: Icons.timer_outlined,
                        label: _fmt(elapsed),
                        color: _orange),
                    _StatChip(
                        icon: Icons.access_time_rounded,
                        label: _age(),
                        color: _orange),
                    _StatChip(
                        icon: Icons
                            .check_circle_outline_rounded,
                        label: '$completed/$total serie',
                        color: _orange),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onResume,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_orange, _orangeWarm]),
                      borderRadius:
                          BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: _orange.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text('Riprendi allenamento',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
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
// _NuovaSessionePanel
// ─────────────────────────────────────────────────────────────

class _NuovaSessionePanel extends StatelessWidget {
  final List<HiveWorkout> workouts;
  final int currentPage;
  final PageController pageController;
  final void Function(int) onPageChanged;
  final void Function(HiveWorkout) onPlay;
  final void Function(HiveWorkout) onEdit;
  final void Function(HiveWorkout) onDelete;
  final VoidCallback onViewAll;
  final VoidCallback onCreateNew;
  final SessionProvider sp;

  const _NuovaSessionePanel({
    required this.workouts,
    required this.currentPage,
    required this.pageController,
    required this.onPageChanged,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onViewAll,
    required this.onCreateNew,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
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
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _teal.withOpacity(0.35), width: 1.3),
            boxShadow: [
              BoxShadow(
                  color: _teal.withOpacity(0.12),
                  blurRadius: 32,
                  spreadRadius: 1)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header panel
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: _teal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Nuova Sessione',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w800)),
                        Text('Scegli come iniziare',
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.45),
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // "Le tue schede" + Vedi tutte
                Row(
                  children: [
                    Text('Le tue schede',
                        style: TextStyle(
                            color:
                                Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                    const Spacer(),
                    if (workouts.isNotEmpty)
                      GestureDetector(
                        onTap: onViewAll,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7),
                              decoration: BoxDecoration(
                                color:
                                    _teal.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        _teal.withOpacity(0.35),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Vedi tutte',
                                      style: TextStyle(
                                          color: _teal,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  Icon(
                                      Icons
                                          .arrow_forward_ios_rounded,
                                      size: 10,
                                      color: _teal),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Carosello schede o empty state
                if (workouts.isEmpty)
                  // PUNTO 5: centering fix — Center esplicito
                  Center(
                    child: _EmptyCarouselCard(
                        onCreateNew: onCreateNew),
                  )
                else ...[
                  SizedBox(
                    height: 196,
                    child: PageView.builder(
                      controller: pageController,
                      onPageChanged: onPageChanged,
                      itemCount: workouts.length,
                      itemBuilder: (ctx, i) {
                        final w = workouts[i];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 6),
                          child: _WorkoutCarouselCard(
                            workout: w,
                            hasPaused: sp
                                .hasPausedSessionForWorkout(
                                    w.key),
                            hasActive: sp.hasActiveSession &&
                                sp.currentWorkout?.key ==
                                    w.key,
                            onPlay: () => onPlay(w),
                            onEdit: () => onEdit(w),
                            onDelete: () => onDelete(w),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (workouts.length > 1)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            List.generate(workouts.length,
                                (i) {
                          final active = i == currentPage;
                          return AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 250),
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 3),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? _teal
                                  : Colors.white
                                      .withOpacity(0.25),
                              borderRadius:
                                  BorderRadius.circular(3),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                          color: _teal
                                              .withOpacity(0.5),
                                          blurRadius: 6)
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Divider(
                    color: Colors.white.withOpacity(0.1),
                    height: 1),
                const SizedBox(height: 20),

                // Crea nuova scheda
                GestureDetector(
                  onTap: onCreateNew,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _teal.withOpacity(0.25),
                        _tealDark.withOpacity(0.15),
                      ]),
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                          color: _teal.withOpacity(0.5),
                          width: 1.3),
                      boxShadow: [
                        BoxShadow(
                            color: _teal.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 1)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.add_rounded,
                              color: _teal,
                              size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text('Crea nuova scheda',
                            style: TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    ),
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
// PUNTO 4: _WorkoutCarouselCard con pulsante cestino
// ─────────────────────────────────────────────────────────────

class _WorkoutCarouselCard extends StatelessWidget {
  final HiveWorkout workout;
  final bool hasPaused;
  final bool hasActive;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkoutCarouselCard({
    required this.workout,
    required this.hasPaused,
    required this.hasActive,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final freeEx = stats['free'] ?? 0;
    final circuits = stats['circuits'] ?? 0;
    final sets = stats['sets'] ?? 0;
    final indicator = hasPaused
        ? _orange
        : hasActive
            ? const Color(0xFF3B82F6)
            : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
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
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: indicator != null
                  ? indicator.withOpacity(0.5)
                  : _teal.withOpacity(0.35),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                  color: (indicator ?? _teal).withOpacity(0.15),
                  blurRadius: 20)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicatore stato
                if (indicator != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: indicator,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      indicator.withOpacity(0.6),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasPaused ? 'In pausa' : 'In corso',
                          style: TextStyle(
                              color: indicator,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),

                // Info scheda
                Row(
                  children: [
                    WorkoutAvatar(
                      iconId: workout.iconId ?? 'dumbbell',
                      iconColorIndex:
                          workout.iconColorIndex ?? 0,
                      customImagePath: workout.customImagePath,
                      size: 44,
                      iconSize: 22,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(workout.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (freeEx > 0)
                                _TinyChip(
                                    label:
                                        '$freeEx eserc.'),
                              if (circuits > 0)
                                _TinyChip(
                                    label:
                                        '$circuits circuiti'),
                              if (sets > 0)
                                _TinyChip(
                                    label: '$sets serie'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Azioni
                Row(
                  children: [
                    // Modifica
                    GestureDetector(
                      onTap: onEdit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 13,
                              color:
                                  Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 5),
                          Text('Modifica',
                              style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.5),
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PUNTO 4: cestino con conferma
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: _red.withOpacity(0.3),
                              width: 0.8),
                        ),
                        child: Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: _red.withOpacity(0.8)),
                      ),
                    ),
                    const Spacer(),
                    // Play
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: hasPaused
                                ? [_orange, _orangeWarm]
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
                                      : _green)
                                  .withOpacity(0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28),
                      ),
                    ),
                  ],
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
// PUNTO 5: _EmptyCarouselCard — perfettamente centrato
// ─────────────────────────────────────────────────────────────

class _EmptyCarouselCard extends StatelessWidget {
  final VoidCallback onCreateNew;

  const _EmptyCarouselCard({required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCreateNew,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 196,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _teal.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: _cyan.withOpacity(0.3), width: 1.3),
              boxShadow: [
                BoxShadow(
                    color: _cyan.withOpacity(0.08),
                    blurRadius: 20)
              ],
            ),
            child: Column(
              // PUNTO 5: centramento esplicito su entrambi gli assi
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _teal.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: _teal, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Crea la tua prima scheda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inizia il tuo percorso fitness',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12),
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
// _TinyChip / _StatChip
// ─────────────────────────────────────────────────────────────

class _TinyChip extends StatelessWidget {
  final String label;
  const _TinyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}