import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';

class ActiveSessionScreen extends StatefulWidget {
  final HiveWorkout workout;
  const ActiveSessionScreen({super.key, required this.workout});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final exercises = context.read<WorkoutProvider>().currentExercises;
    await context.read<SessionProvider>().startSession(
          exercises,
          widget.workout.key,
          widget.workout.name,
        );
    if (mounted) setState(() => _started = true);
  }

  Future<void> _finishSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Termina sessione'),
        content: const Text('Vuoi salvare e terminare la sessione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Termina'),
          ),
        ],
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

  // ── Selezione multipla esercizi ──
  void _showAddExerciseSheet() {
    final sessionProvider = context.read<SessionProvider>();
    final exerciseProvider = context.read<ExerciseProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: exerciseProvider),
          ChangeNotifierProvider.value(value: sessionProvider),
        ],
        child: const _AddMultipleExercisesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sessionProvider = context.watch<SessionProvider>();
    final exercises = sessionProvider.sessionExercises;
    final exerciseSets = sessionProvider.exerciseSets;

    final allSets = exerciseSets.values.expand((s) => s).toList();
    final completedSets = allSets.where((s) => s.completed).length;
    final totalSets = allSets.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          TextButton.icon(
            onPressed: _showAddExerciseSheet,
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('Aggiungi'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          TextButton(
            onPressed: _finishSession,
            child: const Text('Termina'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: totalSets > 0 ? completedSets / totalSets : 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$completedSets / $totalSets serie',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: exercises.length,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: Colors.black45,
                    child: child,
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                sessionProvider.reorderSessionExercises(oldIndex, newIndex);
              },
              itemBuilder: (_, i) {
                final ex = exercises[i];
                final sets = exerciseSets[ex.exerciseKey] ?? [];
                return _ExerciseSessionCard(
                  key: ValueKey(ex.exerciseKey),
                  index: i,
                  sessionExercise: ex,
                  sets: sets,
                  onToggle: (index) =>
                      sessionProvider.toggleSet(ex.exerciseKey, index),
                  onUpdate: (index, weight, reps) =>
                      sessionProvider.updateSet(ex.exerciseKey, index, weight, reps),
                  onAddSet: () => sessionProvider.addSetToExercise(ex.exerciseKey),
                  onRemoveSet: () =>
                      sessionProvider.removeSetFromExercise(ex.exerciseKey),
                  onRemoveExercise: () =>
                      sessionProvider.removeExerciseFromSession(ex.exerciseKey),
                  onEditNote: (note) =>
                      sessionProvider.updateExerciseNote(ex.exerciseKey, note),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selezione MULTIPLA esercizi durante sessione ──
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
    final allExercises = context.watch<ExerciseProvider>().exercises;
    final sessionProvider = context.read<SessionProvider>();
    final alreadyIn =
        sessionProvider.sessionExercises.map((e) => e.exerciseKey).toSet();

    final muscleGroups =
        ({...allExercises.map((e) => e.muscleGroup)}.toList()..sort());
    final groups = ['Tutti', ...muscleGroups];

    final filtered = allExercises.where((e) {
      final matchMuscle =
          _muscleFilter == 'Tutti' || e.muscleGroup == _muscleFilter;
      final matchSearch = _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
      return matchMuscle && matchSearch;
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Titolo con contatore selezione
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected.isEmpty
                        ? 'Aggiungi esercizi'
                        : '${_selected.length} selezionati',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('Deseleziona tutto'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Ricerca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca esercizio...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),

          // Filtro muscoli
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = groups[i];
                return ChoiceChip(
                  label: Text(g),
                  selected: _muscleFilter == g,
                  onSelected: (_) => setState(() => _muscleFilter = g),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Lista esercizi con checkbox
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isAlreadyIn = alreadyIn.contains(ex.key);
                final isSelected = _selected.contains(ex.key);

                return ListTile(
                  leading: isAlreadyIn
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary)
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
                              ? Theme.of(context).colorScheme.outline
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

          // Bottone conferma
          if (_selected.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          final allEx =
                              context.read<ExerciseProvider>().exercises;
                          for (final key in _selected) {
                            try {
                              final ex =
                                  allEx.firstWhere((e) => e.key == key);
                              await sessionProvider.addExerciseToSession(
                                exerciseKey: ex.key,
                                exerciseName: ex.name,
                                muscleGroup: ex.muscleGroup,
                                notes: ex.notes,
                              );
                            } catch (_) {}
                          }
                          if (mounted) Navigator.pop(context);
                        },
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Aggiungi ${_selected.length} esercizi'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Exercise Session Card ───
class _ExerciseSessionCard extends StatelessWidget {
  final SessionExercise sessionExercise;
  final List<ActiveSet> sets;
  final int index;
  final void Function(int index) onToggle;
  final void Function(int index, double weight, int reps) onUpdate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final VoidCallback onRemoveExercise;
  final void Function(String note) onEditNote;

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
    final ctrl = TextEditingController(text: sessionExercise.sessionNote ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nota — ${sessionExercise.exerciseName}'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Es. grip più stretto, ROM completo...',
          ),
        ),
        actions: [
          if (sessionExercise.sessionNote != null &&
              sessionExercise.sessionNote!.isNotEmpty)
            TextButton(
              onPressed: () {
                onEditNote('');
                Navigator.pop(context);
              },
              child: const Text('Elimina nota',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              onEditNote(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = sessionExercise;
    final completedCount = sets.where((s) => s.completed).length;
    final allDone = completedCount == sets.length && sets.isNotEmpty;
    final hasNote = ex.sessionNote != null && ex.sessionNote!.isNotEmpty;
    final hasExerciseNote = ex.notes != null && ex.notes!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6)
              : Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.exerciseName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                      Text(ex.muscleGroup,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline)),
                      if (hasExerciseNote)
                        Text(ex.notes!,
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.outline),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: allDone
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$completedCount/${sets.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: allDone
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      )),
                ),
              ],
            ),
            if (hasNote)
              GestureDetector(
                onTap: () => _showNoteDialog(context),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .tertiaryContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(ex.sessionNote!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.tertiary)),
                      ),
                      Icon(Icons.edit,
                          size: 12,
                          color: Theme.of(context).colorScheme.tertiary),
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
                            color: Theme.of(context).colorScheme.outline))),
                Expanded(
                    child: Text('Reps',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            ...sets.asMap().entries.map((entry) {
              final i = entry.key;
              final set = entry.value;
              return _SetRow(
                key: ValueKey('${ex.exerciseKey}_$i'),
                setNumber: set.setNumber,
                set: set,
                onToggle: () => onToggle(i),
                onUpdate: (weight, reps) => onUpdate(i, weight, reps),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: sets.length > 1 ? onRemoveSet : null,
                  icon: const Icon(Icons.remove, size: 14),
                  label: const Text('Serie', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onAddSet,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Serie', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _showNoteDialog(context),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 14),
                  label: Text(hasNote ? 'Modifica nota' : 'Nota',
                      style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onRemoveExercise,
                  icon: const Icon(Icons.delete_outline,
                      size: 14, color: Colors.red),
                  label: const Text('Rimuovi',
                      style: TextStyle(fontSize: 11, color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
            Consumer<SessionProvider>(
              builder: (_, session, __) {
                final isResting = session.isResting &&
                    session.restingExerciseId == ex.exerciseKey;
                if (!isResting) return const SizedBox.shrink();
                return _RestBanner(
                  elapsed: session.restElapsed,
                  targetRest: ex.restSeconds,
                  onStop: () => session.stopRestTimer(),
                );
              },
            ),
          ],
        ),
      ),
    );
  
  
  }
}

class _SetRow extends StatefulWidget {
  final int setNumber;
  final ActiveSet set;
  final VoidCallback onToggle;
  final void Function(double weight, int reps) onUpdate;

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
    final weightHint = widget.set.lastWeight != null
        ? widget.set.lastWeight! % 1 == 0
            ? widget.set.lastWeight!.toInt().toString()
            : widget.set.lastWeight.toString()
        : widget.set.weight > 0
            ? widget.set.weight.toString()
            : '-';
    final repsHint =
        widget.set.lastReps?.toString() ?? widget.set.reps.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
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
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                )),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _weightCtrl,
                enabled: !isCompleted,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: weightHint,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: isCompleted,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                ),
                onChanged: (_) => _notifyUpdate(),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _repsCtrl,
                enabled: !isCompleted,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: repsHint,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: isCompleted,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
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
                if (_weightCtrl.text.isEmpty || _repsCtrl.text.isEmpty) {
                  final weight = double.tryParse(_weightCtrl.text) ??
                      widget.set.lastWeight ??
                      widget.set.weight;
                  final reps = int.tryParse(_repsCtrl.text) ??
                      widget.set.lastReps ??
                      widget.set.reps;
                  widget.onUpdate(weight, reps);
                }
                widget.onToggle();
              },
              icon: Icon(
                isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
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
    final isOver = targetRest != null && elapsed >= targetRest!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOver
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.notifications_active : Icons.timer_outlined,
            color: isOver
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOver ? 'Recupero terminato!' : 'Recupero in corso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOver
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  targetRest != null
                      ? '${_format(elapsed)} / ${_format(targetRest!)}'
                      : _format(elapsed),
                  style: TextStyle(
                    fontSize: 12,
                    color: isOver
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onStop,
            child: Text('Stop',
                style: TextStyle(
                  color: isOver
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                )),
          ),
        ],
      ),
    );
  }
}