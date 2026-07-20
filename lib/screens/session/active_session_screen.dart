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
// _TopItem
// ─────────────────────────────────────────────────────────────

class _TopItem {
  final bool isFree;
  final SessionExercise? exercise;
  final String? circuitId;
  final List<SessionExercise>? circuitExercises;

  _TopItem.free(SessionExercise ex)
      : isFree = true, exercise = ex,
        circuitId = null, circuitExercises = null;

  _TopItem.circuit(String cid, List<SessionExercise> exs)
      : isFree = false, exercise = null,
        circuitId = cid, circuitExercises = exs;

  String get key =>
      isFree ? 'free_${exercise!.exerciseKey}' : 'circ_$circuitId';
}

List<_TopItem> _buildTopItems(List<SessionExercise> ses) {
  final items = <_TopItem>[];
  final seen = <String>{};
  for (final ex in ses) {
    if (ex.circuitId == null) {
      items.add(_TopItem.free(ex));
    } else {
      final cid = ex.circuitId!;
      if (seen.add(cid)) {
        items.add(_TopItem.circuit(
            cid, ses.where((e) => e.circuitId == cid).toList()));
      }
    }
  }
  return items;
}

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
        const Duration(seconds: 1),
        (_) { if (mounted) setState(() {}); });
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
      exercises, widget.workout.key,
      widget.workout.name, widget.workout,
      circuits: circuits,
    );
  }

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

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
          boxShadow: [BoxShadow(
              color: _orange.withOpacity(0.2), blurRadius: 12)],
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
          boxShadow: [BoxShadow(
              color: _teal.withOpacity(0.2), blurRadius: 12)],
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
        final exList = <({
          dynamic exerciseKey,
          String exerciseName,
          String muscleGroup,
        })>[];
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
      onRemoveExercise: (exKey) =>
          sp.removeExerciseFromCircuitInSession(
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

                final topItems = _buildTopItems(sp.sessionExercises);

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
                          onStop: sp.stopRestTimer),
                    Expanded(
                      child: topItems.isEmpty
                          ? Center(
                              child: Text('Nessun esercizio',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 14)))
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 120),
                              physics: const BouncingScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, i, anim) =>
                                  AnimatedBuilder(
                                animation: anim,
                                builder: (_, __) => Material(
                                  elevation: 0,
                                  color: Colors.transparent,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      border: Border.all(
                                          color: _cyan.withOpacity(0.4),
                                          width: 1.2),
                                      boxShadow: [
                                        BoxShadow(
                                            color: _cyan.withOpacity(0.1),
                                            blurRadius: 12)
                                      ],
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                final reordered =
                                    List<_TopItem>.from(topItems);
                                final moved = reordered.removeAt(oldIndex);
                                reordered.insert(newIndex, moved);
                                final newFlat = <SessionExercise>[];
                                for (final item in reordered) {
                                  if (item.isFree) {
                                    newFlat.add(item.exercise!);
                                  } else {
                                    newFlat.addAll(sp.sessionExercises
                                        .where((e) =>
                                            e.circuitId ==
                                            item.circuitId));
                                  }
                                }
                                sp.reorderSessionExercisesFlat(newFlat);
                                HapticFeedback.selectionClick();
                              },
                              itemCount: topItems.length,
                              itemBuilder: (ctx, i) {
                                final item = topItems[i];
                                if (item.isFree) {
                                  final ex = item.exercise!;
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey(item.key),
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12),
                                      child: _SessionExerciseCard(
                                        exercise: ex,
                                        sets: sp.exerciseSets[
                                                ex.exerciseKey] ??
                                            [],
                                        isRestingHere: sp.isResting &&
                                            sp.restingExerciseId ==
                                                ex.exerciseKey,
                                        onToggle: (idx) => sp.toggleSet(
                                            ex.exerciseKey, idx),
                                        onUpdate: (idx, w, r) =>
                                            sp.updateSet(
                                                ex.exerciseKey, idx, w,
                                                r),
                                        onAddSet: () =>
                                            sp.addSetToExercise(
                                                ex.exerciseKey),
                                        onRemoveSet: () =>
                                            sp.removeSetFromExercise(
                                                ex.exerciseKey),
                                        onRemove: () =>
                                            sp.removeExerciseFromSession(
                                                ex.exerciseKey),
                                        onUpdateNote: (note) =>
                                            sp.updateExerciseNote(
                                                ex.exerciseKey, note),
                                        currentNote:
                                            ex.sessionNote ?? '',
                                      ),
                                    ),
                                  );
                                } else {
                                  final cid = item.circuitId!;
                                  final circExs =
                                      item.circuitExercises!;
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey(item.key),
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12),
                                      child: _SessionCircuitCard(
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
                                        onGoToRound: (round) =>
                                            sp.goToRound(cid, round),
                                        onNextRound: () =>
                                            sp.nextRound(cid),
                                        onPrevRound: () =>
                                            sp.prevRound(cid),
                                        onToggle: (exKey, idx) =>
                                            sp.toggleSet(exKey, idx,
                                                circuitId: cid),
                                        onUpdate: (exKey, idx, w, r) =>
                                            sp.updateSet(exKey, idx, w,
                                                r,
                                                circuitId: cid),
                                        onAddSet: (exKey) =>
                                            sp.addSetToExercise(exKey,
                                                circuitId: cid),
                                        onRemoveSet: (exKey) =>
                                            sp.removeSetFromExercise(exKey,
                                                circuitId: cid),
                                        onRemoveExercise: (exKey) =>
                                            sp.removeExerciseFromCircuitInSession(
                                                circuitId: cid,
                                                exerciseKey: exKey),
                                        onRemoveCircuit: () =>
                                            sp.removeCircuitFromSession(cid),
                                        onModify: () =>
                                            _showModifyCircuitSheet(cid),
                                        onReorderExercises: (reordered) =>
                                            sp.reorderCircuitExercises(
                                                cid, reordered),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                    ),
                    _SessionActionsBar(
                        onAdd: _showAddMenu,
                        onFinish: _finishSession),
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
  final int elapsed, completed, total;
  final String Function(int) formatTime;
  final VoidCallback onBack;
  const _SessionHeader({required this.workoutName, required this.elapsed, required this.completed, required this.total, required this.formatTime, required this.onBack});

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
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cyan.withOpacity(0.2), width: 0.8),
            ),
            child: Column(children: [
              Row(children: [
                GestureDetector(onTap: onBack, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.12))), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(workoutName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)), const SizedBox(width: 5), Text('Sessione in corso', style: TextStyle(color: _green.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600))]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _teal.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.timer_rounded, color: _teal, size: 13), const SizedBox(width: 5), Text(formatTime(elapsed), style: const TextStyle(color: _teal, fontSize: 14, fontWeight: FontWeight.w800))]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('$completed/$total serie', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                const Spacer(),
                Text('${total > 0 ? (progress * 100).round() : 0}%', style: TextStyle(color: _teal.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.08), valueColor: const AlwaysStoppedAnimation<Color>(_teal), minHeight: 4)),
            ]),
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
  final int elapsed; final VoidCallback onStop;
  const _RestTimerBanner({required this.elapsed, required this.onStop});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_indigo.withOpacity(0.2), _indigo.withOpacity(0.08)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: _indigo.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: _indigo.withOpacity(0.15), blurRadius: 12)]),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: _indigo.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.timer_rounded, color: _indigo, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recupero in corso', style: TextStyle(color: _indigo.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            Text('${elapsed}s', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
          GestureDetector(onTap: onStop, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: _indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(9), border: Border.all(color: _indigo.withOpacity(0.4))), child: const Text('Stop', style: TextStyle(color: _indigo, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
      ))),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionActionsBar
