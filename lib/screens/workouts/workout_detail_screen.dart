import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final dynamic workoutId;
  final String workoutName;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<WorkoutDetailScreen> createState() =>
      _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState
    extends State<WorkoutDetailScreen> {
  late ExerciseProvider _exerciseProvider;
  late WorkoutProvider _workoutProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exerciseProvider = context.read<ExerciseProvider>();
    _workoutProvider = context.read<WorkoutProvider>();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context
          .read<WorkoutProvider>()
          .loadWorkoutExercises(widget.workoutId);
      context.read<ExerciseProvider>().loadExercises();
    });
  }

  void _showAddExercisesSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
                value: _exerciseProvider),
            ChangeNotifierProvider.value(
                value: _workoutProvider),
          ],
          child: _SelectExercisesScreen(
              workoutId: widget.workoutId),
        ),
      ),
    );
  }

  void _showEditSheet(HiveWorkoutExercise we) {
    showGlassBottomSheet(
      context: context,
      child: ChangeNotifierProvider.value(
        value: _workoutProvider,
        child: _EditExerciseSheet(workoutExercise: we),
      ),
    );
  }

  void _confirmDeleteExercise(HiveWorkoutExercise we) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.delete_outline,
                    color: Colors.red, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Rimuovi esercizio',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Vuoi rimuovere "${we.exerciseName}"?'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Rimuovi',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                _workoutProvider.removeExerciseFromWorkout(
                    we.key, widget.workoutId);
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
    final exercises =
        context.watch<WorkoutProvider>().currentExercises;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(widget.workoutName),
      ),
      body: exercises.isEmpty
          ? _EmptyExercisesState(
              onAdd: _showAddExercisesSheet)
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 120),
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
                if (newIndex > oldIndex) newIndex--;
                final reordered =
                    List<HiveWorkoutExercise>.from(
                        exercises);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                _workoutProvider.reorderExercises(
                    widget.workoutId, reordered);
              },
              itemBuilder: (_, i) {
                final we = exercises[i];
                return _ExerciseRow(
                  key: ValueKey(we.key),
                  index: i,
                  workoutExercise: we,
                  onEdit: () => _showEditSheet(we),
                  onDelete: () =>
                      _confirmDeleteExercise(we),
                );
              },
            ),
      bottomNavigationBar: exercises.isNotEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  MediaQuery.of(context).padding.bottom +
                      16),
              child: GlassButton(
                onTap: _showAddExercisesSheet,
                icon: Icons.add_rounded,
                label: 'Aggiungi esercizi',
              ),
            )
          : null,
    );
  }
}

class _EmptyExercisesState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyExercisesState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center_outlined,
                  size: 40,
                  color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'Nessun esercizio',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Aggiungi il primo esercizio\na questa scheda',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 28),
            GlassButton(
              onTap: onAdd,
              icon: Icons.add_rounded,
              label: 'Aggiungi esercizi',
              minWidth: 220,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final HiveWorkoutExercise workoutExercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const _ExerciseRow({
    super.key,
    required this.workoutExercise,
    required this.onEdit,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final we = workoutExercise;
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return ReorderableDelayedDragStartListener(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? cs.surface.withOpacity(0.8)
              : cs.surface,
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
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                we.exerciseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                we.muscleGroup,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: cs.outline),
              ),
              if (we.notes != null &&
                  we.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    we.notes!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: cs.outline),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _InfoChip(label: '${we.sets} serie'),
                  _InfoChip(
                      label: '${we.targetReps} reps'),
                  if (we.targetWeight != null &&
                      we.targetWeight! > 0)
                    _InfoChip(
                        label: '${we.targetWeight} kg'),
                  if (we.restSeconds != null)
                    _InfoChip(
                        label:
                            '${we.restSeconds}s rec.'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _SmallGlassButton(
                    label: 'Modifica',
                    icon: Icons.edit_outlined,
                    color: cs.primary,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _SmallGlassButton(
                    label: 'Rimuovi',
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: onDelete,
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

/// Bottone piccolo glass per azioni inline nelle card
class _SmallGlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallGlassButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: cs.onSecondaryContainer)),
    );
  }
}

// ── Selezione esercizi ──
class _SelectExercisesScreen extends StatefulWidget {
  final dynamic workoutId;
  const _SelectExercisesScreen({required this.workoutId});

  @override
  State<_SelectExercisesScreen> createState() =>
      _SelectExercisesScreenState();
}

class _SelectExercisesScreenState
    extends State<_SelectExercisesScreen> {
  final Set<dynamic> _selected = {};
  String _search = '';
  String _muscleFilter = 'Tutti';
  bool _loading = false;

  void _toggle(dynamic key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _confirmAdd() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final allExercises =
          context.read<ExerciseProvider>().exercises;
      final provider = context.read<WorkoutProvider>();
      final existing = provider.currentExercises;
      final selected = _selected.toList();
      final toAdd = <HiveWorkoutExercise>[];
      for (int i = 0; i < selected.length; i++) {
        final matches =
            allExercises.where((e) => e.key == selected[i]);
        if (matches.isEmpty) continue;
        final ex = matches.first;
        toAdd.add(HiveWorkoutExercise(
          workoutKey: widget.workoutId,
          exerciseKey: ex.key,
          exerciseName: ex.name,
          muscleGroup: ex.muscleGroup,
          notes: ex.notes,
          sets: 3,
          targetReps: 8,
          sortOrder: existing.length + i,
        ));
      }
      await provider.addExercisesToWorkout(toAdd);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExercises =
        context.watch<ExerciseProvider>().exercises;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty
            ? 'Seleziona esercizi'
            : '${_selected.length} selezionati'),
        actions: [
          if (_selected.isNotEmpty)
            _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2)),
                  )
                : GlassTextButton(
                    onPressed: _confirmAdd,
                    child: const Text('Aggiungi'),
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
            child: allExercises.isEmpty
                ? const Center(
                    child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ex = filtered[i];
                      final isSelected =
                          _selected.contains(ex.key);
                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) =>
                              _toggle(ex.key),
                        ),
                        title: Text(ex.name),
                        subtitle: Text(ex.muscleGroup),
                        onTap: () => _toggle(ex.key),
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
              child: GlassButton(
                onTap: _loading ? () {} : _confirmAdd,
                icon: Icons.add_rounded,
                label: _loading
                    ? 'Aggiunta...'
                    : 'Aggiungi ${_selected.length} esercizi',
              ),
            ),
        ],
      ),
    );
  }
}

