import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/workout_icon.dart';
import '../../db/hive_database.dart';

// Item tipizzato per la lista piatta
enum _ItemType { exercise, circuit }

class _ListItem {
  final _ItemType type;
  final dynamic data; // HiveWorkoutExercise o HiveCircuit
  _ListItem({required this.type, required this.data});
}

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
  List<HiveCircuit> _circuits = [];

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
      _loadCircuits();
    });
  }

  void _loadCircuits() {
    setState(() {
      _circuits =
          HiveDatabase.instance.getCircuits(widget.workoutId);
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

  void _showAddCircuitSheet() {
    final nameCtrl = TextEditingController();
    int rounds = 3;
    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.loop_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Nuovo circuito',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              fontWeight:
                                  FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome circuito',
                  hintText:
                      'Es. Circuito A, Superset...',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Text('Numero di cicli',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoundsButton(
                    icon: Icons.remove,
                    onTap: rounds > 1
                        ? () => setModal(() => rounds--)
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$rounds cicli',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700)),
                    ),
                  ),
                  _RoundsButton(
                    icon: Icons.add,
                    onTap: () =>
                        setModal(() => rounds++),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Crea circuito',
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () async {
                  if (nameCtrl.text.trim().isEmpty)
                    return;
                  await HiveDatabase.instance
                      .addCircuit(HiveCircuit(
                    workoutKey: widget.workoutId,
                    name: nameCtrl.text.trim(),
                    rounds: rounds,
                    sortOrder: _circuits.length,
                  ));
                  _loadCircuits();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCircuitSheet(HiveCircuit circuit) {
    final nameCtrl =
        TextEditingController(text: circuit.name);
    int rounds = circuit.rounds;
    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 16),
              Text('Modifica circuito',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                          fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nome circuito'),
              ),
              const SizedBox(height: 16),
              Text('Numero di cicli',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoundsButton(
                    icon: Icons.remove,
                    onTap: rounds > 1
                        ? () => setModal(() => rounds--)
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$rounds cicli',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700)),
                    ),
                  ),
                  _RoundsButton(
                    icon: Icons.add,
                    onTap: () =>
                        setModal(() => rounds++),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Salva',
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () async {
                  await HiveDatabase.instance
                      .updateCircuit(
                          circuit.key,
                          nameCtrl.text.trim(),
                          rounds);
                  _loadCircuits();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCircuit(HiveCircuit circuit) {
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
                Text('Elimina circuito',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'Eliminare "${circuit.name}"? Verranno eliminati anche gli esercizi al suo interno.'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () async {
                await HiveDatabase.instance
                    .deleteCircuit(circuit.key);
                _loadCircuits();
                _workoutProvider.loadWorkoutExercises(
                    widget.workoutId);
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onReorder(
      int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final allExercises =
        _workoutProvider.currentExercises;
    final freeExercises =
        allExercises.where((e) => !e.isInCircuit).toList();

    // Costruisci lista piatta ordinata
    final items = <_ListItem>[];
    for (final ex in freeExercises) {
      items.add(_ListItem(
          type: _ItemType.exercise, data: ex));
    }
    for (final c in _circuits) {
      items.add(
          _ListItem(type: _ItemType.circuit, data: c));
    }

    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Aggiorna sortOrder per tipo
    int exOrder = 0;
    int circuitOrder = 0;
    for (final it in items) {
      if (it.type == _ItemType.exercise) {
        final we = it.data as HiveWorkoutExercise;
        final updated = HiveWorkoutExercise(
          workoutKey: we.workoutKey,
          exerciseKey: we.exerciseKey,
          exerciseName: we.exerciseName,
          muscleGroup: we.muscleGroup,
          sets: we.sets,
          targetReps: we.targetReps,
          targetWeight: we.targetWeight,
          restSeconds: we.restSeconds,
          notes: we.notes,
          sortOrder: exOrder++,
        );
        await HiveDatabase.instance
            .updateWorkoutExercise(we.key, updated);
      } else {
        final c = it.data as HiveCircuit;
        await HiveDatabase.instance
            .updateCircuitSortOrder(c.key, circuitOrder++);
      }
    }

    _workoutProvider.loadWorkoutExercises(widget.workoutId);
    _loadCircuits();
  }

  @override
  Widget build(BuildContext context) {
    final allExercises =
        context.watch<WorkoutProvider>().currentExercises;
    final cs = Theme.of(context).colorScheme;

    final freeExercises =
        allExercises.where((e) => !e.isInCircuit).toList();

    // Lista piatta per il ReorderableListView
    final items = <_ListItem>[];
    for (final ex in freeExercises) {
      items.add(_ListItem(
          type: _ItemType.exercise, data: ex));
    }
    for (final c in _circuits) {
      items.add(
          _ListItem(type: _ItemType.circuit, data: c));
    }

    final isEmpty = items.isEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(widget.workoutName),
        actions: [
          GlassTextButton(
            onPressed: _showAddCircuitSheet,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.loop_rounded,
                    size: 16, color: cs.tertiary),
                const SizedBox(width: 4),
                Text('Circuito',
                    style:
                        TextStyle(color: cs.tertiary)),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isEmpty
          ? _EmptyExercisesState(
              onAdd: _showAddExercisesSheet,
              onAddCircuit: _showAddCircuitSheet,
            )
          : ReorderableListView(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 120),
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
              onReorder: _onReorder,
              children: items.asMap().entries.map((e) {
                final index = e.key;
                final item = e.value;

                if (item.type == _ItemType.exercise) {
                  final we =
                      item.data as HiveWorkoutExercise;
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey('ex_${we.key}'),
                    index: index,
                    child: _ExerciseRow(
                      workoutExercise: we,
                      onEdit: () => _showEditSheet(we),
                      onDelete: () =>
                          _confirmDeleteExercise(we),
                    ),
                  );
                } else {
                  final circuit =
                      item.data as HiveCircuit;
                  final circuitTag =
                      '__circuit_${circuit.key}';
                  final circuitExercises =
                      allExercises
                          .where((ex) =>
                              ex.notes == circuitTag)
                          .toList();
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(
                        'circuit_${circuit.key}'),
                    index: index,
                    child: _CircuitCard(
                      circuit: circuit,
                      exercises: circuitExercises,
                      onAddExercise: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MultiProvider(
                              providers: [
                                ChangeNotifierProvider
                                    .value(
                                        value:
                                            _exerciseProvider),
                                ChangeNotifierProvider
                                    .value(
                                        value:
                                            _workoutProvider),
                              ],
                              child:
                                  _SelectExercisesScreen(
                                workoutId: widget.workoutId,
                                circuitKey: circuit.key,
                              ),
                            ),
                          ),
                        );
                      },
                      onEdit: (we) =>
                          _showEditSheet(we),
                      onDelete: (we) =>
                          _confirmDeleteExercise(we),
                      onDeleteCircuit: () =>
                          _confirmDeleteCircuit(circuit),
                      onEditCircuit: () =>
                          _showEditCircuitSheet(circuit),
                      onReorderExercises: (exercises) {
                        _workoutProvider
                            .reorderWorkoutExercises(
                                widget.workoutId,
                                exercises);
                      },
                    ),
                  );
                }
              }).toList(),
            ),
      bottomNavigationBar: !isEmpty
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

// ── Widget helpers ──

class _RoundsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundsButton(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap == null
              ? cs.surfaceContainerHighest.withOpacity(0.3)
              : cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap == null
                ? cs.outlineVariant.withOpacity(0.3)
                : cs.primary.withOpacity(0.3),
          ),
        ),
        child: Icon(icon,
            color: onTap == null
                ? cs.outline.withOpacity(0.3)
                : cs.primary),
      ),
    );
  }
}

class _CircuitCard extends StatelessWidget {
  final HiveCircuit circuit;
  final List<HiveWorkoutExercise> exercises;
  final VoidCallback onAddExercise;
  final void Function(HiveWorkoutExercise) onEdit;
  final void Function(HiveWorkoutExercise) onDelete;
  final VoidCallback onDeleteCircuit;
  final VoidCallback onEditCircuit;
  final void Function(List<HiveWorkoutExercise>)
      onReorderExercises;

  const _CircuitCard({
    required this.circuit,
    required this.exercises,
    required this.onAddExercise,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteCircuit,
    required this.onEditCircuit,
    required this.onReorderExercises,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.loop_rounded,
                      color: cs.onTertiaryContainer,
                      size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(circuit.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: cs.onSurface)),
                      Text(
                          '${circuit.rounds} cicl${circuit.rounds == 1 ? 'o' : 'i'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.tertiary)),
                    ],
                  ),
                ),
                GlassTextButton(
                  onPressed: onEditCircuit,
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: cs.tertiary),
                ),
                GlassTextButton(
                  onPressed: onDeleteCircuit,
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                ),
              ],
            ),
          ),
          if (exercises.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Nessun esercizio nel circuito',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontStyle: FontStyle.italic)),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8),
              proxyDecorator:
                  (child, index, animation) =>
                      AnimatedBuilder(
                animation: animation,
                builder: (_, __) => Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
              ),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final reordered =
                    List<HiveWorkoutExercise>.from(
                        exercises);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                onReorderExercises(reordered);
              },
              children: exercises
                  .asMap()
                  .entries
                  .map((e) =>
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(e.value.key),
                        index: e.key,
                        child: _ExerciseRow(
                          workoutExercise: e.value,
                          onEdit: () => onEdit(e.value),
                          onDelete: () =>
                              onDelete(e.value),
                          compact: true,
                        ),
                      ))
                  .toList(),
            ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: GlassOutlinedButton(
              onPressed: onAddExercise,
              foregroundColor: cs.tertiary,
              borderColor: cs.tertiary.withOpacity(0.4),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.add,
                      size: 16, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Text('Aggiungi esercizio',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.tertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExercisesState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onAddCircuit;
  const _EmptyExercisesState(
      {required this.onAdd, required this.onAddCircuit});

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
            Text('Scheda vuota',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                        fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Aggiungi esercizi o crea un circuito',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.outline)),
            const SizedBox(height: 28),
            GlassButton(
              onTap: onAdd,
              icon: Icons.add_rounded,
              label: 'Aggiungi esercizi',
              minWidth: 220,
            ),
            const SizedBox(height: 12),
            GlassOutlinedButton(
              onPressed: onAddCircuit,
              foregroundColor: cs.tertiary,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.loop_rounded,
                      size: 16, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Text('Crea circuito',
                      style:
                          TextStyle(color: cs.tertiary)),
                ],
              ),
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
  final bool compact;

  const _ExerciseRow({
    super.key,
    required this.workoutExercise,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final we = workoutExercise;
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withOpacity(0.8)
            : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : cs.outlineVariant,
          width: 1.2,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(
                      isDark ? 0.15 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            14, compact ? 10 : 12, 14, compact ? 8 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!compact)
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Text(we.exerciseName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 14 : 15)),
            const SizedBox(height: 2),
            Text(we.muscleGroup,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: cs.outline)),
            const SizedBox(height: 6),
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
                      label: '${we.restSeconds}s rec.'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

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
  final dynamic circuitKey;

  const _SelectExercisesScreen({
    required this.workoutId,
    this.circuitKey,
  });

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
          notes: widget.circuitKey != null
              ? '__circuit_${widget.circuitKey}'
              : ex.notes,
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

    final currentExercises =
        context.read<WorkoutProvider>().currentExercises;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.circuitKey != null
            ? 'Aggiungi al circuito'
            : (_selected.isEmpty
                ? 'Seleziona esercizi'
                : '${_selected.length} selezionati')),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
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
                      final alreadyAdded =
                          currentExercises.any((we) {
                        if (we.exerciseKey != ex.key)
                          return false;
                        if (widget.circuitKey != null) {
                          return we.notes ==
                              '__circuit_${widget.circuitKey}';
                        } else {
                          return !we.isInCircuit;
                        }
                      });

                      return ListTile(
                        leading: alreadyAdded
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary)
                            : Checkbox(
                                value: isSelected,
                                onChanged: (_) =>
                                    _toggle(ex.key),
                              ),
                        title: Text(ex.name,
                            style: TextStyle(
                                color: alreadyAdded
                                    ? Theme.of(context)
                                        .colorScheme
                                        .outline
                                    : null)),
                        subtitle: Text(ex.muscleGroup),
                        trailing: alreadyAdded
                            ? Text('Già aggiunto',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline))
                            : null,
                        enabled: !alreadyAdded,
                        onTap: alreadyAdded
                            ? null
                            : () => _toggle(ex.key),
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
                  MediaQuery.of(context).padding.bottom + 16),
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

class _EditExerciseSheet extends StatefulWidget {
  final HiveWorkoutExercise workoutExercise;
  const _EditExerciseSheet(
      {required this.workoutExercise});

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
    final displayNotes =
        (we.notes != null && we.notes!.startsWith('__circuit_'))
            ? ''
            : we.notes ?? '';
    _notesCtrl =
        TextEditingController(text: displayNotes);
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
    final originalNotes = we.notes;
    final isCircuitNote = originalNotes != null &&
        originalNotes.startsWith('__circuit_');
    final newNotes = isCircuitNote
        ? originalNotes
        : (_notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim());

    final updated = HiveWorkoutExercise(
      workoutKey: we.workoutKey,
      exerciseKey: we.exerciseKey,
      exerciseName: we.exerciseName,
      muscleGroup: we.muscleGroup,
      sets: _series.length,
      targetReps: firstReps,
      targetWeight: firstWeight > 0 ? firstWeight : null,
      restSeconds: int.tryParse(_restCtrl.text),
      notes: newNotes,
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
    final isCircuit =
        widget.workoutExercise.isInCircuit;

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
              Text(widget.workoutExercise.muscleGroup,
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
              if (!isCircuit) ...[
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
              ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
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