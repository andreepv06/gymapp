import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF1744);
const _green  = Color(0xFF22C55E);

// ─────────────────────────────────────────────────────────────
// ActiveSessionScreen
// ─────────────────────────────────────────────────────────────

class ActiveSessionScreen extends StatefulWidget {
  final HiveWorkout workout;
  const ActiveSessionScreen({super.key, required this.workout});

  @override
  State<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState
    extends State<ActiveSessionScreen> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initSession());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSession() async {
    final sp = context.read<SessionProvider>();
    if (sp.hasActiveSession &&
        sp.currentWorkout?.key == widget.workout.key) return;
    if (sp.hasActiveSession) return;
    final exercises =
        HiveDatabase.instance.getWorkoutExercises(widget.workout.key);
    final circuits =
        HiveDatabase.instance.getCircuits(widget.workout.key);
    await sp.startSession(
      exercises,
      widget.workout.key,
      widget.workout.name,
      widget.workout,
      circuits: circuits,
    );
  }

  String _fmt(int s) {
    final h   = s ~/ 3600;
    final m   = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm  = m.toString().padLeft(2, '0');
    final ss  = sec.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  // Stessa architettura di _openSheet in workout_detail_screen.dart
  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    final sp = context.read<SessionProvider>();
    if (!sp.hasAnyData) {
      final ok = await showGlassDialog<bool>(
        context: context,
        accentColor: _red,
        title: 'Abbandonare la sessione?',
        message: 'Non hai ancora completato nessuna serie. '
            'La sessione verrà eliminata.',
        actions: [
          GlassDialogAction(
              label: 'Continua',
              onTap: () => Navigator.pop(context, false)),
          GlassDialogAction(
              label: 'Abbandona',
              isDestructive: true,
              onTap: () => Navigator.pop(context, true)),
        ],
      );
      if (ok == true && mounted) {
        await sp.abandonSession();
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }
    final result = await showGlassDialog<String>(
      context: context,
      accentColor: _orange,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _orange.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: _orange.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: _orange.withOpacity(0.2), blurRadius: 12)
          ],
        ),
        child: const Icon(Icons.pause_circle_outline_rounded,
            color: _orange, size: 22),
      ),
      title: 'Sessione in corso',
      message: 'Vuoi mettere in pausa o abbandonare '
          'definitivamente la sessione?',
      actions: [
        GlassDialogAction(
            label: 'Annulla',
            onTap: () => Navigator.pop(context, 'cancel')),
        GlassDialogAction(
            label: 'Pausa',
            color: _orange,
            onTap: () => Navigator.pop(context, 'pause')),
        GlassDialogAction(
            label: 'Abbandona',
            isDestructive: true,
            onTap: () => Navigator.pop(context, 'abandon')),
      ],
    );
    if (!mounted) return;
    if (result == 'pause') {
      await sp.pauseSession();
      if (mounted) Navigator.of(context).pop();
    } else if (result == 'abandon') {
      await sp.abandonSession();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _finishSession() async {
    final sp = context.read<SessionProvider>();
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: _teal,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: _teal.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 12)
          ],
        ),
        child: const Icon(Icons.check_circle_outline_rounded,
            color: _teal, size: 22),
      ),
      title: 'Termina sessione',
      message: 'Tutte le serie completate verranno salvate '
          'nello storico degli allenamenti.',
      actions: [
        GlassDialogAction(
            label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: 'Termina',
            isDefault: true,
            color: _teal,
            onTap: () => Navigator.pop(context, true)),
      ],
    );
    if (ok == true && mounted) {
      await sp.finishSession();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showAddMenu() async {
    await _openSheet(_AddToSessionSheet(
      onAddExercise: () {
        Navigator.pop(context);
        _showAddExerciseSheet();
      },
      onAddCircuit: () {
        Navigator.pop(context);
        _showAddCircuitSheet();
      },
    ));
  }

  Future<void> _showAddExerciseSheet() async {
    final sp = context.read<SessionProvider>();
    final all = HiveDatabase.instance.getExercises();
    final alreadyIn = sp.sessionExercises
        .where((e) => e.circuitId == null)
        .map((e) => e.exerciseKey)
        .toSet();
    await _openSheet(_AddExerciseToSessionSheet(
      allExercises: all,
      alreadyIn: alreadyIn,
      onConfirm: (keys) async {
        for (final k in keys) {
          try {
            final ex = all.firstWhere((e) => e.key == k);
            await sp.addExerciseToSession(
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
            );
          } catch (_) {}
        }
        if (mounted) Navigator.pop(context);
      },
    ));
  }

  Future<void> _showAddCircuitSheet() async {
    final sp = context.read<SessionProvider>();
    final all = HiveDatabase.instance.getExercises();
    await _openSheet(_AddCircuitToSessionSheet(
      allExercises: all,
      onConfirm: (keys, rounds, name) async {
        final exList =
            <({dynamic exerciseKey, String exerciseName, String muscleGroup})>[];
        for (final k in keys) {
          try {
            final ex = all.firstWhere((e) => e.key == k);
            exList.add((
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
            ));
          } catch (_) {}
        }
        await sp.addCircuitToSession(
            exercises: exList, rounds: rounds, name: name);
        if (mounted) Navigator.pop(context);
      },
    ));
  }

  Future<void> _showModifyCircuitSheet(String circuitId) async {
    final sp = context.read<SessionProvider>();
    final all = HiveDatabase.instance.getExercises();
    await _openSheet(_ModifyCircuitInSessionSheet(
      circuitId: circuitId,
      circuitName: sp.getCircuitName(circuitId),
      allExercises: all,
      currentExercises: sp.sessionExercises
          .where((e) => e.circuitId == circuitId)
          .toList(),
      currentRounds: sp.getTotalRounds(circuitId),
      onAddExercise: (exKey) {
        try {
          final ex = all.firstWhere((e) => e.key == exKey);
          sp.addExerciseToCircuitInSession(
            circuitId: circuitId,
            exerciseKey: ex.key,
            exerciseName: ex.name,
            muscleGroup: ex.muscleGroup,
          );
        } catch (_) {}
      },
      onRemoveExercise: (exKey) => sp.removeExerciseFromCircuitInSession(
          circuitId: circuitId, exerciseKey: exKey),
      onChangeRounds: (r) => sp.setCircuitRoundsInSession(circuitId, r),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF03040A),
        body: CosmicBackground(
          subtle: true,
          child: SafeArea(
            child: Consumer<SessionProvider>(
              builder: (context, sp, _) {
                if (!sp.hasActiveSession) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(
                              color: _teal, strokeWidth: 2),
                        ),
                        const SizedBox(height: 16),
                        Text('Avvio sessione...',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 14)),
                      ],
                    ),
                  );
                }

                final freeExs = sp.sessionExercises
                    .where((e) => e.circuitId == null)
                    .toList();
                final circuitIds = <String>[];
                final seen = <String>{};
                for (final ex in sp.sessionExercises) {
                  if (ex.circuitId != null &&
                      seen.add(ex.circuitId!)) {
                    circuitIds.add(ex.circuitId!);
                  }
                }

                return Column(
                  children: [
                    _SessionHeader(
                      workoutName: widget.workout.name,
                      elapsed: sp.elapsedSeconds,
                      completed: sp.completedSetsCount,
                      total: sp.totalSetsCount,
                      formatTime: _fmt,
                      onBack: _onBack,
                    ),
                    if (sp.isResting)
                      _RestTimerBanner(
                        elapsed: sp.restElapsed,
                        onStop: sp.stopRestTimer,
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, 20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ...freeExs.map((ex) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: _SessionExerciseCard(
                              key: ValueKey('ex_${ex.exerciseKey}'),
                              exercise: ex,
                              sets: sp.exerciseSets[ex.exerciseKey] ??
                                  [],
                              isRestingHere: sp.isResting &&
                                  sp.restingExerciseId ==
                                      ex.exerciseKey,
                              onToggle: (i) =>
                                  sp.toggleSet(ex.exerciseKey, i),
                              onUpdate: (i, w, r) => sp.updateSet(
                                  ex.exerciseKey, i, w, r),
                              onAddSet: () =>
                                  sp.addSetToExercise(ex.exerciseKey),
                              onRemoveSet: () => sp
                                  .removeSetFromExercise(ex.exerciseKey),
                              onRemove: () => sp
                                  .removeExerciseFromSession(
                                      ex.exerciseKey),
                              onUpdateNote: (note) => sp
                                  .updateExerciseNote(
                                      ex.exerciseKey, note),
                              currentNote: ex.sessionNote ?? '',
                            ),
                          )),
                          ...circuitIds.map((cid) {
                            final circExs = sp.sessionExercises
                                .where((e) => e.circuitId == cid)
                                .toList();
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: _SessionCircuitCard(
                                key: ValueKey('circ_$cid'),
                                circuitId: cid,
                                circuitName:
                                    sp.getCircuitName(cid),
                                exercises: circExs,
                                currentRound:
                                    sp.getCurrentRound(cid),
                                totalRounds:
                                    sp.getTotalRounds(cid),
                                getSets: (exKey) =>
                                    sp.getCircuitSets(cid, exKey),
                                onNextRound: () =>
                                    sp.nextRound(cid),
                                onPrevRound: () =>
                                    sp.prevRound(cid),
                                onToggle: (exKey, i) => sp.toggleSet(
                                    exKey, i,
                                    circuitId: cid),
                                onUpdate: (exKey, i, w, r) =>
                                    sp.updateSet(exKey, i, w, r,
                                        circuitId: cid),
                                onAddSet: (exKey) =>
                                    sp.addSetToExercise(exKey,
                                        circuitId: cid),
                                onRemoveSet: (exKey) =>
                                    sp.removeSetFromExercise(exKey,
                                        circuitId: cid),
                                onModify: () =>
                                    _showModifyCircuitSheet(cid),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    _SessionActionsBar(
                      onAdd: _showAddMenu,
                      onFinish: _finishSession,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionHeader
// ─────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  final String workoutName;
  final int elapsed;
  final int completed;
  final int total;
  final String Function(int) formatTime;
  final VoidCallback onBack;

  const _SessionHeader({
    required this.workoutName,
    required this.elapsed,
    required this.completed,
    required this.total,
    required this.formatTime,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _cyan.withOpacity(0.2), width: 0.8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workoutName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text('Sessione in corso',
                                  style: TextStyle(
                                      color: _green.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: _teal, size: 13),
                          const SizedBox(width: 5),
                          Text(formatTime(elapsed),
                              style: const TextStyle(
                                  color: _teal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('$completed/$total serie',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11)),
                    const Spacer(),
                    Text(
                        '${total > 0 ? (progress * 100).round() : 0}%',
                        style: TextStyle(
                            color: _teal.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor:const AlwaysStoppedAnimation<Color>(_teal),
                    minHeight: 4,
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
// _RestTimerBanner
// ─────────────────────────────────────────────────────────────

class _RestTimerBanner extends StatelessWidget {
  final int elapsed;
  final VoidCallback onStop;

  const _RestTimerBanner(
      {required this.elapsed, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _indigo.withOpacity(0.2),
                  _indigo.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _indigo.withOpacity(0.4), width: 1),
              boxShadow: [
                BoxShadow(
                    color: _indigo.withOpacity(0.15),
                    blurRadius: 12)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_rounded,
                      color: _indigo, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recupero in corso',
                          style: TextStyle(
                              color: _indigo.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3)),
                      Text(
                        '${elapsed}s',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _indigo.withOpacity(0.4)),
                    ),
                    child: const Text('Stop',
                        style: TextStyle(
                            color: _indigo,
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
// _SessionActionsBar
// ─────────────────────────────────────────────────────────────

class _SessionActionsBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onFinish;

  const _SessionActionsBar(
      {required this.onAdd, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // Aggiungi
          Expanded(
            child: GestureDetector(
              onTap: onAdd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color:
                                Colors.white.withOpacity(0.7),
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Aggiungi',
                            style: TextStyle(
                                color:
                                    Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Termina
          Expanded(
            child: GestureDetector(
              onTap: onFinish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _teal,
                    Color.lerp(_teal, Colors.black, 0.2) ?? _teal,
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Termina',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionExerciseCard
// ─────────────────────────────────────────────────────────────

class _SessionExerciseCard extends StatefulWidget {
  final SessionExercise exercise;
  final List<ActiveSet> sets;
  final bool isRestingHere;
  final void Function(int index) onToggle;
  final void Function(int index, double weight, int reps) onUpdate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final VoidCallback onRemove;
  final Future<void> Function(String) onUpdateNote;
  final String currentNote;

  const _SessionExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.isRestingHere,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemove,
    required this.onUpdateNote,
    required this.currentNote,
  });

  @override
  State<_SessionExerciseCard> createState() =>
      _SessionExerciseCardState();
}

class _SessionExerciseCardState
    extends State<_SessionExerciseCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final completedCount =
        widget.sets.where((s) => s.completed).length;
    final totalCount = widget.sets.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isRestingHere
                  ? _indigo.withOpacity(0.5)
                  : _cyan.withOpacity(0.15),
              width: widget.isRestingHere ? 1.2 : 0.8,
            ),
            boxShadow: widget.isRestingHere
                ? [
                    BoxShadow(
                        color: _indigo.withOpacity(0.12),
                        blurRadius: 16)
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Header
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      14, 12, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: _teal.withOpacity(0.2)),
                        ),
                        child: const Icon(
                            Icons.fitness_center_rounded,
                            color: _teal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.exercise.exerciseName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            Text(
                              '$completedCount/$totalCount serie',
                              style: TextStyle(
                                  color: completedCount ==
                                          totalCount &&
                                          totalCount > 0
                                      ? _teal
                                      : Colors.white
                                          .withOpacity(0.4),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Rimuovi
                      GestureDetector(
                        onTap: widget.onRemove,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(7),
                          ),
                          child: Icon(
                              Icons.delete_outline_rounded,
                              size: 13,
                              color: _red.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.35),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Container(
                  height: 0.6,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 14),
                  color: Colors.white.withOpacity(0.06),
                ),
                // Serie
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      14, 8, 14, 4),
                  child: Column(
                    children: widget.sets
                        .asMap()
                        .entries
                        .map((e) => _SetRow(
                              index: e.key,
                              set: e.value,
                              onToggle: () =>
                                  widget.onToggle(e.key),
                              onUpdate: (w, r) =>
                                  widget.onUpdate(e.key, w, r),
                            ))
                        .toList(),
                  ),
                ),
                // +/- serie
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      14, 0, 14, 10),
                  child: Row(
                    children: [
                      _SmallBtn(
                        icon: Icons.remove_rounded,
                        color: Colors.white.withOpacity(0.35),
                        onTap: widget.onRemoveSet,
                      ),
                      const SizedBox(width: 8),
                      _SmallBtn(
                        icon: Icons.add_rounded,
                        color: _teal,
                        onTap: widget.onAddSet,
                      ),
                      const Spacer(),
                      // Nota
                      _NoteChip(
                        note: widget.currentNote,
                        onSave: widget.onUpdateNote,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionCircuitCard
// ─────────────────────────────────────────────────────────────

class _SessionCircuitCard extends StatefulWidget {
  final String circuitId;
  final String circuitName;
  final List<SessionExercise> exercises;
  final int currentRound;
  final int totalRounds;
  final List<ActiveSet> Function(dynamic exKey) getSets;
  final VoidCallback onNextRound;
  final VoidCallback onPrevRound;
  final void Function(dynamic exKey, int index) onToggle;
  final void Function(dynamic exKey, int index, double weight,
      int reps) onUpdate;
  final void Function(dynamic exKey) onAddSet;
  final void Function(dynamic exKey) onRemoveSet;
  final VoidCallback onModify;

  const _SessionCircuitCard({
    super.key,
    required this.circuitId,
    required this.circuitName,
    required this.exercises,
    required this.currentRound,
    required this.totalRounds,
    required this.getSets,
    required this.onNextRound,
    required this.onPrevRound,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onModify,
  });

  @override
  State<_SessionCircuitCard> createState() =>
      _SessionCircuitCardState();
}

class _SessionCircuitCardState
    extends State<_SessionCircuitCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    int completedCount = 0;
    int totalCount = 0;
    for (final ex in widget.exercises) {
      final sets = widget.getSets(ex.exerciseKey);
      completedCount += sets.where((s) => s.completed).length;
      totalCount += sets.length;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _indigo.withOpacity(0.12),
                _indigo.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _indigo.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                  color: _indigo.withOpacity(0.1),
                  blurRadius: 16)
            ],
          ),
          child: Column(
            children: [
              // Header circuito
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      14, 12, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.loop_rounded,
                            color: _indigo, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.circuitName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            Text(
                              '$completedCount/$totalCount serie',
                              style: TextStyle(
                                  color: _indigo.withOpacity(0.8),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Modifica circuito in sessione
                      GestureDetector(
                        onTap: widget.onModify,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: _indigo.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    _indigo.withOpacity(0.3)),
                          ),
                          child: const Text('Modifica',
                              style: TextStyle(
                                  color: _indigo,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons
                                .keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.35),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                // Navigazione round
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _indigo.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.currentRound > 0
                            ? widget.onPrevRound
                            : null,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: widget.currentRound > 0
                                ? _indigo.withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.chevron_left_rounded,
                              color: widget.currentRound > 0
                                  ? _indigo
                                  : Colors.white
                                      .withOpacity(0.2),
                              size: 18),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Ciclo ${widget.currentRound + 1} di ${widget.totalRounds}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            widget.currentRound < widget.totalRounds - 1
                                ? widget.onNextRound
                                : null,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: widget.currentRound < widget.totalRounds - 1
                                ? _indigo.withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.chevron_right_rounded,
                              color: widget.currentRound < widget.totalRounds - 1
                                  ? _indigo
                                  : Colors.white
                                      .withOpacity(0.2),
                              size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Esercizi del circuito
                ...widget.exercises.map((ex) {
                  final sets =
                      widget.getSets(ex.exerciseKey);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        10, 0, 10, 8),
                    child: _CircuitExerciseBlock(
                      exercise: ex,
                      sets: sets,
                      onToggle: (i) =>
                          widget.onToggle(ex.exerciseKey, i),
                      onUpdate: (i, w, r) => widget.onUpdate(
                          ex.exerciseKey, i, w, r),
                      onAddSet: () =>
                          widget.onAddSet(ex.exerciseKey),
                      onRemoveSet: () =>
                          widget.onRemoveSet(ex.exerciseKey),
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitExerciseBlock
// ─────────────────────────────────────────────────────────────

class _CircuitExerciseBlock extends StatelessWidget {
  final SessionExercise exercise;
  final List<ActiveSet> sets;
  final void Function(int) onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;

  const _CircuitExerciseBlock({
    required this.exercise,
    required this.sets,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _indigo.withOpacity(0.15), width: 0.7),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: _indigo,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(exercise.exerciseName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...sets.asMap().entries.map((e) => _SetRow(
                    index: e.key,
                    set: e.value,
                    onToggle: () => onToggle(e.key),
                    onUpdate: (w, r) =>
                        onUpdate(e.key, w, r),
                    compact: true,
                  )),
              const SizedBox(height: 4),
              Row(
                children: [
                  _SmallBtn(
                    icon: Icons.remove_rounded,
                    color: Colors.white.withOpacity(0.35),
                    onTap: onRemoveSet,
                  ),
                  const SizedBox(width: 6),
                  _SmallBtn(
                    icon: Icons.add_rounded,
                    color: _indigo,
                    onTap: onAddSet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SetRow
// ─────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final int index;
  final ActiveSet set;
  final VoidCallback onToggle;
  final void Function(double weight, int reps) onUpdate;
  final bool compact;

  const _SetRow({
    required this.index,
    required this.set,
    required this.onToggle,
    required this.onUpdate,
    this.compact = false,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.set.weight > 0
            ? widget.set.weight.toString()
            : '');
    _repsCtrl = TextEditingController(
        text: widget.set.reps.toString());
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SetRow old) {
    super.didUpdateWidget(old);
    if (old.set.weight != widget.set.weight &&
        !_weightCtrl.text.contains(
            widget.set.weight.toString().replaceAll('.0', ''))) {
      _weightCtrl.text = widget.set.weight > 0
          ? widget.set.weight.toString()
          : '';
    }
    if (old.set.reps != widget.set.reps) {
      _repsCtrl.text = widget.set.reps.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.set.completed;
    final accentColor = completed ? _teal : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Numero serie
          SizedBox(
            width: 24,
            child: Text('${widget.index + 1}',
                style: TextStyle(
                    color: accentColor.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          // Peso
          Expanded(
            child: Container(
              height: widget.compact ? 30 : 34,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: completed
                      ? _teal.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: widget.set.lastWeight != null
                            ? '${widget.set.lastWeight}'
                            : 'kg',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 12),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 6),
                      ),
                      onChanged: (v) {
                        final w = double.tryParse(v) ?? 0;
                        final r = int.tryParse(
                                _repsCtrl.text) ??
                            widget.set.reps;
                        widget.onUpdate(w, r);
                      },
                    ),
                  ),
                  Text('kg',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 10)),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          // Ripetizioni
          SizedBox(
            width: widget.compact ? 52 : 60,
            height: widget.compact ? 30 : 34,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: completed
                      ? _teal.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _repsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: widget.set.lastReps != null
                            ? '${widget.set.lastReps}'
                            : 'rip',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 12),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 4),
                      ),
                      onChanged: (v) {
                        final r = int.tryParse(v) ?? widget.set.reps;
                        final w = double.tryParse(
                                _weightCtrl.text) ??
                            widget.set.weight;
                        widget.onUpdate(w, r);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Check
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: widget.compact ? 28 : 32,
              height: widget.compact ? 28 : 32,
              decoration: BoxDecoration(
                color: completed
                    ? _teal
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: completed
                      ? _teal
                      : Colors.white.withOpacity(0.2),
                  width: 1.2,
                ),
                boxShadow: completed
                    ? [
                        BoxShadow(
                            color: _teal.withOpacity(0.4),
                            blurRadius: 8)
                      ]
                    : null,
              ),
              child: Icon(
                Icons.check_rounded,
                color: completed
                    ? Colors.white
                    : Colors.white.withOpacity(0.2),
                size: widget.compact ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SmallBtn
// ─────────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallBtn(
      {required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: color.withOpacity(0.25), width: 0.8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _NoteChip
// ─────────────────────────────────────────────────────────────

class _NoteChip extends StatelessWidget {
  final String note;
  final Future<void> Function(String) onSave;

  const _NoteChip({required this.note, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final hasNote = note.isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final ctrl = TextEditingController(text: note);
        await showKeyboardSafeSheet(
          context,
          GlassSheetWrapper(
            title: 'Nota esercizio',
            accentColor: _cyan,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassTextField(
                  controller: ctrl,
                  hintText: 'Aggiungi una nota...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                GlassPrimaryButton(
                  label: 'Salva nota',
                  color: _teal,
                  onTap: () async {
                    await onSave(ctrl.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasNote
              ? _cyan.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasNote
                ? _cyan.withOpacity(0.35)
                : Colors.white.withOpacity(0.1),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasNote
                  ? Icons.sticky_note_2_rounded
                  : Icons.add_comment_rounded,
              size: 12,
              color: hasNote
                  ? _cyan.withOpacity(0.7)
                  : Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 4),
            Text(
              hasNote ? 'Nota' : 'Aggiungi nota',
              style: TextStyle(
                  color: hasNote
                      ? _cyan.withOpacity(0.7)
                      : Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddToSessionSheet — menu Glass aggiungi esercizio/circuito
// ─────────────────────────────────────────────────────────────

class _AddToSessionSheet extends StatelessWidget {
  final VoidCallback onAddExercise;
  final VoidCallback onAddCircuit;

  const _AddToSessionSheet({
    required this.onAddExercise,
    required this.onAddCircuit,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title: 'Aggiungi alla sessione',
      accentColor: _teal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SessionMenuOption(
            icon: Icons.fitness_center_rounded,
            label: 'Aggiungi esercizio',
            subtitle: 'Inserisci un esercizio singolo',
            color: _teal,
            onTap: onAddExercise,
          ),
          const SizedBox(height: 10),
          _SessionMenuOption(
            icon: Icons.loop_rounded,
            label: 'Aggiungi circuito',
            subtitle: 'Crea un gruppo di esercizi in serie',
            color: _indigo,
            onTap: onAddCircuit,
          ),
        ],
      ),
    );
  }
}

class _SessionMenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SessionMenuOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: color,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: color.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddExerciseToSessionSheet
// ─────────────────────────────────────────────────────────────

class _AddExerciseToSessionSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final Set<dynamic> alreadyIn;
  final void Function(Set<dynamic> keys) onConfirm;

  const _AddExerciseToSessionSheet({
    required this.allExercises,
    required this.alreadyIn,
    required this.onConfirm,
  });

  @override
  State<_AddExerciseToSessionSheet> createState() =>
      _AddExerciseToSessionSheetState();
}

class _AddExerciseToSessionSheetState
    extends State<_AddExerciseToSessionSheet> {
  String _search = '';
  String _muscle = 'Tutti';
  final Set<dynamic> _selected = {};

  static const _groups = [
    'Tutti', 'Petto', 'Schiena', 'Spalle', 'Bicipiti',
    'Tricipiti', 'Gambe', 'Addominali', 'Glutei', 'Polpacci',
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(
                  _search.toLowerCase()));
    }).toList();

    return GlassSheetWrapper(
      title: 'Aggiungi esercizio',
      subtitle: _selected.isEmpty
          ? null
          : '${_selected.length} selezionati',
      accentColor: _teal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _groups.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final g = _groups[i];
                final sel = _muscle == g;
                return GestureDetector(
                  onTap: () => setState(() => _muscle = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _teal.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? _teal.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                        width: sel ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(g,
                        style: TextStyle(
                            color: sel
                                ? _teal
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isIn = widget.alreadyIn.contains(ex.key);
                final isSel = _selected.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: isIn
                      ? Icon(Icons.check_circle,
                          color: _teal.withOpacity(0.5),
                          size: 20)
                      : AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 150),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isSel
                                ? _teal
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                              color: isSel
                                  ? _teal
                                  : Colors.white
                                      .withOpacity(0.25),
                              width: 1.2,
                            ),
                          ),
                          child: isSel
                              ? const Icon(Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white)
                              : null,
                        ),
                  title: Text(ex.name,
                      style: TextStyle(
                          color: isIn
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(ex.muscleGroup,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                  enabled: !isIn,
                  onTap: isIn
                      ? null
                      : () => setState(() {
                            if (isSel)
                              _selected.remove(ex.key);
                            else
                              _selected.add(ex.key);
                          }),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            GlassPrimaryButton(
              label: 'Aggiungi ${_selected.length} esercizi',
              color: _teal,
              onTap: () => widget.onConfirm(_selected),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddCircuitToSessionSheet
// ─────────────────────────────────────────────────────────────

class _AddCircuitToSessionSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final void Function(Set<dynamic> keys, int rounds, String name)
      onConfirm;

  const _AddCircuitToSessionSheet({
    required this.allExercises,
    required this.onConfirm,
  });

  @override
  State<_AddCircuitToSessionSheet> createState() =>
      _AddCircuitToSessionSheetState();
}

class _AddCircuitToSessionSheetState
    extends State<_AddCircuitToSessionSheet> {
  String _search = '';
  String _muscle = 'Tutti';
  final Set<dynamic> _selected = {};
  int _rounds = 3;
  final _nameCtrl = TextEditingController(text: 'Circuito');

  static const _groups = [
    'Tutti', 'Petto', 'Schiena', 'Spalle', 'Bicipiti',
    'Tricipiti', 'Gambe', 'Addominali', 'Glutei', 'Polpacci',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(
                  _search.toLowerCase()));
    }).toList();

    return GlassSheetWrapper(
      title: 'Nuovo circuito',
      accentColor: _indigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: _nameCtrl,
            hintText: 'Nome circuito...',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          // Selettore cicli
          Row(
            children: [
              Text('Cicli:',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _rounds > 1
                    ? () => setState(() => _rounds--)
                    : null,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _rounds > 1
                        ? _cyan.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _rounds > 1
                          ? _cyan.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.remove_rounded,
                      size: 16,
                      color: _rounds > 1
                          ? _cyan
                          : Colors.white.withOpacity(0.2)),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('$_rounds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () => setState(() => _rounds++),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _cyan.withOpacity(0.4), width: 1),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 16, color: _cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassTextField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _groups.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final g = _groups[i];
                final sel = _muscle == g;
                return GestureDetector(
                  onTap: () => setState(() => _muscle = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _indigo.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? _indigo.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                        width: sel ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(g,
                        style: TextStyle(
                            color: sel
                                ? _indigo
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isSel = _selected.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: isSel
                          ? _indigo
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSel
                            ? _indigo
                            : Colors.white.withOpacity(0.25),
                        width: 1.2,
                      ),
                    ),
                    child: isSel
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  title: Text(ex.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(ex.muscleGroup,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                  onTap: () => setState(() {
                    if (isSel)
                      _selected.remove(ex.key);
                    else
                      _selected.add(ex.key);
                  }),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            GlassPrimaryButton(
              label:
                  'Crea · ${_selected.length} esercizi · $_rounds cicli',
              color: _indigo,
              onTap: () => widget.onConfirm(
                _selected,
                _rounds,
                _nameCtrl.text.trim().isNotEmpty
                    ? _nameCtrl.text.trim()
                    : 'Circuito',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _ModifyCircuitInSessionSheet
// Modifica circuito in sessione — NON modifica Hive
// ─────────────────────────────────────────────────────────────

class _ModifyCircuitInSessionSheet extends StatefulWidget {
  final String circuitId;
  final String circuitName;
  final List<HiveExercise> allExercises;
  final List<SessionExercise> currentExercises;
  final int currentRounds;
  final void Function(dynamic exKey) onAddExercise;
  final void Function(dynamic exKey) onRemoveExercise;
  final void Function(int rounds) onChangeRounds;

  const _ModifyCircuitInSessionSheet({
    required this.circuitId,
    required this.circuitName,
    required this.allExercises,
    required this.currentExercises,
    required this.currentRounds,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onChangeRounds,
  });

  @override
  State<_ModifyCircuitInSessionSheet> createState() =>
      _ModifyCircuitInSessionSheetState();
}

class _ModifyCircuitInSessionSheetState
    extends State<_ModifyCircuitInSessionSheet> {
  String _search = '';
  late int _rounds;

  @override
  void initState() {
    super.initState();
    _rounds = widget.currentRounds;
  }

  @override
  Widget build(BuildContext context) {
    final currentKeys =
        widget.currentExercises.map((e) => e.exerciseKey).toSet();
    final available = widget.allExercises.where((e) {
      return _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return GlassSheetWrapper(
      title: 'Modifica circuito',
      subtitle: widget.circuitName,
      accentColor: _indigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cicli
          Row(
            children: [
              Text('Cicli:',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _rounds > 1
                    ? () {
                        setState(() => _rounds--);
                        widget.onChangeRounds(_rounds);
                      }
                    : null,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _rounds > 1
                        ? _cyan.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _rounds > 1
                          ? _cyan.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.remove_rounded,
                      size: 16,
                      color: _rounds > 1
                          ? _cyan
                          : Colors.white.withOpacity(0.2)),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('$_rounds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _rounds++);
                  widget.onChangeRounds(_rounds);
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _cyan.withOpacity(0.4), width: 1),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 16, color: _cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassTextField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: available.length,
              itemBuilder: (_, i) {
                final ex = available[i];
                final isIn = currentKeys.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: GestureDetector(
                    onTap: () {
                      if (isIn) {
                        widget.onRemoveExercise(ex.key);
                      } else {
                        widget.onAddExercise(ex.key);
                      }
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: isIn ? _teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isIn
                              ? _teal
                              : Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: isIn
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  title: Text(ex.name,
                      style: TextStyle(
                          color: isIn
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(ex.muscleGroup,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                  onTap: () {
                    if (isIn) {
                      widget.onRemoveExercise(ex.key);
                    } else {
                      widget.onAddExercise(ex.key);
                    }
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          GlassPrimaryButton(
            label: 'Chiudi',
            color: _indigo,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}