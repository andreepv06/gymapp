import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _red    = MarkFitColors.red;
const _green  = MarkFitColors.green;

class _TopItem {
  final bool                   isFree;
  final SessionExercise?       exercise;
  final String?                circuitId;
  final List<SessionExercise>? circuitExercises;

  _TopItem.free(SessionExercise ex)
      : isFree = true,
        exercise = ex,
        circuitId = null,
        circuitExercises = null;

  _TopItem.circuit(String cid, List<SessionExercise> exs)
      : isFree = false,
        exercise = null,
        circuitId = cid,
        circuitExercises = exs;

  String get key =>
      isFree ? 'free_${exercise!.exerciseKey}' : 'circ_$circuitId';
}

List<_TopItem> _buildTopItems(List<SessionExercise> ses) {
  final items = <_TopItem>[];
  final seen  = <String>{};
  for (final ex in ses) {
    if (ex.circuitId == null) {
      items.add(_TopItem.free(ex));
    } else {
      final cid = ex.circuitId!;
      if (seen.add(cid)) {
        items.add(_TopItem.circuit(
          cid,
          ses.where((e) => e.circuitId == cid).toList(),
        ));
      }
    }
  }
  return items;
}

class ActiveSessionScreen extends StatefulWidget {
  final HiveWorkout workout;
  const ActiveSessionScreen({super.key, required this.workout});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  Timer?  _uiTimer;
  String? _sessionError;
  bool    _sessionInitialized = false;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() {}); },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSession() async {
    if (!mounted) return;
    setState(() {
      _sessionError       = null;
      _sessionInitialized = false;
    });

    final sp = context.read<SessionProvider>();
    if (sp.hasActiveSession &&
        sp.currentWorkout?.key == widget.workout.key) {
      if (mounted) setState(() => _sessionInitialized = true);
      return;
    }
    if (sp.hasActiveSession) {
      if (mounted) setState(() => _sessionInitialized = true);
      return;
    }

    try {
      final exercises =
          HiveDatabase.instance.getWorkoutExercises(widget.workout.key);
      final circuits  =
          HiveDatabase.instance.getCircuits(widget.workout.key);
      await sp.startSession(
        exercises,
        widget.workout.key,
        widget.workout.name,
        widget.workout,
        circuits: circuits,
      );
    } catch (e) {
      debugPrint('[ActiveSessionScreen._initSession] Error: $e');
      if (mounted) {
        setState(() => _sessionError =
            'Non è stato possibile avviare la sessione. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _sessionInitialized = true);
    }
  }

  String _fmt(int s) {
    final h   = s ~/ 3600;
    final m   = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm  = m.toString().padLeft(2, '0');
    final ss  = sec.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child:   child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    final sp = context.read<SessionProvider>();
    if (_sessionError != null || !sp.hasActiveSession) {
      Navigator.of(context).pop();
      return;
    }
    if (!sp.hasAnyData) {
      final ok = await showGlassDialog<bool>(
        context:     context,
        accentColor: _red,
        title:       'Abbandonare la sessione?',
        message:     'Non hai ancora completato nessuna serie. '
            'La sessione verrà eliminata.',
        actions: [
          GlassDialogAction(
            label: 'Continua',
            onTap: () => Navigator.pop(context, false),
          ),
          GlassDialogAction(
            label:         'Abbandona',
            isDestructive: true,
            onTap:         () => Navigator.pop(context, true),
          ),
        ],
      );
      if (ok == true && mounted) {
        await sp.abandonSession();
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }
    final result = await showGlassDialog<String>(
      context:     context,
      accentColor: _orange,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color:     _orange.withOpacity(0.12),
          shape:     BoxShape.circle,
          border:    Border.all(color: _orange.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _orange.withOpacity(0.2), blurRadius: 12),
          ],
        ),
        child: const Icon(Icons.pause_circle_outline_rounded,
            color: _orange, size: 22),
      ),
      title:   'Sessione in corso',
      message: 'Vuoi mettere in pausa o abbandonare '
          'definitivamente la sessione?',
      actions: [
        GlassDialogAction(
          label: 'Annulla',
          onTap: () => Navigator.pop(context, 'cancel'),
        ),
        GlassDialogAction(
          label: 'Pausa',
          color: _orange,
          onTap: () => Navigator.pop(context, 'pause'),
        ),
        GlassDialogAction(
          label:         'Abbandona',
          isDestructive: true,
          onTap:         () => Navigator.pop(context, 'abandon'),
        ),
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
      context:     context,
      accentColor: _teal,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color:     _teal.withOpacity(0.12),
          shape:     BoxShape.circle,
          border:    Border.all(color: _teal.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 12),
          ],
        ),
        child: const Icon(Icons.check_circle_outline_rounded,
            color: _teal, size: 22),
      ),
      title:   'Termina sessione',
      message: 'Tutte le serie completate verranno salvate '
          'nello storico degli allenamenti.',
      actions: [
        GlassDialogAction(
          label: 'Annulla',
          onTap: () => Navigator.pop(context, false),
        ),
        GlassDialogAction(
          label:     'Termina',
          isDefault: true,
          color:     _teal,
          onTap:     () => Navigator.pop(context, true),
        ),
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
    final sp        = context.read<SessionProvider>();
    final all       = HiveDatabase.instance.getExercises();
    final alreadyIn = sp.sessionExercises
        .where((e) => e.circuitId == null)
        .map((e) => e.exerciseKey)
        .toSet();
    await _openSheet(ExercisePickerSheet(
      allExercises: all,
      disabledKeys: alreadyIn,
      title:        'Aggiungi esercizio',
      accentColor:  _teal,
      confirmLabel: 'Aggiungi',
      onConfirm: (result) async {
        for (final k in result.selectedKeys) {
          try {
            final ex = all.firstWhere((e) => e.key == k);
            await sp.addExerciseToSession(
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
            );
          } catch (_) {}
        }
        if (mounted) Navigator.pop(context);
      },
    ));
  }

  Future<void> _showAddCircuitSheet() async {
    final sp  = context.read<SessionProvider>();
    final all = HiveDatabase.instance.getExercises();
    await _openSheet(ExercisePickerSheet(
      allExercises:      all,
      showNameField:     true,
      initialName:       'Circuito',
      showRoundsControl: true,
      initialRounds:     3,
      title:             'Nuovo circuito',
      accentColor:       _indigo,
      confirmLabel:      'Crea',
      onConfirm: (result) async {
        if (result.selectedKeys.isEmpty) return;
        final exList = <({
          dynamic exerciseKey,
          String exerciseName,
          String muscleGroup,
        })>[];
        for (final k in result.selectedKeys) {
          try {
            final ex = all.firstWhere((e) => e.key == k);
            exList.add((
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
            ));
          } catch (_) {}
        }
        await sp.addCircuitToSession(
          exercises: exList,
          rounds:    result.rounds,
          name:      result.name.isNotEmpty ? result.name : 'Circuito',
        );
        if (mounted) Navigator.pop(context);
      },
    ));
  }

  Future<void> _showModifyCircuitSheet(String circuitId) async {
    final sp               = context.read<SessionProvider>();
    final all              = HiveDatabase.instance.getExercises();
    final currentExercises = List<SessionExercise>.from(
      sp.sessionExercises.where((e) => e.circuitId == circuitId),
    );
    final currentKeys   = currentExercises.map((e) => e.exerciseKey).toSet();
    final currentRounds = sp.getTotalRounds(circuitId);
    await _openSheet(ExercisePickerSheet(
      allExercises:        all,
      initialSelectedKeys: Set<dynamic>.from(currentKeys),
      showRoundsControl:   true,
      initialRounds:       currentRounds,
      title:               'Modifica circuito',
      subtitle:            sp.getCircuitName(circuitId),
      accentColor:         _indigo,
      confirmLabel:        'Salva',
      alwaysShowConfirm:   true,
      onConfirm: (result) {
        final newKeys = result.selectedKeys;
        if (result.rounds != currentRounds) {
          sp.setCircuitRoundsInSession(circuitId, result.rounds);
        }
        for (final key in newKeys.difference(currentKeys)) {
          try {
            final ex = all.firstWhere((e) => e.key == key);
            sp.addExerciseToCircuitInSession(
              circuitId:    circuitId,
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
            );
          } catch (_) {}
        }
        for (final key in currentKeys.difference(newKeys)) {
          sp.removeExerciseFromCircuitInSession(
            circuitId:   circuitId,
            exerciseKey: key,
          );
        }
        if (mounted) Navigator.pop(context);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CosmicBackground(
          subtle: true,
          child: SafeArea(
            child: Consumer<SessionProvider>(
              builder: (context, sp, _) {
                if (_sessionError != null) {
                  return _buildError(c, _sessionError!);
                }
                if (!_sessionInitialized) {
                  return _buildLoading(c);
                }
                if (!sp.hasActiveSession) {
                  return _buildError(
                    c,
                    'Sessione non avviata correttamente. Riprova.',
                  );
                }
                final topItems = _buildTopItems(sp.sessionExercises);
                return Column(
                  children: [
                    _SessionHeader(
                      workoutName: widget.workout.name,
                      elapsed:     sp.elapsedSeconds,
                      completed:   sp.completedSetsCount,
                      total:       sp.totalSetsCount,
                      formatTime:  _fmt,
                      onBack:      _onBack,
                      c:           c,
                    ),
                    if (sp.isResting)
                      _RestTimerBanner(
                        elapsed: sp.restElapsed,
                        onStop:  sp.stopRestTimer,
                        c:       c,
                      ),
                    Expanded(
                      child: topItems.isEmpty
                          ? Center(
                              child: Text(
                                'Nessun esercizio',
                                style: TextStyle(
                                  color:    c.textTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : _buildReorderableList(sp, topItems, c),
                    ),
                    _SessionActionsBar(
                      onAdd:    _showAddMenu,
                      onFinish: _finishSession,
                      c:        c,
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

  Widget _buildReorderableList(
    SessionProvider sp,
    List<_TopItem> topItems,
    MarkFitColors c,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, i, anim) => AnimatedBuilder(
        animation: anim,
        builder: (_, _) => Material(
          elevation: 0,
          color:     Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _cyan.withOpacity(0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(color: _cyan.withOpacity(0.1), blurRadius: 12),
              ],
            ),
            child: child,
          ),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<_TopItem>.from(topItems);
        final moved     = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        final newFlat = <SessionExercise>[];
        for (final item in reordered) {
          if (item.isFree) {
            newFlat.add(item.exercise!);
          } else {
            newFlat.addAll(
              sp.sessionExercises
                  .where((e) => e.circuitId == item.circuitId),
            );
          }
        }
        sp.reorderSessionExercisesFlat(newFlat);
        HapticFeedback.selectionClick();
      },
      itemCount: topItems.length,
      itemBuilder: (ctx, i) {
        final item = topItems[i];
        if (item.isFree) {
          return _buildFreeExerciseItem(sp, item, i);
        } else {
          return _buildCircuitItem(sp, item, i);
        }
      },
    );
  }

  Widget _buildFreeExerciseItem(SessionProvider sp, _TopItem item, int i) {
    final ex = item.exercise!;
    return ReorderableDelayedDragStartListener(
      key:   ValueKey(item.key),
      index: i,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SessionExerciseCard(
          exercise:      ex,
          sets:          sp.exerciseSets[ex.exerciseKey] ?? [],
          isRestingHere: sp.isResting &&
              sp.restingExerciseId == ex.exerciseKey,
          onToggle:     (idx) => sp.toggleSet(ex.exerciseKey, idx),
          onUpdate:     (idx, w, r) =>
              sp.updateSet(ex.exerciseKey, idx, w, r),
          onAddSet:     () => sp.addSetToExercise(ex.exerciseKey),
          onRemoveSet:  () => sp.removeSetFromExercise(ex.exerciseKey),
          onRemove:     () => sp.removeExerciseFromSession(ex.exerciseKey),
          onUpdateNote: (note) =>
              sp.updateExerciseNote(ex.exerciseKey, note),
          currentNote:  ex.sessionNote ?? '',
        ),
      ),
    );
  }

  Widget _buildCircuitItem(SessionProvider sp, _TopItem item, int i) {
    final cid    = item.circuitId!;
    final circEx = item.circuitExercises!;
    return ReorderableDelayedDragStartListener(
      key:   ValueKey(item.key),
      index: i,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SessionCircuitCard(
          circuitId:    cid,
          circuitName:  sp.getCircuitName(cid),
          exercises:    circEx,
          currentRound: sp.getCurrentRound(cid),
          totalRounds:  sp.getTotalRounds(cid),
          getSets:      (exKey) => sp.getCircuitSets(cid, exKey),
          onGoToRound:  (r) => sp.goToRound(cid, r),
          onNextRound:  () => sp.nextRound(cid),
          onPrevRound:  () => sp.prevRound(cid),
          onToggle:     (exKey, idx) =>
              sp.toggleSet(exKey, idx, circuitId: cid),
          onUpdate:     (exKey, idx, w, r) =>
              sp.updateSet(exKey, idx, w, r, circuitId: cid),
          onAddSet:     (exKey) =>
              sp.addSetToExercise(exKey, circuitId: cid),
          onRemoveSet:  (exKey) =>
              sp.removeSetFromExercise(exKey, circuitId: cid),
          onRemoveExercise: (exKey) =>
              sp.removeExerciseFromCircuitInSession(
                circuitId:   cid,
                exerciseKey: exKey,
              ),
          onRemoveCircuit: () => sp.removeCircuitFromSession(cid),
          onModify:        () => _showModifyCircuitSheet(cid),
          onReorderExercises: (reordered) =>
              sp.reorderCircuitExercises(cid, reordered),
        ),
      ),
    );
  }

  Widget _buildLoading(MarkFitColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
                color: _teal, strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text('Avvio sessione...',
              style: TextStyle(color: c.textTertiary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(MarkFitColors c, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: c.glassBlur, sigmaY: c.glassBlur),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:        c.glassCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _red.withOpacity(0.3), width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        color: _red, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Impossibile avviare la sessione',
                    style: TextStyle(
                      color:      c.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    style: TextStyle(
                        color: c.textTertiary, fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _initSession,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_teal, MarkFitColors.tealDk],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [BoxShadow(
                                  color: _teal.withOpacity(0.4),
                                  blurRadius: 10)],
                            ),
                            child: const Text('Riprova',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            decoration: BoxDecoration(
                              color:        c.glassCardInset,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: c.glassBorder, width: 0.8),
                            ),
                            child: Text('Indietro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:      c.textPrimary,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
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

// _SessionHeader, _RestTimerBanner, _SessionActionsBar,
// _SessionExerciseCard, _SessionCircuitCard, _CircuitRoundContent,
// _CircuitExerciseBlock, _SetRow, _SmallBtn: identici alla versione
// precedente — già tutti theme-aware con context.mfc.

class _SessionHeader extends StatelessWidget {
  final String               workoutName;
  final int                  elapsed, completed, total;
  final String Function(int) formatTime;
  final VoidCallback         onBack;
  final MarkFitColors        c;

  const _SessionHeader({
    required this.workoutName, required this.elapsed,
    required this.completed,   required this.total,
    required this.formatTime,  required this.onBack,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        c.glassCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _cyan.withOpacity(0.2), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor,
                      blurRadius: 12, offset: const Offset(0, 2))]
                  : null,
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
                          color:        c.glassCardInset,
                          borderRadius: BorderRadius.circular(10),
                          border:       Border.all(color: c.glassBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: c.iconPrimary, size: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workoutName, style: TextStyle(
                              color:      c.textPrimary,
                              fontSize:   16,
                              fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('Sessione in corso', style: TextStyle(
                                  color:      _green.withOpacity(0.8),
                                  fontSize:   10,
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
                        color:        _teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(
                            color: _teal.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                        const Icon(Icons.timer_rounded,
                            color: _teal, size: 13),
                        const SizedBox(width: 5),
                        Text(formatTime(elapsed),
                            style: const TextStyle(
                                color:      _teal,
                                fontSize:   14,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('$completed/$total serie',
                        style: TextStyle(
                            color: c.textTertiary, fontSize: 11)),
                    const Spacer(),
                    Text(
                        '${total > 0 ? (progress * 100).round() : 0}%',
                        style: TextStyle(
                            color:      _teal.withOpacity(0.8),
                            fontSize:   11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value:           progress,
                    backgroundColor: c.glassCardInset,
                    valueColor: const AlwaysStoppedAnimation<Color>(_teal),
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

class _RestTimerBanner extends StatelessWidget {
  final int          elapsed;
  final VoidCallback onStop;
  final MarkFitColors c;
  const _RestTimerBanner({
      required this.elapsed, required this.onStop, required this.c});

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
              gradient: LinearGradient(colors: [
                _indigo.withOpacity(0.2),
                _indigo.withOpacity(0.08),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _indigo.withOpacity(0.4), width: 1),
              boxShadow: [BoxShadow(
                  color: _indigo.withOpacity(0.15), blurRadius: 12)],
            ),
            child: Row(
              children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_rounded,
                      color: _indigo, size: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recupero in corso', style: TextStyle(
                          color:        _indigo.withOpacity(0.8),
                          fontSize:     10,
                          fontWeight:   FontWeight.w600,
                          letterSpacing: 0.3)),
                      Text('${elapsed}s', style: TextStyle(
                          color:      c.textPrimary,
                          fontSize:   16,
                          fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        _indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _indigo.withOpacity(0.4)),
                    ),
                    child: const Text('Stop', style: TextStyle(
                        color:      _indigo,
                        fontSize:   12,
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

class _SessionActionsBar extends StatelessWidget {
  final VoidCallback  onAdd, onFinish;
  final MarkFitColors c;
  const _SessionActionsBar({
      required this.onAdd, required this.onFinish, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onAdd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:        c.glassCardInset,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: c.glassBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: c.iconPrimary, size: 18),
                        const SizedBox(width: 6),
                        Text('Aggiungi', style: TextStyle(
                            color:      c.textSecondary,
                            fontSize:   14,
                            fontWeight: FontWeight.w600)),
                      ],
                    ),
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
                  gradient: LinearGradient(colors: [
                    _teal,
                    Color.lerp(_teal, Colors.black, 0.2) ?? _teal,
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color:      _teal.withOpacity(0.4),
                      blurRadius: 14,
                      offset:     const Offset(0, 3))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Termina', style: TextStyle(
                        color:      Colors.white,
                        fontSize:   14,
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

class _SessionExerciseCard extends StatefulWidget {
  final SessionExercise                exercise;
  final List<ActiveSet>                sets;
  final bool                           isRestingHere;
  final void Function(int)             onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback                   onAddSet, onRemoveSet, onRemove;
  final Future<void> Function(String)  onUpdateNote;
  final String                         currentNote;

  const _SessionExerciseCard({
    required this.exercise,     required this.sets,
    required this.isRestingHere, required this.onToggle,
    required this.onUpdate,     required this.onAddSet,
    required this.onRemoveSet,  required this.onRemove,
    required this.onUpdateNote, required this.currentNote,
  });

  @override
  State<_SessionExerciseCard> createState() =>
      _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<_SessionExerciseCard> {
  bool _expanded = false;

  // FASE 4 — etichetta struttura attesa (fisso o range) per la
  // serie in posizione [index], se disponibile. Puramente
  // informativa: non condiziona la modificabilità del valore.
  String? _expectedLabelFor(int index) {
    final structure = widget.exercise.expectedStructure;
    if (structure == null || index >= structure.length) return null;
    return structure[index].label;
  }

  @override
  Widget build(BuildContext context) {
    final c              = context.mfc;
    final completedCount = widget.sets.where((s) => s.completed).length;
    final totalCount     = widget.sets.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isRestingHere
                  ? _indigo.withOpacity(0.5) : c.glassBorder,
              width: widget.isRestingHere ? 1.2 : 0.8,
            ),
            boxShadow: widget.isRestingHere
                ? [BoxShadow(color: _indigo.withOpacity(0.12),
                    blurRadius: 16)]
                : c.showElevation
                    ? [BoxShadow(color: c.elevationColor, blurRadius: 6)]
                    : null,
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 18, color: c.iconSecondary),
                      const SizedBox(width: 10),
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color:        _teal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _teal.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.fitness_center_rounded,
                            color: _teal, size: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.exercise.exerciseName,
                                style: TextStyle(
                                    color:      c.textPrimary,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('$completedCount/$totalCount serie',
                                style: TextStyle(
                                  color: completedCount == totalCount &&
                                          totalCount > 0
                                      ? _teal : c.textTertiary,
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final ok = await showGlassDialog<bool>(
                            context:     context,
                            accentColor: _red,
                            title:   'Elimina esercizio',
                            message: 'Vuoi eliminare questo esercizio '
                                'dalla sessione?',
                            actions: [
                              GlassDialogAction(
                                label: 'Annulla',
                                onTap: () =>
                                    Navigator.pop(context, false),
                              ),
                              GlassDialogAction(
                                label:         'Elimina',
                                isDestructive: true,
                                onTap:         () =>
                                    Navigator.pop(context, true),
                              ),
                            ],
                          );
                          if (ok == true && context.mounted) {
                            widget.onRemove();
                          }
                        },
                        child: Container(width: 28, height: 28,
                          decoration: BoxDecoration(
                            color:        _red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 13,
                              color: _red.withOpacity(0.7))),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: c.textTertiary, size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(height: 0, thickness: 0.6,
                    indent: 14, endIndent: 14, color: c.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Column(
                    children: widget.sets.asMap().entries.map((e) =>
                        _SetRow(
                          index:    e.key,
                          set:      e.value,
                          onToggle: () => widget.onToggle(e.key),
                          onUpdate: (w, r) =>
                              widget.onUpdate(e.key, w, r),
                          expectedLabel: _expectedLabelFor(e.key),
                        )).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Row(
                    children: [
                      _SmallBtn(
                        icon:  Icons.remove_rounded,
                        color: c.textTertiary,
                        onTap: widget.onRemoveSet,
                      ),
                      const SizedBox(width: 8),
                      _SmallBtn(
                        icon:  Icons.add_rounded,
                        color: _teal,
                        onTap: widget.onAddSet,
                      ),
                      const Spacer(),
                      _NoteChip(
                        note:   widget.currentNote,
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

class _SessionCircuitCard extends StatefulWidget {
  final String                           circuitId, circuitName;
  final List<SessionExercise>            exercises;
  final int                              currentRound, totalRounds;
  final List<ActiveSet> Function(dynamic) getSets;
  final void Function(int)               onGoToRound;
  final VoidCallback                     onNextRound, onPrevRound;
  final void Function(dynamic, int)      onToggle;
  final void Function(dynamic, int, double, int) onUpdate;
  final void Function(dynamic)           onAddSet, onRemoveSet;
  final void Function(dynamic)           onRemoveExercise;
  final VoidCallback                     onModify, onRemoveCircuit;
  final void Function(List<SessionExercise>) onReorderExercises;

  const _SessionCircuitCard({
    required this.circuitId,       required this.circuitName,
    required this.exercises,       required this.currentRound,
    required this.totalRounds,     required this.getSets,
    required this.onGoToRound,     required this.onNextRound,
    required this.onPrevRound,     required this.onToggle,
    required this.onUpdate,        required this.onAddSet,
    required this.onRemoveSet,     required this.onRemoveExercise,
    required this.onModify,        required this.onRemoveCircuit,
    required this.onReorderExercises,
  });

  @override
  State<_SessionCircuitCard> createState() => _SessionCircuitCardState();
}

class _SessionCircuitCardState extends State<_SessionCircuitCard> {
  bool _expanded = false;

  int get _completedCount {
    int n = 0;
    for (final ex in widget.exercises) {
      n += widget.getSets(ex.exerciseKey)
          .where((s) => s.completed).length;
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
    final c       = context.mfc;
    final hasPrev = widget.currentRound > 0;
    final hasNext = widget.currentRound < widget.totalRounds - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color:        c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left:   BorderSide(
                  color: _indigo.withOpacity(0.6), width: 3),
              top:    BorderSide(
                  color: _indigo.withOpacity(0.2), width: 0.7),
              right:  BorderSide(
                  color: _indigo.withOpacity(0.2), width: 0.7),
              bottom: BorderSide(
                  color: _indigo.withOpacity(0.2), width: 0.7),
            ),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8)]
                : [BoxShadow(color: _indigo.withOpacity(0.06),
                    blurRadius: 16)],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 18, color: c.iconSecondary),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:        _indigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.loop_rounded,
                            color: _indigo, size: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.circuitName, style: TextStyle(
                                color:      c.textPrimary,
                                fontSize:   14,
                                fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('$_completedCount/$_totalCount serie',
                                style: TextStyle(
                                    color:    _indigo.withOpacity(0.8),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onModify,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color:        _indigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _indigo.withOpacity(0.3)),
                          ),
                          child: const Text('Modifica', style: TextStyle(
                              color:      _indigo,
                              fontSize:   11,
                              fontWeight: FontWeight.w600)))),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          final ok = await showGlassDialog<bool>(
                            context:     context,
                            accentColor: _red,
                            title:   'Elimina circuito',
                            message: 'Vuoi eliminare definitivamente '
                                'questo circuito dalla sessione?',
                            actions: [
                              GlassDialogAction(
                                label: 'Annulla',
                                onTap: () =>
                                    Navigator.pop(context, false),
                              ),
                              GlassDialogAction(
                                label:         'Elimina',
                                isDestructive: true,
                                onTap:         () =>
                                    Navigator.pop(context, true),
                              ),
                            ],
                          );
                          if (ok == true && context.mounted) {
                            widget.onRemoveCircuit();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color:        _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _red.withOpacity(0.3)),
                          ),
                          child: const Text('Elimina', style: TextStyle(
                              color:      _red,
                              fontSize:   11,
                              fontWeight: FontWeight.w600)))),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: c.textTertiary, size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Container(height: 0.7,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      _indigo.withOpacity(0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:        _indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _indigo.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: hasPrev ? widget.onPrevRound : null,
                              child: Container(width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: hasPrev
                                      ? _indigo.withOpacity(0.15)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chevron_left_rounded,
                                    color: hasPrev ? _indigo : c.textTertiary,
                                    size: 20))),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Ciclo ${widget.currentRound + 1} '
                                    'di ${widget.totalRounds}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color:      c.textPrimary,
                                        fontSize:   13,
                                        fontWeight: FontWeight.w700)),
                                  if (widget.totalRounds > 1) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        widget.totalRounds,
                                        (i) {
                                          final active =
                                              i == widget.currentRound;
                                          return GestureDetector(
                                            onTap: () =>
                                                widget.onGoToRound(i),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              margin: const EdgeInsets
                                                  .symmetric(horizontal: 3),
                                              width:  active ? 16 : 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? _indigo
                                                    : c.textTertiary
                                                        .withOpacity(0.4),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                boxShadow: active
                                                    ? [BoxShadow(
                                                        color: _indigo
                                                            .withOpacity(0.5),
                                                        blurRadius: 4)]
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: hasNext ? widget.onNextRound : null,
                              child: Container(width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: hasNext
                                      ? _indigo.withOpacity(0.15)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chevron_right_rounded,
                                    color: hasNext ? _indigo : c.textTertiary,
                                    size: 20))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Padding(
                    key: ValueKey(
                        '${widget.circuitId}_r${widget.currentRound}'),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: widget.exercises.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text('Nessun esercizio',
                                style: TextStyle(
                                    color:     c.textTertiary,
                                    fontSize:  12,
                                    fontStyle: FontStyle.italic)))
                        : _CircuitRoundContent(
                            circuitId:          widget.circuitId,
                            exercises:          widget.exercises,
                            roundIndex:         widget.currentRound,
                            getSets:            widget.getSets,
                            onToggle:           widget.onToggle,
                            onUpdate:           widget.onUpdate,
                            onAddSet:           widget.onAddSet,
                            onRemoveSet:        widget.onRemoveSet,
                            onRemoveExercise:   widget.onRemoveExercise,
                            onReorderExercises: widget.onReorderExercises,
                          ),
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

class _CircuitRoundContent extends StatelessWidget {
  final String                               circuitId;
  final List<SessionExercise>                exercises;
  final int                                  roundIndex;
  final List<ActiveSet> Function(dynamic)    getSets;
  final void Function(dynamic, int)          onToggle;
  final void Function(dynamic, int, double, int) onUpdate;
  final void Function(dynamic)               onAddSet, onRemoveSet;
  final void Function(dynamic)               onRemoveExercise;
  final void Function(List<SessionExercise>) onReorderExercises;

  const _CircuitRoundContent({
    required this.circuitId,        required this.exercises,
    required this.roundIndex,       required this.getSets,
    required this.onToggle,         required this.onUpdate,
    required this.onAddSet,         required this.onRemoveSet,
    required this.onRemoveExercise, required this.onReorderExercises,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap:              true,
      physics:                 const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (_, _) => Material(
          elevation: 0, color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _cyan.withOpacity(0.5), width: 1.2),
              boxShadow: [BoxShadow(
                  color: _cyan.withOpacity(0.12), blurRadius: 10)],
            ),
            child: child,
          ),
        ),
      ),
      onReorder: (oldIdx, newIdx) {
        if (newIdx > oldIdx) newIdx--;
        final r    = List<SessionExercise>.from(exercises);
        final item = r.removeAt(oldIdx);
        r.insert(newIdx, item);
        onReorderExercises(r);
      },
      children: exercises.asMap().entries.map((e) {
        final ex   = e.value;
        final sets = getSets(ex.exerciseKey);
        return ReorderableDelayedDragStartListener(
          key:   ValueKey('${ex.exerciseKey}_r$roundIndex'),
          index: e.key,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CircuitExerciseBlock(
              exercise:    ex,
              sets:        sets,
              onToggle:    (i)       => onToggle(ex.exerciseKey, i),
              onUpdate:    (i, w, r) => onUpdate(ex.exerciseKey, i, w, r),
              onAddSet:    ()        => onAddSet(ex.exerciseKey),
              onRemoveSet: ()        => onRemoveSet(ex.exerciseKey),
              onRemove:    ()        => onRemoveExercise(ex.exerciseKey),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CircuitExerciseBlock extends StatelessWidget {
  final SessionExercise                exercise;
  final List<ActiveSet>                sets;
  final void Function(int)             onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback                   onAddSet, onRemoveSet, onRemove;

  const _CircuitExerciseBlock({
    required this.exercise, required this.sets,
    required this.onToggle, required this.onUpdate,
    required this.onAddSet, required this.onRemoveSet,
    required this.onRemove,
  });

  // FASE 4 — etichetta struttura attesa per posizione, letta
  // direttamente dall'istantanea immutabile su SessionExercise.
  String? _expectedLabelFor(int index) {
    final structure = exercise.expectedStructure;
    if (structure == null || index >= structure.length) return null;
    return structure[index].label;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: BoxDecoration(
            color:        c.glassCardInset,
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
                  Icon(Icons.drag_handle_rounded,
                      size: 16, color: c.iconSecondary),
                  const SizedBox(width: 6),
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: _indigo, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(exercise.exerciseName,
                      style: TextStyle(color: c.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showGlassDialog<bool>(
                        context:     context,
                        accentColor: _red,
                        title:   'Elimina esercizio',
                        message: 'Vuoi eliminare questo esercizio '
                            'dalla sessione?',
                        actions: [
                          GlassDialogAction(
                            label: 'Annulla',
                            onTap: () => Navigator.pop(context, false),
                          ),
                          GlassDialogAction(
                            label:         'Elimina',
                            isDestructive: true,
                            onTap:         () =>
                                Navigator.pop(context, true),
                          ),
                        ],
                      );
                      if (ok == true && context.mounted) onRemove();
                    },
                    child: Container(width: 24, height: 24,
                      decoration: BoxDecoration(
                        color:        _red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 12, color: _red.withOpacity(0.7)))),
                ],
              ),
              const SizedBox(height: 8),
              ...sets.asMap().entries.map((e) => _SetRow(
                    index:    e.key,
                    set:      e.value,
                    onToggle: () => onToggle(e.key),
                    onUpdate: (w, r) => onUpdate(e.key, w, r),
                    compact:  true,
                    expectedLabel: _expectedLabelFor(e.key),
                  )),
              const SizedBox(height: 4),
              Row(
                children: [
                  _SmallBtn(
                    icon:  Icons.remove_rounded,
                    color: c.textTertiary,
                    onTap: onRemoveSet,
                  ),
                  const SizedBox(width: 6),
                  _SmallBtn(
                    icon:  Icons.add_rounded,
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

class _SetRow extends StatefulWidget {
  final int                        index;
  final ActiveSet                  set;
  final VoidCallback               onToggle;
  final void Function(double, int) onUpdate;
  final bool                       compact;
  // FASE 4 — etichetta della struttura attesa per questa posizione
  // (es. "8" oppure "8-12"), puramente informativa. Non rende il
  // campo non modificabile: l'utente può sempre discostarsene
  // durante l'esecuzione (Parte 16 — la sessione registra ciò che è
  // stato realmente eseguito, non ciò che era previsto).
  final String?                    expectedLabel;

  const _SetRow({
    required this.index,   required this.set,
    required this.onToggle, required this.onUpdate,
    this.compact = false,
    this.expectedLabel,
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
      text: widget.set.weight > 0 ? widget.set.weight.toString() : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.set.reps.toString(),
    );
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
    if (old.set.weight != widget.set.weight) {
      _weightCtrl.text = widget.set.weight > 0
          ? widget.set.weight.toString() : '';
    }
    if (old.set.reps != widget.set.reps) {
      _repsCtrl.text = widget.set.reps.toString();
    }
  }

  // FASE 4 — Parte 17: incremento/decremento rapido delle
  // ripetizioni, indipendente per ogni serie. Aggiorna il
  // controller per coerenza visiva immediata e propaga il nuovo
  // valore tramite onUpdate, senza toccare focus/tastiera del
  // campo peso adiacente.
  void _stepReps(int delta) {
    final current = int.tryParse(_repsCtrl.text) ?? widget.set.reps;
    final next = (current + delta).clamp(0, 999);
    setState(() => _repsCtrl.text = '$next');
    final w = double.tryParse(_weightCtrl.text) ?? widget.set.weight;
    widget.onUpdate(w, next);
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final isDark    = context.isDarkMode;
    final completed = widget.set.completed;
    final rowColor  = completed ? _teal : c.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 26,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.index + 1}', style: TextStyle(
                    color:      rowColor.withOpacity(0.6),
                    fontSize:   12,
                    fontWeight: FontWeight.w700)),
                if (widget.expectedLabel != null)
                  Text(widget.expectedLabel!, style: TextStyle(
                      color:    c.textTertiary.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500)),
              ],
            )),
          Expanded(child: Container(
            height: widget.compact ? 30 : 34,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color:        c.inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: completed
                    ? _teal.withOpacity(0.3) : c.inputBorder,
                width: isDark ? 0.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: TextField(
                  controller:         _weightCtrl,
                  keyboardType: const TextInputType
                      .numberWithOptions(decimal: true),
                  keyboardAppearance: isDark
                      ? Brightness.dark : Brightness.light,
                  textAlign:   TextAlign.center,
                  cursorColor: _teal,
                  style: TextStyle(
                      color:      c.inputText,
                      fontSize:   13,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText:  widget.set.lastWeight != null
                        ? '${widget.set.lastWeight}' : 'kg',
                    hintStyle: TextStyle(
                        color: c.inputHint, fontSize: 12),
                    border:    InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6)),
                  onChanged: (v) {
                    final w = double.tryParse(v) ?? 0;
                    final r = int.tryParse(_repsCtrl.text) ??
                        widget.set.reps;
                    widget.onUpdate(w, r);
                  })),
                Text('kg', style: TextStyle(
                    color: c.textTertiary, fontSize: 10)),
                const SizedBox(width: 4),
              ],
            ),
          )),
          GestureDetector(
            onTap: () => _stepReps(-1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(Icons.remove_circle_outline_rounded,
                  size: widget.compact ? 15 : 17,
                  color: c.iconSecondary),
            ),
          ),
          SizedBox(
            width:  widget.compact ? 42 : 48,
            height: widget.compact ? 30 : 34,
            child: Container(
              decoration: BoxDecoration(
                color:        c.inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: completed
                      ? _teal.withOpacity(0.3) : c.inputBorder,
                  width: isDark ? 0.8 : 1.0,
                ),
              ),
              child: TextField(
                controller:         _repsCtrl,
                keyboardType:       TextInputType.number,
                keyboardAppearance: isDark
                    ? Brightness.dark : Brightness.light,
                textAlign:   TextAlign.center,
                cursorColor: _teal,
                style: TextStyle(
                    color:      c.inputText,
                    fontSize:   13,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText:  widget.set.lastReps != null
                      ? '${widget.set.lastReps}' : 'rip',
                  hintStyle: TextStyle(
                      color: c.inputHint, fontSize: 12),
                  border:    InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4)),
                onChanged: (v) {
                  final r = int.tryParse(v) ?? widget.set.reps;
                  final w = double.tryParse(_weightCtrl.text) ??
                      widget.set.weight;
                  widget.onUpdate(w, r);
                }),
            ),
          ),
          GestureDetector(
            onTap: () => _stepReps(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(Icons.add_circle_outline_rounded,
                  size: widget.compact ? 15 : 17,
                  color: _teal),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  widget.compact ? 28 : 32,
              height: widget.compact ? 28 : 32,
              decoration: BoxDecoration(
                color: completed ? _teal : c.glassCardInset,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: completed ? _teal : c.glassBorder,
                  width: 1.2,
                ),
                boxShadow: completed
                    ? [BoxShadow(color: _teal.withOpacity(0.4),
                        blurRadius: 8)]
                    : null,
              ),
              child: Icon(Icons.check_rounded,
                  color:  completed ? Colors.white : c.textTertiary,
                  size:   widget.compact ? 14 : 16)),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
      child: Icon(icon, size: 14, color: color)));
}

// ─────────────────────────────────────────────────────────────
// _NoteChip — ADATTIVO (già corretto, usa c.mfc)
// ─────────────────────────────────────────────────────────────
class _NoteChip extends StatelessWidget {
  final String                        note;
  final Future<void> Function(String) onSave;
  const _NoteChip({required this.note, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final c       = context.mfc;
    final hasNote = note.isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final ctrl = TextEditingController(text: note);
        await showKeyboardSafeSheet(
          context,
          GlassSheetWrapper(
            title:       'Nota esercizio',
            accentColor: _cyan,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GlassTextField(controller: ctrl,
                  hintText: 'Aggiungi una nota...', maxLines: 3),
              const SizedBox(height: 16),
              GlassPrimaryButton(
                label: 'Salva nota',
                color: _teal,
                onTap: () async {
                  await onSave(ctrl.text.trim());
                  if (context.mounted) Navigator.pop(context);
                }),
            ])));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasNote ? _cyan.withOpacity(0.1) : c.glassCardInset,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasNote ? _cyan.withOpacity(0.35) : c.glassBorder,
            width: 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            hasNote
                ? Icons.sticky_note_2_rounded
                : Icons.add_comment_rounded,
            size:  12,
            color: hasNote ? _cyan.withOpacity(0.7) : c.iconSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            hasNote ? 'Nota' : 'Aggiungi nota',
            style: TextStyle(
              color: hasNote ? _cyan.withOpacity(0.7) : c.textTertiary,
              fontSize:   11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AddToSessionSheet — sheet usa GlassSheetWrapper (ora theme-aware)
// ─────────────────────────────────────────────────────────────
class _AddToSessionSheet extends StatelessWidget {
  final VoidCallback onAddExercise, onAddCircuit;
  const _AddToSessionSheet({
    required this.onAddExercise, required this.onAddCircuit});

  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title:       'Aggiungi alla sessione',
      accentColor: _teal,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SessionMenuOption(
          icon:     Icons.fitness_center_rounded,
          label:    'Aggiungi esercizio',
          subtitle: 'Inserisci un esercizio singolo',
          color:    _teal,
          onTap:    onAddExercise,
        ),
        const SizedBox(height: 10),
        _SessionMenuOption(
          icon:     Icons.loop_rounded,
          label:    'Aggiungi circuito',
          subtitle: 'Crea un gruppo di esercizi in serie',
          color:    _indigo,
          onTap:    onAddCircuit,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionMenuOption — FIX: subtitle ora usa c.textTertiary
// PRIMA: Colors.white.withOpacity(0.4) hardcoded
// ─────────────────────────────────────────────────────────────
class _SessionMenuOption extends StatelessWidget {
  final IconData     icon;
  final String       label, subtitle;
  final Color        color;
  final VoidCallback onTap;

  const _SessionMenuOption({
    required this.icon,     required this.label,
    required this.subtitle, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: legge tema corrente
    final c = context.mfc;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                        color:      color,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    // FIX: era Colors.white.withOpacity(0.4)
                    Text(subtitle, style: TextStyle(
                        color:    c.textTertiary,
                        fontSize: 11)),
                  ],
                )),
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