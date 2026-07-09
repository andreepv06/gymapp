import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_button.dart';

// ─────────────────────────────────────────────────────────────
// ActiveSessionScreen — usa SessionProvider per tutto lo stato.
// La schermata gestisce SOLO display timer locale e PageController
// dei circuiti. Tutto il resto (serie, pesi, round, pausa,
// ripristino) è in SessionProvider/Hive.
// ─────────────────────────────────────────────────────────────

// Elementi display top-level
sealed class _DItem {}

class _FreeExItem extends _DItem {
  final SessionExercise ex;
  _FreeExItem(this.ex);
  String get key => ex.exerciseKey.toString();
}

class _CircuitItem extends _DItem {
  final String circuitId;
  final List<SessionExercise> exercises;
  _CircuitItem(this.circuitId, this.exercises);
}

// ─────────────────────────────────────────────────────────────

class ActiveSessionScreen extends StatefulWidget {
  final dynamic workoutId;
  final String workoutName;

  const ActiveSessionScreen({
    super.key,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _initialized = false;
  bool _finishing = false;

  // Timer locale per display elapsed
  Timer? _displayTimer;
  int _displayElapsed = 0;

  // PageController per ogni circuito (circuitId → controller)
  final Map<String, PageController> _circuitControllers = {};

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    for (final c in _circuitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Init ─────────────────────────────────────────────────────

  Future<void> _initSession() async {
    final sp = context.read<SessionProvider>();

    // Sessione già attiva per questa scheda → ripristino
    if (sp.hasActiveSession &&
        sp.currentWorkout?.key == widget.workoutId) {
      _displayElapsed = sp.elapsedSeconds;
      _startDisplayTimer();
      if (mounted) setState(() => _initialized = true);
      return;
    }

    // Carica dati dal DB
    final db = HiveDatabase.instance;
    final workouts = db.getWorkouts();
    HiveWorkout? workout;
    try {
      workout = workouts.firstWhere((w) => w.key == widget.workoutId);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final exercises = db.getWorkoutExercises(widget.workoutId)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final circuits = db.getCircuits(widget.workoutId)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    await sp.startSession(
      exercises,
      widget.workoutId,
      widget.workoutName,
      workout,
      circuits: circuits,
    );

    _displayElapsed = 0;
    _startDisplayTimer();

    if (mounted) setState(() => _initialized = true);
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _displayElapsed++);
    });
  }

  // ── Build display items ───────────────────────────────────────

  List<_DItem> _buildDisplayItems(List<SessionExercise> exercises) {
    final items = <_DItem>[];
    final seen = <String>{};
    for (final ex in exercises) {
      if (ex.circuitId != null) {
        final cid = ex.circuitId!;
        if (!seen.contains(cid)) {
          seen.add(cid);
          final circuitExes =
              exercises.where((e) => e.circuitId == cid).toList();
          items.add(_CircuitItem(cid, circuitExes));
        }
      } else {
        items.add(_FreeExItem(ex));
      }
    }
    return items;
  }

  // ── PageController per circuito ───────────────────────────────

  PageController _controllerFor(String circuitId, int currentRound) {
    _circuitControllers.putIfAbsent(
      circuitId,
      () => PageController(initialPage: currentRound),
    );
    return _circuitControllers[circuitId]!;
  }

  // ── Reorder top-level ─────────────────────────────────────────

  void _onTopReorder(
      int oldIndex, int newIndex, List<_DItem> items, SessionProvider sp) {
    if (newIndex > oldIndex) newIndex--;
    final newItems = List<_DItem>.from(items);
    final item = newItems.removeAt(oldIndex);
    newItems.insert(newIndex, item);

    // Ricostruisce la lista piatta di SessionExercise nel nuovo ordine
    final newFlat = <SessionExercise>[];
    for (final dItem in newItems) {
      if (dItem is _FreeExItem) {
        newFlat.add(dItem.ex);
      } else if (dItem is _CircuitItem) {
        final circuitExes = sp.sessionExercises
            .where((e) => e.circuitId == dItem.circuitId)
            .toList();
        newFlat.addAll(circuitExes);
      }
    }

    sp.reorderSessionExercisesFlat(newFlat);
    HapticFeedback.selectionClick();
  }

  // ── Exit ─────────────────────────────────────────────────────

  Future<void> _handleExit() async {
    final sp = context.read<SessionProvider>();
    _displayTimer?.cancel();

    final completedSets = sp.completedSetsCount;
    final totalSets = sp.totalSetsCount;

    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Sessione di allenamento'),
        message: Text(
          completedSets > 0
              ? '$completedSets/$totalSets serie completate · ${_fmtTime(_displayElapsed)}'
              : 'Nessuna serie completata ancora.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continua allenamento'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'pause'),
            child: const Text('Metti in pausa'),
          ),
          if (completedSets > 0)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Salva e termina'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Elimina sessione'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('Annulla'),
        ),
      ),
    );

    if (!mounted) return;

    switch (result) {
      case 'continue':
      case 'cancel':
      case null:
        _startDisplayTimer();
        break;
      case 'pause':
        sp.pauseSession();
        if (mounted) Navigator.of(context).pop();
        break;
      case 'save':
        await _saveAndEnd(sp);
        break;
      case 'delete':
        await sp.abandonSession();
        if (mounted) Navigator.of(context).pop();
        break;
    }
  }

  Future<void> _saveAndEnd(SessionProvider sp) async {
    if (_finishing) return;
    if (sp.completedSetsCount == 0) {
      // Nessuna serie → elimina senza salvare
      await sp.abandonSession();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _finishing = true);
    await sp.finishSession();
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_initialized) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          title: Text(widget.workoutName),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sp = context.watch<SessionProvider>();
    final displayItems = _buildDisplayItems(sp.sessionExercises);
    final completed = sp.completedSetsCount;
    final total = sp.totalSetsCount;
    final progress = total > 0 ? completed / total : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _handleExit,
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.workoutName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                _fmtTime(_displayElapsed),
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            _finishing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : GlassTextButton(
                    onPressed: completed > 0
                        ? () => _saveAndEnd(sp)
                        : null,
                    foregroundColor:
                        completed > 0 ? cs.primary : cs.outline,
                    child: const Text(
                      'Termina',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            // Corpo principale
            CustomScrollView(
              slivers: [
                // Barra progresso
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor:
                                cs.primary.withOpacity(0.12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completed / $total serie completate',
                          style: TextStyle(
                              fontSize: 11, color: cs.outline),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista riordinabile
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      // Spazio extra per rest overlay + bottom bar
                      sp.isResting ? 200 : 120),
                  sliver: SliverReorderableList(
                    itemCount: displayItems.length,
                    itemBuilder: (ctx, index) {
                      final item = displayItems[index];
                      final stableKey = item is _FreeExItem
                          ? ValueKey('fex_${item.key}')
                          : ValueKey(
                              'circuit_${(item as _CircuitItem).circuitId}');
                      return ReorderableDelayedDragStartListener(
                        key: stableKey,
                        index: index,
                        child: item is _FreeExItem
                            ? _FreeExCard(
                                key: ValueKey(
                                    'fex_card_${item.key}'),
                                ex: item.ex,
                                sp: sp,
                              )
                            : _CircuitBlock(
                                key: ValueKey(
                                    'circuit_block_${(item as _CircuitItem).circuitId}'),
                                circuitId: item.circuitId,
                                exercises: item.exercises,
                                sp: sp,
                                controller: _controllerFor(
                                    item.circuitId,
                                    sp.getCurrentRound(
                                        item.circuitId)),
                              ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) =>
                        _onTopReorder(
                            oldIndex, newIndex, displayItems, sp),
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                      animation: animation,
                      builder: (_, __) => Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        shadowColor: Colors.black38,
                        color: Colors.transparent,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Rest timer overlay
            if (sp.isResting)
              _RestOverlay(
                total: sp.restTotal,
                remaining: sp.restRemaining,
                paused: sp.restPaused,
                onTogglePause: sp.toggleRestPause,
                onSkip: sp.skipRest,
                onAddTime: sp.addRestTime,
              ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: GlassButton(
            onTap: _finishing
                ? () {}
                : () => _saveAndEnd(sp),
            icon: completed > 0
                ? Icons.check_circle_outline_rounded
                : Icons.close_rounded,
            label: _finishing
                ? 'Salvataggio...'
                : completed > 0
                    ? 'Termina sessione'
                    : 'Chiudi senza salvare',
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _FreeExCard — card esercizio libero
// ─────────────────────────────────────────────────────────────

class _FreeExCard extends StatelessWidget {
  final SessionExercise ex;
  final SessionProvider sp;

  const _FreeExCard({super.key, required this.ex, required this.sp});

  @override
  Widget build(BuildContext context) {
    final sets = sp.exerciseSets[ex.exerciseKey] ?? [];
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.8) : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.drag_handle_rounded,
                    size: 18, color: cs.outline.withOpacity(0.4)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.exerciseName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(ex.muscleGroup,
                          style: TextStyle(
                              fontSize: 12, color: cs.outline)),
                    ],
                  ),
                ),
                if ((ex.restSeconds ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('${ex.restSeconds}s',
                            style: TextStyle(
                                fontSize: 11, color: cs.primary)),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                // Aggiungi/rimuovi serie
                GestureDetector(
                  onTap: () =>
                      sp.removeSetFromExercise(ex.exerciseKey),
                  child: Icon(Icons.remove_circle_outline,
                      size: 18, color: cs.outline.withOpacity(0.5)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => sp.addSetToExercise(ex.exerciseKey),
                  child: Icon(Icons.add_circle_outline,
                      size: 18, color: cs.primary),
                ),
              ],
            ),
          ),

          // Intestazioni
          _SetHeaders(cs: cs),
          const SizedBox(height: 4),

          // Righe serie
          ...sets.asMap().entries.map((e) => _SetRow(
                key: ValueKey('free_${ex.exerciseKey}_${e.key}'),
                index: e.key,
                set: e.value,
                onToggle: () =>
                    sp.toggleSet(ex.exerciseKey, e.key),
                onWeightChanged: (w) => sp.updateSet(
                    ex.exerciseKey, e.key, w, e.value.reps),
                onRepsChanged: (r) => sp.updateSet(
                    ex.exerciseKey, e.key, e.value.weight, r),
              )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitBlock — circuito con PageView per round
// ─────────────────────────────────────────────────────────────

class _CircuitBlock extends StatefulWidget {
  final String circuitId;
  final List<SessionExercise> exercises;
  final SessionProvider sp;
  final PageController controller;

  const _CircuitBlock({
    super.key,
    required this.circuitId,
    required this.exercises,
    required this.sp,
    required this.controller,
  });

  @override
  State<_CircuitBlock> createState() => _CircuitBlockState();
}

class _CircuitBlockState extends State<_CircuitBlock> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sp = widget.sp;
    final totalRounds = sp.getTotalRounds(widget.circuitId);
    final currentRound = sp.getCurrentRound(widget.circuitId);

    // Altezza stimata: header + navigazione + esercizi
    final estimatedHeight = 80.0 + // header
        (totalRounds > 1 ? 52.0 : 0) + // navigazione
        widget.exercises.length * 152.0; // esercizi

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.tertiaryContainer.withOpacity(0.15)
            : cs.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.tertiary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header circuito
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.drag_handle_rounded,
                    size: 18,
                    color: cs.outline.withOpacity(0.4)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.loop_rounded,
                      color: cs.onTertiaryContainer, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Nome circuito non disponibile in SessionExercise
                        // usiamo "Circuito" come fallback
                        widget.exercises.isNotEmpty
                            ? 'Circuito'
                            : 'Circuito',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '$totalRounds cicl${totalRounds == 1 ? 'o' : 'i'} · ${widget.exercises.length} esercizi',
                        style:
                            TextStyle(fontSize: 12, color: cs.tertiary),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Ciclo ${currentRound + 1}/$totalRounds',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Navigazione round (solo se > 1)
          if (totalRounds > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _CircuitNavBtn(
                    icon: Icons.chevron_left_rounded,
                    enabled: currentRound > 0,
                    cs: cs,
                    onTap: () {
                      final prev = currentRound - 1;
                      if (prev >= 0) {
                        widget.controller.animateToPage(
                          prev,
                          duration:
                              const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        sp.setRound(widget.circuitId, prev);
                      }
                    },
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalRounds, (i) {
                        final isCur = i == currentRound;
                        // Conta completati nel round i
                        int done = 0;
                        int tot = 0;
                        for (final ex in widget.exercises) {
                          final sets = sp.getCircuitSetsForRound(
                              widget.circuitId, i, ex.exerciseKey);
                          done +=
                              sets.where((s) => s.completed).length;
                          tot += sets.length;
                        }
                        final allDone = tot > 0 && done == tot;

                        return GestureDetector(
                          onTap: () {
                            widget.controller.animateToPage(
                              i,
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            sp.setRound(widget.circuitId, i);
                          },
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 4),
                            width: isCur ? 36 : 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: allDone
                                  ? cs.tertiary
                                  : isCur
                                      ? cs.tertiaryContainer
                                      : cs.outlineVariant
                                          .withOpacity(0.3),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: isCur
                                  ? Border.all(
                                      color: cs.tertiary,
                                      width: 1.5)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: allDone
                                      ? cs.onTertiary
                                      : isCur
                                          ? cs.tertiary
                                          : cs.outline,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  _CircuitNavBtn(
                    icon: Icons.chevron_right_rounded,
                    enabled: currentRound < totalRounds - 1,
                    cs: cs,
                    onTap: () {
                      final next = currentRound + 1;
                      if (next < totalRounds) {
                        widget.controller.animateToPage(
                          next,
                          duration:
                              const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        sp.setRound(widget.circuitId, next);
                      }
                    },
                  ),
                ],
              ),
            ),

          // PageView dei round
          SizedBox(
            height: estimatedHeight,
            child: PageView.builder(
              controller: widget.controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalRounds,
              onPageChanged: (i) {
                sp.setRound(widget.circuitId, i);
              },
              itemBuilder: (ctx, roundIdx) {
                return _CircuitRoundPage(
                  circuitId: widget.circuitId,
                  roundIndex: roundIdx,
                  exercises: widget.exercises,
                  sp: sp,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitNavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _CircuitNavBtn({
    required this.icon,
    required this.enabled,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? cs.tertiaryContainer
              : cs.outlineVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color:
              enabled ? cs.tertiary : cs.outline.withOpacity(0.3),
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitRoundPage — pagina singola round di un circuito
// ─────────────────────────────────────────────────────────────

class _CircuitRoundPage extends StatelessWidget {
  final String circuitId;
  final int roundIndex;
  final List<SessionExercise> exercises;
  final SessionProvider sp;

  const _CircuitRoundPage({
    required this.circuitId,
    required this.roundIndex,
    required this.exercises,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: exercises.map((ex) {
        final sets = sp.getCircuitSetsForRound(
            circuitId, roundIndex, ex.exerciseKey);

        return Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.7)
                : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : cs.outlineVariant.withOpacity(0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header esercizio nel circuito
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.exerciseName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(ex.muscleGroup,
                              style: TextStyle(
                                  fontSize: 11, color: cs.outline)),
                        ],
                      ),
                    ),
                    // Aggiungi/rimuovi serie
                    GestureDetector(
                      onTap: () => sp.removeSetFromExercise(
                          ex.exerciseKey,
                          circuitId: circuitId),
                      child: Icon(Icons.remove_circle_outline,
                          size: 16,
                          color: cs.outline.withOpacity(0.5)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => sp.addSetToExercise(
                          ex.exerciseKey,
                          circuitId: circuitId),
                      child: Icon(Icons.add_circle_outline,
                          size: 16, color: cs.tertiary),
                    ),
                  ],
                ),
              ),
              _SetHeaders(cs: cs),
              const SizedBox(height: 2),
              ...sets.asMap().entries.map((e) => _SetRow(
                    key: ValueKey(
                        'circuit_${circuitId}_r${roundIndex}_${ex.exerciseKey}_${e.key}'),
                    index: e.key,
                    set: e.value,
                    onToggle: () => sp.toggleCircuitSetForRound(
                        circuitId,
                        roundIndex,
                        ex.exerciseKey,
                        e.key),
                    onWeightChanged: (w) =>
                        sp.updateCircuitSetForRound(
                            circuitId,
                            roundIndex,
                            ex.exerciseKey,
                            e.key,
                            w,
                            e.value.reps),
                    onRepsChanged: (r) =>
                        sp.updateCircuitSetForRound(
                            circuitId,
                            roundIndex,
                            ex.exerciseKey,
                            e.key,
                            e.value.weight,
                            r),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SetHeaders
// ─────────────────────────────────────────────────────────────

class _SetHeaders extends StatelessWidget {
  final ColorScheme cs;
  const _SetHeaders({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 2, 12, 0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Peso (kg)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: cs.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Ripetizioni',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: cs.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SetRow — riga serie con placeholder peso e rep +/-
// ─────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final int index;
  final ActiveSet set;
  final VoidCallback onToggle;
  final void Function(double) onWeightChanged;
  final void Function(int) onRepsChanged;

  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.onToggle,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _wCtrl;
  late TextEditingController _rCtrl;

  @override
  void initState() {
    super.initState();
    final w = widget.set.weight;
    // Peso: vuoto se 0 (lastWeight viene mostrato come placeholder)
    _wCtrl = TextEditingController(
      text: w > 0
          ? (w % 1 == 0 ? w.toInt().toString() : w.toString())
          : '',
    );
    _rCtrl = TextEditingController(text: '${widget.set.reps}');
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _rCtrl.dispose();
    super.dispose();
  }

  /// Quando completa una serie con campo peso vuoto, usa lastWeight
  void _handleToggle() {
    if (!widget.set.completed) {
      final text = _wCtrl.text.trim();
      if (text.isEmpty) {
        final lw = widget.set.lastWeight;
        if (lw != null && lw > 0) {
          final str =
              lw % 1 == 0 ? lw.toInt().toString() : lw.toString();
          setState(() => _wCtrl.text = str);
          widget.onWeightChanged(lw);
        }
      }
    }
    widget.onToggle();
  }

  void _decReps() {
    final cur = widget.set.reps;
    if (cur <= 1) return;
    widget.onRepsChanged(cur - 1);
    setState(() => _rCtrl.text = '${cur - 1}');
    HapticFeedback.selectionClick();
  }

  void _incReps() {
    final cur = widget.set.reps;
    widget.onRepsChanged(cur + 1);
    setState(() => _rCtrl.text = '${cur + 1}');
    HapticFeedback.selectionClick();
  }

  String get _weightHint {
    final lw = widget.set.lastWeight;
    if (lw == null || lw <= 0) return '';
    return lw % 1 == 0 ? lw.toInt().toString() : lw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = widget.set.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: done ? cs.primary.withOpacity(0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Numero serie
          SizedBox(
            width: 32,
            child: Text(
              '${widget.index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: done ? cs.primary : cs.onSurface,
              ),
            ),
          ),

          // Peso con placeholder lastWeight
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _wCtrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  hintText: _weightHint,
                  hintStyle: TextStyle(
                    color: cs.outline.withOpacity(0.5),
                    fontWeight: FontWeight.normal,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 6),
                  filled: done,
                  fillColor:
                      done ? cs.primary.withOpacity(0.05) : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: done
                          ? cs.primary.withOpacity(0.3)
                          : cs.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: done ? cs.primary : null,
                  fontWeight:
                      done ? FontWeight.w600 : FontWeight.normal,
                ),
                onChanged: (v) =>
                    widget.onWeightChanged(double.tryParse(v) ?? 0),
              ),
            ),
          ),

          // Rep: [-] campo [+]
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RepBtn(
                  icon: Icons.remove_rounded,
                  cs: cs,
                  done: done,
                  onTap: _decReps,
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _rCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      filled: done,
                      fillColor: done
                          ? cs.primary.withOpacity(0.05)
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: done
                              ? cs.primary.withOpacity(0.3)
                              : cs.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: cs.primary),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: done ? cs.primary : null,
                      fontWeight: done
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    onChanged: (v) {
                      final r = int.tryParse(v);
                      if (r != null) widget.onRepsChanged(r);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _RepBtn(
                  icon: Icons.add_rounded,
                  cs: cs,
                  done: done,
                  onTap: _incReps,
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Pulsante completa
          GestureDetector(
            onTap: _handleToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: done ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: done ? cs.primary : cs.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 20,
                color: done ? cs.onPrimary : cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepBtn extends StatelessWidget {
  final IconData icon;
  final ColorScheme cs;
  final bool done;
  final VoidCallback onTap;

  const _RepBtn({
    required this.icon,
    required this.cs,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: done
              ? cs.primary.withOpacity(0.12)
              : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: done
                ? cs.primary.withOpacity(0.3)
                : cs.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Icon(icon,
            size: 16,
            color: done ? cs.primary : cs.outline),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _RestOverlay — overlay Glass countdown recupero
// ─────────────────────────────────────────────────────────────

class _RestOverlay extends StatelessWidget {
  final int total;
  final int remaining;
  final bool paused;
  final VoidCallback onTogglePause;
  final VoidCallback onSkip;
  final void Function(int) onAddTime;

  const _RestOverlay({
    required this.total,
    required this.remaining,
    required this.paused,
    required this.onTogglePause,
    required this.onSkip,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = total > 0 ? remaining / total : 0.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 96,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.withOpacity(0.94)
                  : cs.surface.withOpacity(0.97),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : cs.primary.withOpacity(0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(isDark ? 0.4 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Timer circolare
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 5,
                          color: cs.primary.withOpacity(0.12),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          color: cs.primary,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '$remaining',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Controlli
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Recupero',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _RestCtrlBtn(
                            label: '-10s',
                            cs: cs,
                            onTap: () => onAddTime(-10),
                          ),
                          _RestCtrlBtn(
                            label: paused ? '▶' : '⏸',
                            cs: cs,
                            filled: true,
                            onTap: onTogglePause,
                          ),
                          _RestCtrlBtn(
                            label: '+30s',
                            cs: cs,
                            onTap: () => onAddTime(30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onSkip,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withOpacity(0.4),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color: cs.outlineVariant
                                    .withOpacity(0.4)),
                          ),
                          child: Text(
                            'Salta recupero',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _RestCtrlBtn extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final VoidCallback onTap;
  final bool filled;

  const _RestCtrlBtn({
    required this.label,
    required this.cs,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 36,
        decoration: BoxDecoration(
          color: filled
              ? cs.primary
              : cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.primary.withOpacity(filled ? 0 : 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}