// ─────────────────────────────────────────────────────────────

class _SessionActionsBar extends StatelessWidget {
  final VoidCallback onAdd, onFinish;
  const _SessionActionsBar({required this.onAdd, required this.onFinish});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onAdd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.15), width: 1)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                    const SizedBox(width: 6),
                    Text('Aggiungi', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onFinish,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_teal, Color.lerp(_teal, Colors.black, 0.2) ?? _teal]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 3))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Termina', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
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
  final void Function(int) onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback onAddSet, onRemoveSet, onRemove;
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

class _SessionExerciseCardState extends State<_SessionExerciseCard> {
  bool _expanded = false;

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
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.isRestingHere ? _indigo.withOpacity(0.5) : _cyan.withOpacity(0.15), width: widget.isRestingHere ? 1.2 : 0.8),
            boxShadow: widget.isRestingHere ? [BoxShadow(color: _indigo.withOpacity(0.12), blurRadius: 16)] : null,
          ),
          child: Column(children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Icon(Icons.drag_handle_rounded, size: 18, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 10),
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: _teal.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _teal.withOpacity(0.2))), child: const Icon(Icons.fitness_center_rounded, color: _teal, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.exercise.exerciseName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$completedCount/$totalCount serie', style: TextStyle(color: completedCount == totalCount && totalCount > 0 ? _teal : Colors.white.withOpacity(0.4), fontSize: 11)),
                  ])),
                  // Conferma eliminazione esercizio
                  GestureDetector(
                    onTap: () async {
                      final ok = await showGlassDialog<bool>(
                        context: context,
                        accentColor: _red,
                        title: 'Elimina esercizio',
                        message: 'Vuoi eliminare questo esercizio dalla sessione?',
                        actions: [
                          GlassDialogAction(label: 'Annulla', onTap: () => Navigator.pop(context, false)),
                          GlassDialogAction(label: 'Elimina', isDestructive: true, onTap: () => Navigator.pop(context, true)),
                        ],
                      );
                      if (ok == true && context.mounted) widget.onRemove();
                    },
                    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: _red.withOpacity(0.08), borderRadius: BorderRadius.circular(7)), child: Icon(Icons.delete_outline_rounded, size: 13, color: _red.withOpacity(0.7))),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.35), size: 18),
                ]),
              ),
            ),
            if (_expanded) ...[
              Container(height: 0.6, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white.withOpacity(0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(children: widget.sets.asMap().entries.map((e) => _SetRow(index: e.key, set: e.value, onToggle: () => widget.onToggle(e.key), onUpdate: (w, r) => widget.onUpdate(e.key, w, r))).toList()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(children: [
                  _SmallBtn(icon: Icons.remove_rounded, color: Colors.white.withOpacity(0.35), onTap: widget.onRemoveSet),
                  const SizedBox(width: 8),
                  _SmallBtn(icon: Icons.add_rounded, color: _teal, onTap: widget.onAddSet),
                  const Spacer(),
                  _NoteChip(note: widget.currentNote, onSave: widget.onUpdateNote),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionCircuitCard
//
// FIX SPAZIO ECCESSIVO (sezione 8 prompt):
//   Rimosso PageView con altezza fissa.
//   Sostituito con AnimatedSwitcher + _CircuitRoundContent
//   che usa shrinkWrap:true e NeverScrollableScrollPhysics().
//   Il bordo ora si adatta esattamente al contenuto reale.
// ─────────────────────────────────────────────────────────────

class _SessionCircuitCard extends StatefulWidget {
  final String circuitId;
  final String circuitName;
  final List<SessionExercise> exercises;
  final int currentRound;
  final int totalRounds;
  final List<ActiveSet> Function(dynamic exKey) getSets;
  final void Function(int round) onGoToRound;
  final VoidCallback onNextRound, onPrevRound;
  final void Function(dynamic exKey, int index) onToggle;
  final void Function(dynamic exKey, int index, double weight, int reps) onUpdate;
  final void Function(dynamic exKey) onAddSet, onRemoveSet;
  final void Function(dynamic exKey) onRemoveExercise;
  final VoidCallback onModify;
  final VoidCallback onRemoveCircuit;
  final void Function(List<SessionExercise>) onReorderExercises;

  const _SessionCircuitCard({
    super.key,
    required this.circuitId,
    required this.circuitName,
    required this.exercises,
    required this.currentRound,
    required this.totalRounds,
    required this.getSets,
    required this.onGoToRound,
    required this.onNextRound,
    required this.onPrevRound,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onModify,
    required this.onRemoveCircuit,
    required this.onReorderExercises,
  });

  @override
  State<_SessionCircuitCard> createState() => _SessionCircuitCardState();
}

class _SessionCircuitCardState extends State<_SessionCircuitCard> {
  // FIX: PageController rimosso — non più necessario senza PageView
  bool _expanded = false;

  int get _completedCount {
    int n = 0;
    for (final ex in widget.exercises) {
      n += widget.getSets(ex.exerciseKey).where((s) => s.completed).length;
    }
    return n;
  }

  int get _totalCount {
    int n = 0;
    for (final ex in widget.exercises) {
      n += widget.getSets(ex.exerciseKey).length;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_indigo.withOpacity(0.12), _indigo.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _indigo.withOpacity(0.4), width: 1),
            boxShadow: [BoxShadow(color: _indigo.withOpacity(0.1), blurRadius: 16)],
          ),
          child: Column(children: [
            // Header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Icon(Icons.drag_handle_rounded, size: 18, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.loop_rounded, color: _indigo, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.circuitName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$_completedCount/$_totalCount serie', style: TextStyle(color: _indigo.withOpacity(0.8), fontSize: 11)),
                  ])),
                  GestureDetector(onTap: widget.onModify, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: _indigo.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: _indigo.withOpacity(0.3))), child: const Text('Modifica', style: TextStyle(color: _indigo, fontSize: 11, fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 6),
                  // Conferma eliminazione circuito
                  GestureDetector(
                    onTap: () async {
                      final ok = await showGlassDialog<bool>(
                        context: context,
                        accentColor: _red,
                        title: 'Elimina circuito',
                        message: 'Vuoi eliminare definitivamente questo circuito dalla sessione?',
                        actions: [
                          GlassDialogAction(label: 'Annulla', onTap: () => Navigator.pop(context, false)),
                          GlassDialogAction(label: 'Elimina', isDestructive: true, onTap: () => Navigator.pop(context, true)),
                        ],
                      );
                      if (ok == true && context.mounted) widget.onRemoveCircuit();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _red.withOpacity(0.3))),
                      child: const Text('Elimina', style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.35), size: 18),
                ]),
              ),
            ),
            if (_expanded) ...[
              Container(height: 0.7, margin: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, _indigo.withOpacity(0.3), Colors.transparent]))),
              const SizedBox(height: 10),
              // Navigazione round — frecce + puntini
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: _indigo.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _indigo.withOpacity(0.2))),
                      child: Row(children: [
                        GestureDetector(
                          // FIX: rimosso _pageController.animateToPage
                          onTap: widget.currentRound > 0 ? widget.onPrevRound : null,
                          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: widget.currentRound > 0 ? _indigo.withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle), child: Icon(Icons.chevron_left_rounded, color: widget.currentRound > 0 ? _indigo : Colors.white.withOpacity(0.2), size: 20)),
                        ),
                        Expanded(
                          child: Column(children: [
                            Text('Ciclo ${widget.currentRound + 1} di ${widget.totalRounds}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            if (widget.totalRounds > 1) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(widget.totalRounds, (i) {
                                  final active = i == widget.currentRound;
                                  return GestureDetector(
                                    // FIX: rimosso _pageController.animateToPage
                                    onTap: () => widget.onGoToRound(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: active ? 16 : 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: active ? _indigo : Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: active ? [BoxShadow(color: _indigo.withOpacity(0.5), blurRadius: 4)] : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ]),
                        ),
                        GestureDetector(
                          // FIX: rimosso _pageController.animateToPage
                          onTap: widget.currentRound < widget.totalRounds - 1 ? widget.onNextRound : null,
                          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: widget.currentRound < widget.totalRounds - 1 ? _indigo.withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle), child: Icon(Icons.chevron_right_rounded, color: widget.currentRound < widget.totalRounds - 1 ? _indigo : Colors.white.withOpacity(0.2), size: 20)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // FIX SPAZIO ECCESSIVO:
              // AnimatedSwitcher sostituisce PageView con altezza fissa.
              // _CircuitRoundContent usa shrinkWrap:true →
              // il bordo del circuito si adatta esattamente al contenuto.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Padding(
                  key: ValueKey('${widget.circuitId}_r${widget.currentRound}'),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: widget.exercises.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text('Nessun esercizio',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic)))
                      : _CircuitRoundContent(
                          circuitId: widget.circuitId,
                          exercises: widget.exercises,
                          roundIndex: widget.currentRound,
                          getSets: widget.getSets,
                          onToggle: widget.onToggle,
                          onUpdate: widget.onUpdate,
                          onAddSet: widget.onAddSet,
                          onRemoveSet: widget.onRemoveSet,
                          onRemoveExercise: widget.onRemoveExercise,
                          onReorderExercises: widget.onReorderExercises,
                        ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitRoundContent
// shrinkWrap:true + NeverScrollableScrollPhysics() → altezza naturale
// ─────────────────────────────────────────────────────────────

class _CircuitRoundContent extends StatelessWidget {
  final String circuitId;
  final List<SessionExercise> exercises;
  final int roundIndex;
  final List<ActiveSet> Function(dynamic exKey) getSets;
  final void Function(dynamic exKey, int index) onToggle;
  final void Function(dynamic exKey, int index, double weight, int reps) onUpdate;
  final void Function(dynamic exKey) onAddSet, onRemoveSet;
  final void Function(dynamic exKey) onRemoveExercise;
  final void Function(List<SessionExercise>) onReorderExercises;

  const _CircuitRoundContent({
    required this.circuitId,
    required this.exercises,
    required this.roundIndex,
    required this.getSets,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onReorderExercises,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Material(
          elevation: 0, color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cyan.withOpacity(0.5), width: 1.2),
              boxShadow: [BoxShadow(color: _cyan.withOpacity(0.12), blurRadius: 10)],
            ),
            child: child,
          ),
        ),
      ),
      onReorder: (oldIdx, newIdx) {
        if (newIdx > oldIdx) newIdx--;
        final r = List<SessionExercise>.from(exercises);
        final item = r.removeAt(oldIdx);
        r.insert(newIdx, item);
        onReorderExercises(r);
      },
      children: exercises.asMap().entries.map((e) {
        final ex = e.value;
        final sets = getSets(ex.exerciseKey);
        return ReorderableDelayedDragStartListener(
          key: ValueKey('${ex.exerciseKey}_r$roundIndex'),
          index: e.key,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CircuitExerciseBlock(
              exercise: ex,
              sets: sets,
              onToggle: (i) => onToggle(ex.exerciseKey, i),
              onUpdate: (i, w, r) => onUpdate(ex.exerciseKey, i, w, r),
              onAddSet: () => onAddSet(ex.exerciseKey),
              onRemoveSet: () => onRemoveSet(ex.exerciseKey),
              onRemove: () => onRemoveExercise(ex.exerciseKey),
            ),
          ),
        );
      }).toList(),
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
  final VoidCallback onAddSet, onRemoveSet, onRemove;

  const _CircuitExerciseBlock({
    required this.exercise, required this.sets,
    required this.onToggle, required this.onUpdate,
    required this.onAddSet, required this.onRemoveSet,
    required this.onRemove,
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
            border: Border.all(color: _indigo.withOpacity(0.15), width: 0.7),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.drag_handle_rounded, size: 16, color: Colors.white.withOpacity(0.25)),
              const SizedBox(width: 6),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: _indigo, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(exercise.exerciseName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              // Conferma eliminazione esercizio nel circuito
              GestureDetector(
                onTap: () async {
                  final ok = await showGlassDialog<bool>(
                    context: context,
                    accentColor: _red,
                    title: 'Elimina esercizio',
                    message: 'Vuoi eliminare questo esercizio dalla sessione?',
                    actions: [
                      GlassDialogAction(label: 'Annulla', onTap: () => Navigator.pop(context, false)),
                      GlassDialogAction(label: 'Elimina', isDestructive: true, onTap: () => Navigator.pop(context, true)),
                    ],
                  );
                  if (ok == true && context.mounted) onRemove();
                },
                child: Container(width: 24, height: 24, decoration: BoxDecoration(color: _red.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.delete_outline_rounded, size: 12, color: _red.withOpacity(0.7))),
              ),
            ]),
            const SizedBox(height: 8),
            ...sets.asMap().entries.map((e) => _SetRow(index: e.key, set: e.value, onToggle: () => onToggle(e.key), onUpdate: (w, r) => onUpdate(e.key, w, r), compact: true)),
            const SizedBox(height: 4),
            Row(children: [
              _SmallBtn(icon: Icons.remove_rounded, color: Colors.white.withOpacity(0.35), onTap: onRemoveSet),
              const SizedBox(width: 6),
              _SmallBtn(icon: Icons.add_rounded, color: _indigo, onTap: onAddSet),
            ]),
          ]),
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
    required this.index, required this.set,
    required this.onToggle, required this.onUpdate,
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
        text: widget.set.weight > 0 ? widget.set.weight.toString() : '');
    _repsCtrl = TextEditingController(text: widget.set.reps.toString());
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
      _weightCtrl.text =
          widget.set.weight > 0 ? widget.set.weight.toString() : '';
    }
    if (old.set.reps != widget.set.reps) {
      _repsCtrl.text = widget.set.reps.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.set.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 24, child: Text('${widget.index + 1}', style: TextStyle(color: (completed ? _teal : Colors.white).withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(
          child: Container(
            height: widget.compact ? 30 : 34,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: completed ? _teal.withOpacity(0.3) : Colors.white.withOpacity(0.1), width: 0.8)),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(hintText: widget.set.lastWeight != null ? '${widget.set.lastWeight}' : 'kg', hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6)),
                onChanged: (v) { final w = double.tryParse(v) ?? 0; final r = int.tryParse(_repsCtrl.text) ?? widget.set.reps; widget.onUpdate(w, r); },
              )),
              Text('kg', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
              const SizedBox(width: 4),
            ]),
          ),
        ),
        SizedBox(
          width: widget.compact ? 52 : 60,
          height: widget.compact ? 30 : 34,
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: completed ? _teal.withOpacity(0.3) : Colors.white.withOpacity(0.1), width: 0.8)),
            child: TextField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(hintText: widget.set.lastReps != null ? '${widget.set.lastReps}' : 'rip', hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 4)),
              onChanged: (v) { final r = int.tryParse(v) ?? widget.set.reps; final w = double.tryParse(_weightCtrl.text) ?? widget.set.weight; widget.onUpdate(w, r); },
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); widget.onToggle(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.compact ? 28 : 32,
            height: widget.compact ? 28 : 32,
            decoration: BoxDecoration(
              color: completed ? _teal : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: completed ? _teal : Colors.white.withOpacity(0.2), width: 1.2),
              boxShadow: completed ? [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 8)] : null,
            ),
            child: Icon(Icons.check_rounded, color: completed ? Colors.white : Colors.white.withOpacity(0.2), size: widget.compact ? 14 : 16),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SmallBtn / _NoteChip
