import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../db/hive_database.dart';

class ActiveSessionScreen extends StatefulWidget {
  final HiveWorkout workout;
  const ActiveSessionScreen(
      {super.key, required this.workout});

  @override
  State<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState
    extends State<ActiveSessionScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final exercises =
        context.read<WorkoutProvider>().currentExercises;
    final circuits = HiveDatabase.instance
        .getCircuits(widget.workout.key);
    await context.read<SessionProvider>().startSession(
          exercises,
          widget.workout.key,
          widget.workout.name,
          widget.workout,
          circuits: circuits,
        );
    if (mounted) setState(() => _started = true);
  }

  Future<bool> _onWillPop() async {
    final session = context.read<SessionProvider>();

    if (!session.hasAnyData) {
      await session.abandonSession();
      return true;
    }

    final result = await showGlassDialog<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    Icons.pause_circle_outline,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    size: 22),
                const SizedBox(width: 10),
                Text('Sessione in corso',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
                'Cosa vuoi fare con la sessione?'),
            const SizedBox(height: 24),
            Column(
              children: [
                GlassFilledButton(
                  onPressed: () =>
                      Navigator.pop(context, 'pause'),
                  child: const Text('Metti in pausa'),
                ),
                const SizedBox(height: 10),
                GlassFilledButton(
                  onPressed: () =>
                      Navigator.pop(context, 'finish'),
                  backgroundColor: Colors.green,
                  child:
                      const Text('Termina e salva'),
                ),
                const SizedBox(height: 10),
                GlassOutlinedButton(
                  onPressed: () => Navigator.pop(
                      context, 'abandon'),
                  foregroundColor: Colors.red,
                  child: const Text(
                      'Abbandona senza salvare'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == null) return false;

    if (result == 'pause') {
      session.pauseSession();
      return true;
    } else if (result == 'finish') {
      await session.finishSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sessione salvata!')),
        );
      }
      return true;
    } else if (result == 'abandon') {
      await session.abandonSession();
      return true;
    }

    return false;
  }

  Future<void> _finishSession() async {
    final confirm = await showGlassDialog<bool>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    size: 22),
                const SizedBox(width: 10),
                Text('Termina sessione',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'Vuoi salvare e terminare la sessione?',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Termina',
              onCancel: () =>
                  Navigator.pop(context, false),
              onConfirm: () =>
                  Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await context.read<SessionProvider>().finishSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sessione salvata!')),
      );
      Navigator.pop(context);
    }
  }

  void _showAddExerciseSheet() {
    final sessionProvider =
        context.read<SessionProvider>();
    final exerciseProvider =
        context.read<ExerciseProvider>();
    showGlassBottomSheet(
      context: context,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
              value: exerciseProvider),
          ChangeNotifierProvider.value(
              value: sessionProvider),
        ],
        child: const _AddMultipleExercisesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator()));
    }

    final sessionProvider =
        context.watch<SessionProvider>();
    final exercises = sessionProvider.sessionExercises;
    final exerciseSets = sessionProvider.exerciseSets;

    // Raggruppa esercizi per circuito
    final freeExercises = exercises
        .where((e) => !e.isInCircuit)
        .toList();
    final circuitIds = exercises
        .where((e) => e.isInCircuit)
        .map((e) => e.circuitId!)
        .toSet()
        .toList();

    final allSets =
        exerciseSets.values.expand((s) => s).toList();
    final completedSets =
        allSets.where((s) => s.completed).length;
    final totalSets = allSets.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            GlassTextButton(
              onPressed: _showAddExerciseSheet,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 18),
                  SizedBox(width: 6),
                  Text('Aggiungi'),
                ],
              ),
            ),
            GlassTextButton(
              onPressed: _finishSession,
              child: const Text('Termina'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: totalSets > 0
                          ? completedSets / totalSets
                          : 0,
                      minHeight: 8,
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                      '$completedSets / $totalSets serie',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 24),
                buildDefaultDragHandles: false,
                proxyDecorator:
                    (child, index, animation) =>
                        AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => Material(
                    elevation: 8,
                    borderRadius:
                        BorderRadius.circular(16),
                    shadowColor: Colors.black38,
                    child: child,
                  ),
                ),
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  sessionProvider
                      .reorderSessionExercises(
                          oldIndex, newIndex);
                },
                children: [
                  // Esercizi liberi
                  ...freeExercises
                      .asMap()
                      .entries
                      .map((e) {
                    final ex = e.value;
                    final sets =
                        exerciseSets[ex.exerciseKey] ?? [];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(
                          'free_${ex.exerciseKey}'),
                      index: e.key,
                      child: _ExerciseSessionCard(
                        sessionExercise: ex,
                        sets: sets,
                        onToggle: (index) =>
                            sessionProvider.toggleSet(
                                ex.exerciseKey, index),
                        onUpdate: (index, weight, reps) =>
                            sessionProvider.updateSet(
                                ex.exerciseKey,
                                index,
                                weight,
                                reps),
                        onAddSet: () => sessionProvider
                            .addSetToExercise(
                                ex.exerciseKey),
                        onRemoveSet: () => sessionProvider
                            .removeSetFromExercise(
                                ex.exerciseKey),
                        onRemoveExercise: () => sessionProvider
                            .removeExerciseFromSession(
                                ex.exerciseKey),
                        onEditNote: (note) =>
                            sessionProvider.updateExerciseNote(
                                ex.exerciseKey, note),
                      ),
                    );
                  }),
            
                  // Circuiti
                  ...circuitIds
                      .asMap()
                      .entries
                      .map((e) {
                    final circuitId = e.value;
                    final circuitExercises = exercises
                        .where(
                            (ex) => ex.circuitId == circuitId)
                        .toList();
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('circuit_$circuitId'),
                      index: freeExercises.length + e.key,
                      child: _CircuitSessionBlock(
                        circuitId: circuitId,
                        exercises: circuitExercises,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blocco circuito con navigazione tra round
class _CircuitSessionBlock extends StatelessWidget {
  final String circuitId;
  final List<SessionExercise> exercises;

  const _CircuitSessionBlock({
    super.key,
    required this.circuitId,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final currentRound = session.getCurrentRound(circuitId);
    final totalRounds = session.getTotalRounds(circuitId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.tertiaryContainer.withOpacity(0.12)
            : cs.tertiaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.tertiary.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header con navigazione round
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.tertiary.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(Icons.loop_rounded,
                    color: cs.tertiary, size: 18),
                const SizedBox(width: 8),
                Text('Circuito',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.tertiary,
                        fontSize: 14)),
                const Spacer(),
                // Freccia sinistra
                _RoundNavButton(
                  icon: Icons.chevron_left,
                  enabled: currentRound > 0,
                  color: cs.tertiary,
                  onTap: () =>
                      session.prevRound(circuitId),
                ),
                const SizedBox(width: 8),
                // Indicatore round
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ciclo ${currentRound + 1} di $totalRounds',
                    style: TextStyle(
                      color: cs.onTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Freccia destra
                _RoundNavButton(
                  icon: Icons.chevron_right,
                  enabled:
                      currentRound < totalRounds - 1,
                  color: cs.tertiary,
                  onTap: () =>
                      session.nextRound(circuitId),
                ),
              ],
            ),
          ),

          // Esercizi del round corrente
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: exercises.map((ex) {
                final sets = session.getCircuitSets(
                    circuitId, ex.exerciseKey);
                return _ExerciseSessionCard(
                  key: ValueKey(
                    '${ex.exerciseKey}_${circuitId}_$currentRound'),
                  sessionExercise: ex,
                  sets: sets,
                  onToggle: (index) =>
                      session.toggleSet(
                          ex.exerciseKey, index,
                          circuitId: circuitId),
                  onUpdate: (index, weight, reps) =>
                      session.updateSet(
                          ex.exerciseKey,
                          index,
                          weight,
                          reps,
                          circuitId: circuitId),
                  onAddSet: () =>
                      session.addSetToExercise(
                          ex.exerciseKey,
                          circuitId: circuitId),
                  onRemoveSet: () =>
                      session.removeSetFromExercise(
                          ex.exerciseKey,
                          circuitId: circuitId),
                  onRemoveExercise: () => session
                      .removeExerciseFromSession(
                          ex.exerciseKey),
                  onEditNote: (note) =>
                      session.updateExerciseNote(
                          ex.exerciseKey, note),
                  isInCircuit: true,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _RoundNavButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? color.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.4)
                : color.withOpacity(0.15),
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? color
              : color.withOpacity(0.3),
          size: 20,
        ),
      ),
    );
  }
}

class _AddMultipleExercisesSheet extends StatefulWidget {
  const _AddMultipleExercisesSheet();

  @override
  State<_AddMultipleExercisesSheet> createState() =>
      _AddMultipleExercisesSheetState();
}

class _AddMultipleExercisesSheetState
    extends State<_AddMultipleExercisesSheet> {
  String _search = '';
  String _muscleFilter = 'Tutti';
  final Set<dynamic> _selected = {};
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final allExercises =
        context.watch<ExerciseProvider>().exercises;
    final sessionProvider =
        context.read<SessionProvider>();
    final alreadyIn = sessionProvider.sessionExercises
        .map((e) => e.exerciseKey)
        .toSet();
    final muscleGroups =
        ({...allExercises.map((e) => e.muscleGroup)}
            .toList()
          ..sort());
    final groups = ['Tutti', ...muscleGroups];
    final filtered = allExercises.where((e) {
      final matchMuscle = _muscleFilter == 'Tutti' ||
          e.muscleGroup == _muscleFilter;
      final matchSearch = _search.isEmpty ||
          e.name
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchMuscle && matchSearch;
    }).toList();

    return SizedBox(
      height:
          MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12),
            child: const GlassSheetHandle(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected.isEmpty
                        ? 'Aggiungi esercizi'
                        : '${_selected.length} selezionati',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                if (_selected.isNotEmpty)
                  GlassTextButton(
                    onPressed: () => setState(
                        () => _selected.clear()),
                    child: const Text(
                        'Deseleziona tutto'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca esercizio...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) =>
                  setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16),
              itemCount: groups.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = groups[i];
                return ChoiceChip(
                  label: Text(g),
                  selected: _muscleFilter == g,
                  onSelected: (_) =>
                      setState(() => _muscleFilter = g),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isAlreadyIn =
                    alreadyIn.contains(ex.key);
                final isSelected =
                    _selected.contains(ex.key);
                return ListTile(
                  leading: isAlreadyIn
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context)
                              .colorScheme
                              .primary)
                      : Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            setState(() {
                              if (isSelected) {
                                _selected
                                    .remove(ex.key);
                              } else {
                                _selected.add(ex.key);
                              }
                            });
                          },
                        ),
                  title: Text(ex.name,
                      style: TextStyle(
                          color: isAlreadyIn
                              ? Theme.of(context)
                                  .colorScheme
                                  .outline
                              : null)),
                  subtitle: Text(ex.muscleGroup),
                  enabled: !isAlreadyIn,
                  onTap: isAlreadyIn
                      ? null
                      : () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(ex.key);
                            } else {
                              _selected.add(ex.key);
                            }
                          });
                        },
                );
              },
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom +
                      16),
              child: GlassFilledButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(
                            () => _loading = true);
                        final allEx = context
                            .read<ExerciseProvider>()
                            .exercises;
                        for (final key in _selected) {
                          try {
                            final ex =
                                allEx.firstWhere(
                                    (e) =>
                                        e.key == key);
                            await context.read<SessionProvider>()
                              .addExerciseToSession(
                                  exerciseKey: ex.key,
                                  exerciseName: ex.name,
                                  muscleGroup:
                                      ex.muscleGroup,
                                  notes: ex.notes,
                                );
                          } catch (_) {}
                        }
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : Text(
                        'Aggiungi ${_selected.length} esercizi'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseSessionCard extends StatelessWidget {
  final SessionExercise sessionExercise;
  final List<ActiveSet> sets;
  final void Function(int) onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final VoidCallback onRemoveExercise;
  final void Function(String) onEditNote;
  final bool isInCircuit;

  const _ExerciseSessionCard({
    super.key,
    required this.sessionExercise,
    required this.sets,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onEditNote,
    this.isInCircuit = false,
  });

  void _showNoteDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: sessionExercise.sessionNote ?? '');
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .tertiary,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Nota — ${sessionExercise.exerciseName}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                              fontWeight:
                                  FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'Es. grip più stretto, ROM completo...',
              ),
            ),
            const SizedBox(height: 16),
            if (sessionExercise.sessionNote != null &&
                sessionExercise.sessionNote!.isNotEmpty)
              GlassTextButton(
                onPressed: () {
                  onEditNote('');
                  Navigator.pop(context);
                },
                foregroundColor: Colors.red,
                child: const Text('Elimina nota'),
              ),
            const SizedBox(height: 8),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Salva',
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                onEditNote(ctrl.text.trim());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = sessionExercise;
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final completedCount =
        sets.where((s) => s.completed).length;
    final allDone =
        completedCount == sets.length && sets.isNotEmpty;
    final hasNote = ex.sessionNote != null &&
        ex.sessionNote!.isNotEmpty;
    final hasExerciseNote =
        ex.notes != null && ex.notes!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          margin: EdgeInsets.only(
              bottom: isInCircuit ? 8 : 12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.7)
                : cs.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : cs.outlineVariant.withOpacity(0.8),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(ex.exerciseName,
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 15),
                              overflow:
                                  TextOverflow.ellipsis),
                          Text(ex.muscleGroup,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.outline)),
                          if (hasExerciseNote)
                            Text(ex.notes!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontStyle:
                                        FontStyle.italic,
                                    color: cs.outline),
                                overflow:
                                    TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: allDone
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                          '$completedCount/${sets.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: allDone
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                          )),
                    ),
                  ],
                ),
                if (hasNote)
                  GestureDetector(
                    onTap: () =>
                        _showNoteDialog(context),
                    child: Container(
                      margin: const EdgeInsets.only(
                          top: 8),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer
                            .withOpacity(0.5),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.tertiary
                              .withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              Icons
                                  .sticky_note_2_outlined,
                              size: 14,
                              color: cs.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                ex.sessionNote!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.tertiary)),
                          ),
                          Icon(Icons.edit,
                              size: 12,
                              color: cs.tertiary),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                // Header colonne
                Row(
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                        flex: 3,
                        child: Text('Peso (kg)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.outline))),
                    const SizedBox(width: 4),
                    Expanded(
                        flex: 4,
                        child: Text('Reps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.outline))),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 4),
                ...sets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final set = entry.value;
                  return _SetRow(
                    key: ValueKey(
                        '${ex.exerciseKey}_$i'),
                    setNumber: set.setNumber,
                    set: set,
                    onToggle: () => onToggle(i),
                    onUpdate: (weight, reps) =>
                        onUpdate(i, weight, reps),
                  );
                }),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniGlassButton(
                      label: '– Serie',
                      color: Colors.red,
                      onTap: sets.length > 1
                          ? onRemoveSet
                          : null,
                    ),
                    _MiniGlassButton(
                      label: '+ Serie',
                      color: cs.primary,
                      onTap: onAddSet,
                    ),
                    _MiniGlassButton(
                      label: hasNote
                          ? 'Modifica nota'
                          : 'Nota',
                      color: cs.tertiary,
                      onTap: () =>
                          _showNoteDialog(context),
                    ),
                    _MiniGlassButton(
                      label: 'Rimuovi',
                      color: Colors.red,
                      onTap: () {
                        showGlassDialog(
                          context: context,
                          child: Padding(
                            padding:
                                const EdgeInsets.all(
                                    24),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                    'Rimuovere ${ex.exerciseName}?',
                                    style: Theme.of(
                                            context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight
                                                    .w700)),
                                const SizedBox(
                                    height: 20),
                                GlassDialogActions(
                                  cancelLabel:
                                      'Annulla',
                                  confirmLabel:
                                      'Rimuovi',
                                  confirmColor:
                                      Colors.red,
                                  onCancel: () =>
                                      Navigator.pop(
                                          context),
                                  onConfirm: () {
                                    Navigator.pop(
                                        context);
                                    onRemoveExercise();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Consumer<SessionProvider>(
                  builder: (_, session, __) {
                    final isResting =
                        session.isResting &&
                            session.restingExerciseId ==
                                ex.exerciseKey;
                    if (!isResting)
                      return const SizedBox.shrink();
                    return _RestBanner(
                      elapsed: session.restElapsed,
                      targetRest: ex.restSeconds,
                      onStop: () =>
                          session.stopRestTimer(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGlassButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MiniGlassButton({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.transparent
              : color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.4)
                : color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDisabled
                ? Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3)
                : color,
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int setNumber;
  final ActiveSet set;
  final VoidCallback onToggle;
  final void Function(double, int) onUpdate;

  const _SetRow({
    super.key,
    required this.setNumber,
    required this.set,
    required this.onToggle,
    required this.onUpdate,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late int _currentReps;

  @override
  void initState() {
    super.initState();
    _currentReps =
        widget.set.lastReps ?? widget.set.reps;
    _weightCtrl = TextEditingController(
        text: widget.set.weight > 0
            ? (widget.set.weight % 1 == 0
                ? widget.set.weight.toInt().toString()
                : widget.set.weight.toString())
            : '');
    _repsCtrl = TextEditingController(
        text: _currentReps.toString());
  }

  // FIX: aggiorna i controller quando cambiano i dati
  // (es. navigazione tra round del circuito)
  @override
  void didUpdateWidget(_SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set != widget.set) {
      _currentReps =
          widget.set.lastReps ?? widget.set.reps;

      final newWeight = widget.set.weight > 0
          ? (widget.set.weight % 1 == 0
              ? widget.set.weight.toInt().toString()
              : widget.set.weight.toString())
          : '';

      if (_weightCtrl.text != newWeight) {
        _weightCtrl.text = newWeight;
      }

      final newReps = _currentReps.toString();
      if (_repsCtrl.text != newReps) {
        _repsCtrl.text = newReps;
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    final weight =
        double.tryParse(_weightCtrl.text) ??
            widget.set.lastWeight ??
            widget.set.weight;
    final reps =
        int.tryParse(_repsCtrl.text) ?? _currentReps;
    widget.onUpdate(weight, reps);
  }

  void _changeReps(int delta) {
    if (widget.set.completed) return;
    final current =
        int.tryParse(_repsCtrl.text) ?? _currentReps;
    final newVal = (current + delta).clamp(0, 999);
    setState(() {
      _currentReps = newVal;
      _repsCtrl.text = newVal.toString();
    });
    _notifyUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.set.completed;
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final weightHint = widget.set.lastWeight != null
        ? widget.set.lastWeight! % 1 == 0
            ? widget.set.lastWeight!.toInt().toString()
            : widget.set.lastWeight.toString()
        : widget.set.weight > 0
            ? widget.set.weight.toString()
            : '-';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
          horizontal: 2, vertical: 5),
      decoration: BoxDecoration(
        color: isCompleted
            ? cs.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${widget.setNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isCompleted
                      ? cs.primary
                      : cs.outline,
                )),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _weightCtrl,
              enabled: !isCompleted,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(
                      decimal: true),
              decoration: InputDecoration(
                isDense: true,
                hintText: weightHint,
                hintStyle: TextStyle(
                    fontSize: 12,
                    color: cs.outline.withOpacity(0.6)),
                contentPadding:
                    const EdgeInsets.symmetric(
                        vertical: 7, horizontal: 6),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8)),
                filled: isCompleted,
                fillColor: cs.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              onChanged: (_) => _notifyUpdate(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isCompleted
                    ? cs.surfaceContainerHighest
                        .withOpacity(0.3)
                    : isDark
                        ? Colors.white.withOpacity(0.05)
                        : cs.surfaceContainerHighest
                            .withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? cs.outlineVariant
                          .withOpacity(0.3)
                      : cs.outlineVariant,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _RepsBtn(
                    icon: Icons.remove,
                    onTap: isCompleted
                        ? null
                        : () => _changeReps(-1),
                    color: cs.outline,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _repsCtrl,
                      enabled: !isCompleted,
                      textAlign: TextAlign.center,
                      keyboardType:
                          TextInputType.number,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? cs.outline
                            : cs.onSurface,
                      ),
                      decoration:
                          const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(
                                vertical: 7),
                      ),
                      onChanged: (v) {
                        _currentReps =
                            int.tryParse(v) ??
                                _currentReps;
                        _notifyUpdate();
                      },
                    ),
                  ),
                  _RepsBtn(
                    icon: Icons.add,
                    onTap: isCompleted
                        ? null
                        : () => _changeReps(1),
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                final weight =
                    double.tryParse(_weightCtrl.text) ??
                        widget.set.lastWeight ??
                        widget.set.weight;
                final reps =
                    int.tryParse(_repsCtrl.text) ??
                        _currentReps;
                widget.onUpdate(weight, reps);
                widget.onToggle();
              },
              icon: Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: isCompleted
                    ? cs.primary
                    : cs.outline,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RepsBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _RepsBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 36,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? color.withOpacity(0.3)
              : color,
        ),
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  final int elapsed;
  final int? targetRest;
  final VoidCallback onStop;

  const _RestBanner({
    required this.elapsed,
    required this.targetRest,
    required this.onStop,
  });

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final isOver =
        targetRest != null && elapsed >= targetRest!;
    final bg = isOver
        ? cs.errorContainer
        : cs.secondaryContainer;
    final fg = isOver
        ? cs.onErrorContainer
        : cs.onSecondaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg
                  .withOpacity(isDark ? 0.7 : 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    (isOver ? cs.error : cs.secondary)
                        .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOver
                      ? Icons.notifications_active
                      : Icons.timer_outlined,
                  color: fg,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOver
                            ? 'Recupero terminato!'
                            : 'Recupero in corso',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: fg,
                        ),
                      ),
                      Text(
                        targetRest != null
                            ? '${_format(elapsed)} / ${_format(targetRest!)}'
                            : _format(elapsed),
                        style: TextStyle(
                            fontSize: 12, color: fg),
                      ),
                    ],
                  ),
                ),
                GlassTextButton(
                  onPressed: onStop,
                  foregroundColor: fg,
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}