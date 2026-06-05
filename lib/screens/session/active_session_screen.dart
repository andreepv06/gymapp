import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

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
    await context.read<SessionProvider>().startSession(
          exercises,
          widget.workout.key,
          widget.workout.name,
        );
    if (mounted) setState(() => _started = true);
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
                            fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Vuoi salvare e terminare la sessione?',
                style:
                    Theme.of(context).textTheme.bodyMedium),
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
        const SnackBar(content: Text('Sessione salvata!')),
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
          body:
              Center(child: CircularProgressIndicator()));
    }

    final sessionProvider =
        context.watch<SessionProvider>();
    final exercises = sessionProvider.sessionExercises;
    final exerciseSets = sessionProvider.exerciseSets;

    final allSets =
        exerciseSets.values.expand((s) => s).toList();
    final completedSets =
        allSets.where((s) => s.completed).length;
    final totalSets = allSets.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        // FIX swipe back: l'AppBar di Flutter su iOS
        // abilita automaticamente il back gesture quando
        // c'è un leading arrow — non serve nulla in più
        // se il Navigator usa CupertinoPageRoute o
        // MaterialPageRoute con allowSnapshotting.
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
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSets > 0
                          ? completedSets / totalSets
                          : 0,
                      minHeight: 8,
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
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
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 24),
              itemCount: exercises.length,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => Material(
                    elevation: 8,
                    borderRadius:
                        BorderRadius.circular(16),
                    shadowColor: Colors.black45,
                    child: child,
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                sessionProvider.reorderSessionExercises(
                    oldIndex, newIndex);
              },
              itemBuilder: (_, i) {
                final ex = exercises[i];
                final sets =
                    exerciseSets[ex.exerciseKey] ?? [];
                return _ExerciseSessionCard(
                  key: ValueKey(ex.exerciseKey),
                  index: i,
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
                      .addSetToExercise(ex.exerciseKey),
                  onRemoveSet: () => sessionProvider
                      .removeSetFromExercise(
                          ex.exerciseKey),
                  onRemoveExercise: () => sessionProvider
                      .removeExerciseFromSession(
                          ex.exerciseKey),
                  onEditNote: (note) =>
                      sessionProvider.updateExerciseNote(
                          ex.exerciseKey, note),
                );
              },
            ),
          ),
        ],
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
                    onPressed: () =>
                        setState(() => _selected.clear()),
                    child:
                        const Text('Deseleziona tutto'),
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
                                _selected.remove(ex.key);
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
                        setState(() => _loading = true);
                        final allEx = context
                            .read<ExerciseProvider>()
                            .exercises;
                        for (final key in _selected) {
                          try {
                            final ex = allEx.firstWhere(
                                (e) => e.key == key);
                            await context
                                .read<SessionProvider>()
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
  final int index;
  final void Function(int) onToggle;
  final void Function(int, double, int) onUpdate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final VoidCallback onRemoveExercise;
  final void Function(String) onEditNote;

  const _ExerciseSessionCard({
    super.key,
    required this.sessionExercise,
    required this.sets,
    required this.index,
    required this.onToggle,
    required this.onUpdate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onEditNote,
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
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.7)
                : cs.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : cs.outlineVariant,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                                  fontSize: 16),
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
                      padding: const EdgeInsets.symmetric(
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
                      margin:
                          const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 36),
                    Expanded(
                        child: Text('Peso (kg)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.outline))),
                    Expanded(
                        child: Text('Reps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.outline))),
                    const SizedBox(width: 48),
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
                // Azioni con bottoni glass mini
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
                      color:
                          Theme.of(context)
                              .colorScheme
                              .primary,
                      onTap: onAddSet,
                    ),
                    _MiniGlassButton(
                      label: hasNote
                          ? 'Modifica nota'
                          : 'Nota',
                      color:
                          Theme.of(context)
                              .colorScheme
                              .tertiary,
                      onTap: () =>
                          _showNoteDialog(context),
                    ),
                    _MiniGlassButton(
                      label: 'Rimuovi',
                      color: Colors.red,
                      onTap: () {
                        // Conferma prima di rimuovere
                        showGlassDialog(
                          context: context,
                          child: Padding(
                            padding:
                                const EdgeInsets.all(24),
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
                                  cancelLabel: 'Annulla',
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

/// Bottone mini glass per azioni inline
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

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: '');
    _repsCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    final weight = double.tryParse(_weightCtrl.text) ??
        widget.set.lastWeight ??
        widget.set.weight;
    final reps = int.tryParse(_repsCtrl.text) ??
        widget.set.lastReps ??
        widget.set.reps;
    widget.onUpdate(weight, reps);
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.set.completed;
    final cs = Theme.of(context).colorScheme;
    final weightHint = widget.set.lastWeight != null
        ? widget.set.lastWeight! % 1 == 0
            ? widget.set.lastWeight!.toInt().toString()
            : widget.set.lastWeight.toString()
        : widget.set.weight > 0
            ? widget.set.weight.toString()
            : '-';
    final repsHint = widget.set.lastReps?.toString() ??
        widget.set.reps.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? cs.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('${widget.setNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? cs.primary
                      : cs.outline,
                )),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4),
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
                  contentPadding:
                      const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
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
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4),
              child: TextField(
                controller: _repsCtrl,
                enabled: !isCompleted,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: repsHint,
                  contentPadding:
                      const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
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
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              onPressed: () {
                if (_weightCtrl.text.isEmpty ||
                    _repsCtrl.text.isEmpty) {
                  final weight =
                      double.tryParse(_weightCtrl.text) ??
                          widget.set.lastWeight ??
                          widget.set.weight;
                  final reps =
                      int.tryParse(_repsCtrl.text) ??
                          widget.set.lastReps ??
                          widget.set.reps;
                  widget.onUpdate(weight, reps);
                }
                widget.onToggle();
              },
              icon: Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: isCompleted
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                    : Theme.of(context)
                        .colorScheme
                        .outline,
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bg.withOpacity(
                  isDark ? 0.7 : 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isOver
                        ? cs.error
                        : cs.secondary)
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