// ─────────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.25), width: 0.8)), child: Icon(icon, size: 14, color: color)));
}

class _NoteChip extends StatelessWidget {
  final String note; final Future<void> Function(String) onSave;
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GlassTextField(controller: ctrl, hintText: 'Aggiungi una nota...', maxLines: 3),
              const SizedBox(height: 16),
              GlassPrimaryButton(label: 'Salva nota', color: _teal, onTap: () async { await onSave(ctrl.text.trim()); if (context.mounted) Navigator.pop(context); }),
            ]),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasNote ? _cyan.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasNote ? _cyan.withOpacity(0.35) : Colors.white.withOpacity(0.1), width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(hasNote ? Icons.sticky_note_2_rounded : Icons.add_comment_rounded, size: 12, color: hasNote ? _cyan.withOpacity(0.7) : Colors.white.withOpacity(0.3)),
          const SizedBox(width: 4),
          Text(hasNote ? 'Nota' : 'Aggiungi nota', style: TextStyle(color: hasNote ? _cyan.withOpacity(0.7) : Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddToSessionSheet
// ─────────────────────────────────────────────────────────────

class _AddToSessionSheet extends StatelessWidget {
  final VoidCallback onAddExercise, onAddCircuit;
  const _AddToSessionSheet({required this.onAddExercise, required this.onAddCircuit});

  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title: 'Aggiungi alla sessione',
      accentColor: _teal,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SessionMenuOption(icon: Icons.fitness_center_rounded, label: 'Aggiungi esercizio', subtitle: 'Inserisci un esercizio singolo', color: _teal, onTap: onAddExercise),
        const SizedBox(height: 10),
        _SessionMenuOption(icon: Icons.loop_rounded, label: 'Aggiungi circuito', subtitle: 'Crea un gruppo di esercizi in serie', color: _indigo, onTap: onAddCircuit),
      ]),
    );
  }
}