// ── Edit Exercise Sheet glass ──
class _EditExerciseSheet extends StatefulWidget {
  final HiveWorkoutExercise workoutExercise;
  const _EditExerciseSheet({required this.workoutExercise});

  @override
  State<_EditExerciseSheet> createState() =>
      _EditExerciseSheetState();
}

class _EditExerciseSheetState
    extends State<_EditExerciseSheet> {
  late final TextEditingController _restCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();
  late List<_SerieRow> _series;

  @override
  void initState() {
    super.initState();
    final we = widget.workoutExercise;
    _restCtrl = TextEditingController(
        text: we.restSeconds?.toString() ?? '');
    _notesCtrl =
        TextEditingController(text: we.notes ?? '');
    _series = List.generate(
      we.sets,
      (i) => _SerieRow(
          reps: we.targetReps,
          weight: we.targetWeight ?? 0),
    );
  }

  @override
  void dispose() {
    _restCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addSerie() {
    setState(() {
      final last =
          _series.isNotEmpty ? _series.last : null;
      _series.add(_SerieRow(
        reps: last?.reps ??
            widget.workoutExercise.targetReps,
        weight: last?.weight ??
            widget.workoutExercise.targetWeight ??
            0,
      ));
    });
  }

  void _removeSerie(int index) {
    if (_series.length <= 1) return;
    setState(() => _series.removeAt(index));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final firstWeight =
        _series.isNotEmpty ? _series.first.weight : 0.0;
    final firstReps = _series.isNotEmpty
        ? _series.first.reps
        : widget.workoutExercise.targetReps;

    final we = widget.workoutExercise;
    final updated = HiveWorkoutExercise(
      workoutKey: we.workoutKey,
      exerciseKey: we.exerciseKey,
      exerciseName: we.exerciseName,
      muscleGroup: we.muscleGroup,
      sets: _series.length,
      targetReps: firstReps,
      targetWeight: firstWeight > 0 ? firstWeight : null,
      restSeconds: int.tryParse(_restCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      sortOrder: we.sortOrder,
    );

    context
        .read<WorkoutProvider>()
        .updateExerciseInWorkout(we.key, updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 16),
              Text(widget.workoutExercise.exerciseName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium),
              Text(
                  widget.workoutExercise.muscleGroup,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _restCtrl,
                decoration: const InputDecoration(
                    labelText: 'Recupero (secondi)',
                    prefixIcon:
                        Icon(Icons.timer_outlined)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText:
                      'Es. presa prona, ROM completo...',
                  prefixIcon: Icon(
                      Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Serie',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall),
                  const Spacer(),
                  _SmallGlassButton(
                    label: 'Aggiungi',
                    icon: Icons.add,
                    color: cs.primary,
                    onTap: _addSerie,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                        child: Text('Peso kg',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.outline))),
                    Expanded(
                        child: Text('Reps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.outline))),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ..._series.asMap().entries.map((entry) {
                final i = entry.key;
                final serie = entry.value;
                return _SerieEditRow(
                  index: i,
                  serie: serie,
                  canDelete: _series.length > 1,
                  onDelete: () => _removeSerie(i),
                  onChanged: (weight, reps) {
                    setState(() {
                      _series[i] = _SerieRow(
                          weight: weight, reps: reps);
                    });
                  },
                );
              }),
              const SizedBox(height: 20),
              GlassFilledButton(
                onPressed: _save,
                child: const Text('Salva'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SerieRow {
  double weight;
  int reps;
  _SerieRow({required this.weight, required this.reps});
}

class _SerieEditRow extends StatefulWidget {
  final int index;
  final _SerieRow serie;
  final bool canDelete;
  final VoidCallback onDelete;
  final void Function(double weight, int reps) onChanged;

  const _SerieEditRow({
    required this.index,
    required this.serie,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_SerieEditRow> createState() =>
      _SerieEditRowState();
}

class _SerieEditRowState extends State<_SerieEditRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.serie.weight > 0
            ? widget.serie.weight.toString()
            : '');
    _repsCtrl = TextEditingController(
        text: widget.serie.reps.toString());
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('${widget.index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4),
              child: TextField(
                controller: _weightCtrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  contentPadding:
                      const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  widget.onChanged(
                    double.tryParse(v) ?? 0,
                    int.tryParse(_repsCtrl.text) ??
                        widget.serie.reps,
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4),
              child: TextField(
                controller: _repsCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '8',
                  contentPadding:
                      const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  widget.onChanged(
                    double.tryParse(_weightCtrl.text) ??
                        widget.serie.weight,
                    int.tryParse(v) ?? widget.serie.reps,
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: widget.canDelete
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: Colors.red),
                    onPressed: widget.onDelete,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}