class _SessionMenuOption extends StatelessWidget {
  final IconData icon; final String label, subtitle; final Color color; final VoidCallback onTap;
  const _SessionMenuOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3), width: 1), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)]),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.5)),
        ]),
      ))),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddExerciseToSessionSheet
// ─────────────────────────────────────────────────────────────

class _AddExerciseToSessionSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final Set<dynamic> alreadyIn;
  final void Function(Set<dynamic>) onConfirm;
  const _AddExerciseToSessionSheet({required this.allExercises, required this.alreadyIn, required this.onConfirm});
  @override State<_AddExerciseToSessionSheet> createState() => _AddExerciseToSessionSheetState();
}
class _AddExerciseToSessionSheetState extends State<_AddExerciseToSessionSheet> {
  String _search = ''; String _muscle = 'Tutti'; final Set<dynamic> _selected = {};
  static const _groups = ['Tutti', 'Petto', 'Schiena', 'Spalle', 'Bicipiti', 'Tricipiti', 'Gambe', 'Addominali', 'Glutei', 'Polpacci'];
  @override
  Widget build(BuildContext context) {
    final filtered = widget.allExercises.where((e) => (_muscle == 'Tutti' || e.muscleGroup == _muscle) && (_search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase()))).toList();
    return GlassSheetWrapper(title: 'Aggiungi esercizio', subtitle: _selected.isEmpty ? null : '${_selected.length} selezionati', accentColor: _teal, child: Column(mainAxisSize: MainAxisSize.min, children: [
      GlassTextField(hintText: 'Cerca esercizio...', onChanged: (v) => setState(() => _search = v)),
      const SizedBox(height: 10),
      _ChipRow(groups: _groups, selected: _muscle, color: _teal, onSelect: (g) => setState(() => _muscle = g)),
      const SizedBox(height: 10),
      SizedBox(height: 260, child: ListView.builder(physics: const BouncingScrollPhysics(), itemCount: filtered.length, itemBuilder: (_, i) {
        final ex = filtered[i]; final isIn = widget.alreadyIn.contains(ex.key); final isSel = _selected.contains(ex.key);
        return _ExTile(exercise: ex, isIn: isIn, isSel: isSel, accentColor: _teal, onTap: isIn ? null : () => setState(() { if (isSel) _selected.remove(ex.key); else _selected.add(ex.key); }));
      })),
      if (_selected.isNotEmpty) ...[const SizedBox(height: 10), GlassPrimaryButton(label: 'Aggiungi ${_selected.length} esercizi', color: _teal, onTap: () => widget.onConfirm(_selected))],
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddCircuitToSessionSheet
// ─────────────────────────────────────────────────────────────

class _AddCircuitToSessionSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final void Function(Set<dynamic>, int, String) onConfirm;
  const _AddCircuitToSessionSheet({required this.allExercises, required this.onConfirm});
  @override State<_AddCircuitToSessionSheet> createState() => _AddCircuitToSessionSheetState();
}
class _AddCircuitToSessionSheetState extends State<_AddCircuitToSessionSheet> {
  String _search = ''; String _muscle = 'Tutti'; final Set<dynamic> _selected = {}; int _rounds = 3;
  final _nameCtrl = TextEditingController(text: 'Circuito');
  static const _groups = ['Tutti', 'Petto', 'Schiena', 'Spalle', 'Bicipiti', 'Tricipiti', 'Gambe', 'Addominali', 'Glutei', 'Polpacci'];
  @override void dispose() { _nameCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final filtered = widget.allExercises.where((e) => (_muscle == 'Tutti' || e.muscleGroup == _muscle) && (_search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase()))).toList();
    return GlassSheetWrapper(title: 'Nuovo circuito', accentColor: _indigo, child: Column(mainAxisSize: MainAxisSize.min, children: [
      GlassTextField(controller: _nameCtrl, hintText: 'Nome circuito...', onChanged: (_) {}),
      const SizedBox(height: 12),
      _RoundsRow(rounds: _rounds, onChanged: (v) => setState(() => _rounds = v)),
      const SizedBox(height: 12),
      GlassTextField(hintText: 'Cerca esercizio...', onChanged: (v) => setState(() => _search = v)),
      const SizedBox(height: 10),
      _ChipRow(groups: _groups, selected: _muscle, color: _indigo, onSelect: (g) => setState(() => _muscle = g)),
      const SizedBox(height: 10),
      SizedBox(height: 220, child: ListView.builder(physics: const BouncingScrollPhysics(), itemCount: filtered.length, itemBuilder: (_, i) {
        final ex = filtered[i]; final isSel = _selected.contains(ex.key);
        return _ExTile(exercise: ex, isIn: false, isSel: isSel, accentColor: _indigo, onTap: () => setState(() { if (isSel) _selected.remove(ex.key); else _selected.add(ex.key); }));
      })),
      if (_selected.isNotEmpty) ...[const SizedBox(height: 10), GlassPrimaryButton(label: 'Crea · ${_selected.length} esercizi · $_rounds cicli', color: _indigo, onTap: () => widget.onConfirm(_selected, _rounds, _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Circuito'))],
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _ModifyCircuitInSessionSheet
// ─────────────────────────────────────────────────────────────

class _ModifyCircuitInSessionSheet extends StatefulWidget {
  final String circuitId, circuitName;
  final List<HiveExercise> allExercises;
  final List<SessionExercise> currentExercises;
  final int currentRounds;
  final void Function(dynamic) onAddExercise, onRemoveExercise;
  final void Function(int) onChangeRounds;
  const _ModifyCircuitInSessionSheet({required this.circuitId, required this.circuitName, required this.allExercises, required this.currentExercises, required this.currentRounds, required this.onAddExercise, required this.onRemoveExercise, required this.onChangeRounds});
  @override State<_ModifyCircuitInSessionSheet> createState() => _ModifyCircuitInSessionSheetState();
}
class _ModifyCircuitInSessionSheetState extends State<_ModifyCircuitInSessionSheet> {
  String _search = ''; late int _rounds;
  @override void initState() { super.initState(); _rounds = widget.currentRounds; }
  @override
  Widget build(BuildContext context) {
    final currentKeys = widget.currentExercises.map((e) => e.exerciseKey).toSet();
    final available = widget.allExercises.where((e) => _search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase())).toList();
    return GlassSheetWrapper(title: 'Modifica circuito', subtitle: widget.circuitName, accentColor: _indigo, child: Column(mainAxisSize: MainAxisSize.min, children: [
      _RoundsRow(rounds: _rounds, onChanged: (v) { setState(() => _rounds = v); widget.onChangeRounds(v); }),
      const SizedBox(height: 12),
      GlassTextField(hintText: 'Cerca esercizio...', onChanged: (v) => setState(() => _search = v)),
      const SizedBox(height: 10),
      SizedBox(height: 260, child: ListView.builder(physics: const BouncingScrollPhysics(), itemCount: available.length, itemBuilder: (_, i) {
        final ex = available[i]; final isIn = currentKeys.contains(ex.key);
        return _ExTile(exercise: ex, isIn: false, isSel: isIn, accentColor: _teal, onTap: () { if (isIn) { widget.onRemoveExercise(ex.key); } else { widget.onAddExercise(ex.key); } setState(() {}); });
      })),
      const SizedBox(height: 10),
      GlassPrimaryButton(label: 'Chiudi', color: _indigo, onTap: () => Navigator.pop(context)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// Micro widget condivisi
// ─────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  final List<String> groups; final String selected; final Color color; final void Function(String) onSelect;
  const _ChipRow({required this.groups, required this.selected, required this.color, required this.onSelect});
  @override
  Widget build(BuildContext context) => SizedBox(height: 34, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: groups.length, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) {
    final g = groups[i]; final sel = selected == g;
    return GestureDetector(onTap: () => onSelect(g), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: sel ? color.withOpacity(0.2) : Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(9), border: Border.all(color: sel ? color.withOpacity(0.6) : Colors.white.withOpacity(0.1), width: sel ? 1.2 : 0.8)), child: Text(g, style: TextStyle(color: sel ? color : Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))));
  }));
}

class _RoundsRow extends StatelessWidget {
  final int rounds; final void Function(int) onChanged;
  const _RoundsRow({required this.rounds, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('Cicli:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w600)),
    const Spacer(),
    GestureDetector(onTap: rounds > 1 ? () => onChanged(rounds - 1) : null, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: rounds > 1 ? _cyan.withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: rounds > 1 ? _cyan.withOpacity(0.4) : Colors.white.withOpacity(0.1), width: 1)), child: Icon(Icons.remove_rounded, size: 16, color: rounds > 1 ? _cyan : Colors.white.withOpacity(0.2)))),
    SizedBox(width: 44, child: Text('$rounds', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    GestureDetector(onTap: () => onChanged(rounds + 1), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: _cyan.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: _cyan.withOpacity(0.4), width: 1)), child: const Icon(Icons.add_rounded, size: 16, color: _cyan))),
  ]);
}

class _ExTile extends StatelessWidget {
  final HiveExercise exercise; final bool isIn, isSel; final Color accentColor; final VoidCallback? onTap;
  const _ExTile({required this.exercise, required this.isIn, required this.isSel, required this.accentColor, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 22, height: 22, decoration: BoxDecoration(color: isSel ? accentColor : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSel ? accentColor : Colors.white.withOpacity(0.25), width: 1.2)), child: isSel ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null),
    title: Text(exercise.name, style: TextStyle(color: isIn ? Colors.white.withOpacity(0.35) : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    subtitle: Text(exercise.muscleGroup, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
    onTap: onTap,
  );
}