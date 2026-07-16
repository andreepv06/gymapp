import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/workout_icon.dart';

// Palette 8 colori — ordine IDENTICO a WorkoutAvatar.
// NON riordinare: gli indici sono salvati in Hive.
// Nuovi colori vanno aggiunti SOLO in fondo.
const _kWorkoutColors = [
  Color(0xFF00D4AA), // 0 teal
  Color(0xFF6366F1), // 1 indigo
  Color(0xFF22C55E), // 2 green
  Color(0xFFF59E0B), // 3 amber
  Color(0xFFEC4899), // 4 pink
  Color(0xFFEF4444), // 5 red
  Color(0xFF3B82F6), // 6 blue
  Color(0xFF8B5CF6), // 7 purple
];

const _kWorkoutIcons = [
  ('dumbbell', Icons.fitness_center_rounded),
  ('bike', Icons.directions_bike_rounded),
  ('run', Icons.directions_run_rounded),
  ('swim', Icons.pool_rounded),
  ('yoga', Icons.self_improvement_rounded),
  ('sports', Icons.sports_rounded),
  ('heart', Icons.favorite_rounded),
  ('star', Icons.star_rounded),
  ('flash', Icons.bolt_rounded),
  ('target', Icons.track_changes_rounded),
  ('mountain', Icons.terrain_rounded),
  ('fire', Icons.local_fire_department_rounded),
];

const _kMuscleGroups = [
  'Tutti', 'Petto', 'Schiena', 'Spalle',
  'Bicipiti', 'Tricipiti', 'Gambe', 'Addominali',
];

const _kCyan   = Color(0xFF00E5FF);
const _kTeal   = Color(0xFF00D4AA);
const _kRed    = Color(0xFFFF1744);
const _kIndigo = Color(0xFF6366F1);
const _kOrange = Color(0xFFFF8C00);

enum _ItemType { exercise, circuit }

class _ListItem {
  final _ItemType type;
  final dynamic refKey;
  _ListItem({required this.type, required this.refKey});
  String get stableId =>
      type == _ItemType.exercise ? 'ex_$refKey' : 'circ_$refKey';
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
  late List<_ListItem> _items;
  late List<HiveCircuit> _circuits;
  HiveWorkout? _workout;
  bool _hasChanges = false;
  late List<_ListItem> _snapshot;
  late Map<dynamic, List<HiveWorkoutExercise>> _circuitChildren;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
    _rebuildAll();
    _snapshot = List.from(_items);
  }

  void _loadWorkout() {
    try {
      _workout = HiveDatabase.instance
          .getWorkouts()
          .firstWhere((w) => w.key == widget.workoutId);
    } catch (_) {
      _workout = null;
    }
  }

  void _rebuildAll() {
    final wp = context.read<WorkoutProvider>();
    final allEx = wp.currentExercises;
    _circuits =
        HiveDatabase.instance.getCircuits(widget.workoutId)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final freeEx = allEx.where((e) => !e.isInCircuit).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final topItems = <({int order, bool isCircuit, dynamic key})>[
      ...freeEx.map((e) => (
            order: e.sortOrder, isCircuit: false, key: e.key as dynamic)),
      ..._circuits.map((c) => (
            order: c.sortOrder, isCircuit: true, key: c.key as dynamic)),
    ]..sort((a, b) => a.order.compareTo(b.order));
    _items = topItems
        .map((i) => _ListItem(
              type: i.isCircuit ? _ItemType.circuit : _ItemType.exercise,
              refKey: i.key,
            ))
        .toList();
    _circuitChildren = {
      for (final c in _circuits)
        c.key: allEx
            .where((e) => e.isInCircuit && e.circuitId == c.key.toString())
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    };
  }

  HiveWorkoutExercise? _findEx(dynamic key) {
    try {
      return context
          .read<WorkoutProvider>()
          .currentExercises
          .firstWhere((e) => e.key == key);
    } catch (_) {
      return null;
    }
  }

  HiveCircuit? _findCircuit(dynamic key) {
    try {
      return _circuits.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistOrder(List<_ListItem> snapshot) async {
    int order = 0;
    for (final item in snapshot) {
      if (item.type == _ItemType.exercise) {
        final we = _findEx(item.refKey);
        if (we == null) continue;
        await HiveDatabase.instance.updateWorkoutExercise(
          we.key,
          HiveWorkoutExercise(
            workoutKey: we.workoutKey,
            exerciseKey: we.exerciseKey,
            exerciseName: we.exerciseName,
            muscleGroup: we.muscleGroup,
            sets: we.sets,
            targetReps: we.targetReps,
            targetWeight: we.targetWeight,
            restSeconds: we.restSeconds,
            notes: we.notes,
            sortOrder: order++,
          ),
        );
      } else {
        final c = _findCircuit(item.refKey);
        if (c == null) continue;
        await HiveDatabase.instance
            .updateCircuitSortOrder(c.key, order++);
      }
    }
    if (mounted) {
      // FIX: variabile locale — evita context.read<T>() spezzato
      // su più righe che causa parse error in dart2js
      final wp = context.read<WorkoutProvider>();
      wp.loadWorkoutExercises(widget.workoutId);
    }
  }

  // FIX 5: _saveAndPop è l'UNICO posto che chiama Navigator.pop.
  // _onWillPop ritorna solo bool, non naviga mai direttamente.
  Future<void> _saveAndPop() async {
    await _persistOrder(_items);
    if (mounted) {
      context.read<WorkoutProvider>().loadWorkouts();
      Navigator.of(context).pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Modifiche non salvate'),
        content: const Text('Vuoi salvare le modifiche alla scheda?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Scarta'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _persistOrder(_items);
      if (mounted) context.read<WorkoutProvider>().loadWorkouts();
      return true;
    }
    if (result == 'discard') {
      await _persistOrder(_snapshot);
      if (mounted) {
        final wp = context.read<WorkoutProvider>();
        wp.loadWorkoutExercises(widget.workoutId);
      }
      return true;
    }
    return false;
  }

  // FIX TASTIERA: AnimatedPadding + ConstrainedBox
  // - AnimatedPadding(150ms) anima il padding quando la tastiera
  //   appare/scompare → nessun salto violento
  // - ConstrainedBox(maxHeight: 85% screen) impedisce che il sheet
  //   superi l'altezza disponibile → il top non sparisce mai
  // - SingleChildScrollView consente lo scroll se il contenuto
  //   è più alto dell'area disponibile
  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddExerciseSheet() async {
    final allExercises = HiveDatabase.instance.getExercises();
    final currentKeys = context
        .read<WorkoutProvider>()
        .currentExercises
        .map((e) => e.exerciseKey)
        .toSet();
    await _openSheet(_AddExercisesToWorkoutSheet(
      allExercises: allExercises,
      alreadyIn: currentKeys,
      onConfirm: (keys) async {
        final existing = context.read<WorkoutProvider>().currentExercises;
        int nextOrder = existing.isEmpty
            ? 0
            : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
        for (final key in keys) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
              workoutKey: widget.workoutId,
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              sets: 3,
              targetReps: 10,
              targetWeight: 0,
              sortOrder: nextOrder++,
            ));
          } catch (_) {}
        }
        if (mounted) {
          final wp = context.read<WorkoutProvider>();
          wp.loadWorkoutExercises(widget.workoutId);
          setState(() { _rebuildAll(); _hasChanges = true; });
          Navigator.pop(context);
        }
      },
    ));
  }

  Future<void> _showAddCircuitSheet() async {
    final allExercises = HiveDatabase.instance.getExercises();
    await _openSheet(_AddCircuitToWorkoutSheet(
      allExercises: allExercises,
      onConfirm: (keys, rounds, name) async {
        final existing = context.read<WorkoutProvider>().currentExercises;
        int nextOrder = existing.isEmpty
            ? 0
            : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
        final circuitKey = await HiveDatabase.instance.addCircuit(HiveCircuit(
          workoutKey: widget.workoutId,
          name: name,
          rounds: rounds,
          sortOrder: nextOrder,
        ));
        int exOrder = 0;
        for (final key in keys) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
              workoutKey: widget.workoutId,
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              sets: 3,
              targetReps: 10,
              targetWeight: 0,
              notes: '__circuit_$circuitKey',
              sortOrder: exOrder++,
            ));
          } catch (_) {}
        }
        if (mounted) {
          final wp = context.read<WorkoutProvider>();
          wp.loadWorkoutExercises(widget.workoutId);
          setState(() { _rebuildAll(); _hasChanges = true; });
          Navigator.pop(context);
        }
      },
    ));
  }

  Future<void> _showEditCircuitSheet(
      HiveCircuit circuit, List<HiveWorkoutExercise> children) async {
    final allExercises = HiveDatabase.instance.getExercises();
    await _openSheet(_EditCircuitSheet(
      circuit: circuit,
      currentChildren: children,
      allExercises: allExercises,
      onConfirm: (rounds, toAdd, toRemove) async {
        // FIX: mutazione diretta + save() — updateCircuitRounds non esiste in HiveDatabase
        if (rounds != circuit.rounds) {
          circuit.rounds = rounds;
          await circuit.save();
        }
        for (final we in toRemove) {
          await HiveDatabase.instance.deleteWorkoutExercise(we.key);
        }
        int nextOrder = children.isEmpty
            ? 0
            : children.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
        for (final key in toAdd) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
              workoutKey: widget.workoutId,
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              sets: 3,
              targetReps: 10,
              targetWeight: 0,
              notes: '__circuit_${circuit.key}',
              sortOrder: nextOrder++,
            ));
          } catch (_) {}
        }
        if (mounted) {
          final wp = context.read<WorkoutProvider>();
          wp.loadWorkoutExercises(widget.workoutId);
          setState(() { _rebuildAll(); _hasChanges = true; });
          Navigator.pop(context);
        }
      },
    ));
  }

  Future<void> _showRenameSheet() async {
    if (_workout == null) return;
    final ctrl = TextEditingController(text: _workout!.name);
    await _openSheet(_RenameSheet(
      controller: ctrl,
      onConfirm: () {
        final name = ctrl.text.trim();
        if (name.isEmpty) return;
        HiveDatabase.instance.updateWorkout(_workout!.key, name);
        setState(() { _workout!.name = name; _hasChanges = true; });
        context.read<WorkoutProvider>().loadWorkouts();
        Navigator.pop(context);
      },
    ));
  }

  // FIX 1: salvataggio icona/colore con mutazione diretta + save()
  // Il colorIndex salvato è l'indice in _kWorkoutColors, che è la
  // stessa palette usata da WorkoutAvatar → sincronizzazione garantita.
  Future<void> _showIconColorSheet() async {
    if (_workout == null) return;
    await _openSheet(_IconColorSheet(
      currentIconId: _workout!.iconId ?? 'dumbbell',
      // clamp difensivo: protegge da dati salvati con palette diversa
      currentColorIndex: (_workout!.iconColorIndex ?? 0)
          .clamp(0, _kWorkoutColors.length - 1),
      onSelect: (iconId, colorIndex) {
        // Mutazione diretta sull'oggetto HiveObject + save()
        _workout!.iconId = iconId;
        _workout!.iconColorIndex = colorIndex;
        _workout!.save();
        // setState aggiorna il WorkoutHeader immediatamente
        setState(() => _hasChanges = true);
        // loadWorkouts aggiorna il Provider per carosello/lista
        context.read<WorkoutProvider>().loadWorkouts();
        Navigator.pop(context);
      },
    ));
  }

  Future<void> _removeExercise(dynamic key) async {
    final we = _findEx(key);
    if (we == null) return;
    await HiveDatabase.instance.deleteWorkoutExercise(we.key);
    if (mounted) {
      final wp = context.read<WorkoutProvider>();
      wp.loadWorkoutExercises(widget.workoutId);
      setState(() { _rebuildAll(); _hasChanges = true; });
    }
  }

  Future<void> _removeCircuit(dynamic circuitKey) async {
    final children = _circuitChildren[circuitKey] ?? [];
    for (final ex in children) {
      await HiveDatabase.instance.deleteWorkoutExercise(ex.key);
    }
    await HiveDatabase.instance.deleteCircuit(circuitKey);
    if (mounted) {
      final wp = context.read<WorkoutProvider>();
      wp.loadWorkoutExercises(widget.workoutId);
      setState(() { _rebuildAll(); _hasChanges = true; });
    }
  }

  Future<void> _editExerciseParams(HiveWorkoutExercise we) async {
    await _openSheet(_EditParamsSheet(
      exercise: we,
      onConfirm: (sets, reps, weight, rest) async {
        await HiveDatabase.instance.updateWorkoutExercise(
          we.key,
          HiveWorkoutExercise(
            workoutKey: we.workoutKey,
            exerciseKey: we.exerciseKey,
            exerciseName: we.exerciseName,
            muscleGroup: we.muscleGroup,
            sets: sets,
            targetReps: reps,
            targetWeight: weight,
            restSeconds: rest,
            notes: we.notes,
            sortOrder: we.sortOrder,
          ),
        );
        if (mounted) {
          final wp = context.read<WorkoutProvider>();
          wp.loadWorkoutExercises(widget.workoutId);
          setState(() { _rebuildAll(); _hasChanges = true; });
          Navigator.pop(context);
        }
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _items.isEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // FIX 5: UN SOLO POP — eseguito qui, _onWillPop non naviga mai
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF03040A),
        body: CosmicBackground(
          subtle: true,
          child: SafeArea(
            child: Column(
              children: [
                _WorkoutHeader(
                  workout: _workout,
                  hasChanges: _hasChanges,
                  onBack: () async {
                    final canPop = await _onWillPop();
                    if (canPop && mounted) Navigator.of(context).pop();
                  },
                  onRename: _showRenameSheet,
                  onIconColor: _showIconColorSheet,
                  onSave: _hasChanges ? _saveAndPop : null,
                ),
                const SizedBox(height: 8),
                // FIX 6: bottoni rapidi SOLO se scheda non è vuota
                if (!isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: '+ Esercizio',
                            icon: Icons.fitness_center_rounded,
                            color: _kTeal,
                            onTap: _showAddExerciseSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            label: '+ Circuito',
                            icon: Icons.loop_rounded,
                            color: _kIndigo,
                            onTap: _showAddCircuitSheet,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: isEmpty
                      ? _EmptyWorkoutState(
                          onAddExercise: _showAddExerciseSheet,
                          onAddCircuit: _showAddCircuitSheet,
                        )
                      : ReorderableListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          buildDefaultDragHandles: false,
                          physics: const BouncingScrollPhysics(),
                          proxyDecorator: (child, i, anim) => AnimatedBuilder(
                            animation: anim,
                            builder: (_, __) => Material(
                              elevation: 10,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: child,
                            ),
                          ),
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            setState(() {
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                              _hasChanges = true;
                            });
                            HapticFeedback.selectionClick();
                          },
                          children: _items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            if (item.type == _ItemType.exercise) {
                              final we = _findEx(item.refKey);
                              if (we == null) {
                                return SizedBox.shrink(key: ValueKey(item.stableId));
                              }
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(item.stableId),
                                index: idx,
                                child: _ExerciseCard(
                                  exercise: we,
                                  onEdit: () => _editExerciseParams(we),
                                  onDelete: () => _removeExercise(item.refKey),
                                ),
                              );
                            } else {
                              final c = _findCircuit(item.refKey);
                              final children = _circuitChildren[item.refKey] ?? [];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(item.stableId),
                                index: idx,
                                child: _CircuitCard(
                                  circuit: c,
                                  exercises: children,
                                  onEditCircuit: c == null
                                      ? () {}
                                      : () => _showEditCircuitSheet(c, children),
                                  onEditExercise: (we) => _editExerciseParams(we),
                                  onRemoveExercise: (weKey) => _removeExercise(weKey),
                                  onDelete: () => _removeCircuit(item.refKey),
                                  onReorderExercises: (reordered) async {
                                    for (int i = 0; i < reordered.length; i++) {
                                      await HiveDatabase.instance.updateWorkoutExercise(
                                        reordered[i].key,
                                        HiveWorkoutExercise(
                                          workoutKey: reordered[i].workoutKey,
                                          exerciseKey: reordered[i].exerciseKey,
                                          exerciseName: reordered[i].exerciseName,
                                          muscleGroup: reordered[i].muscleGroup,
                                          sets: reordered[i].sets,
                                          targetReps: reordered[i].targetReps,
                                          targetWeight: reordered[i].targetWeight,
                                          restSeconds: reordered[i].restSeconds,
                                          notes: reordered[i].notes,
                                          sortOrder: i,
                                        ),
                                      );
                                    }
                                    if (mounted) {
                                      // FIX compilazione: variabile locale
                                      // evita context.read<T>() su più righe
                                      final wp = context.read<WorkoutProvider>();
                                      wp.loadWorkoutExercises(widget.workoutId);
                                      setState(() {
                                        _rebuildAll();
                                        _hasChanges = true;
                                      });
                                    }
                                  },
                                ),
                              );
                            }
                          }).toList(),
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
// _WorkoutHeader
// ─────────────────────────────────────────────────────────────

class _WorkoutHeader extends StatelessWidget {
  final HiveWorkout? workout;
  final bool hasChanges;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onIconColor;
  final VoidCallback? onSave;
  const _WorkoutHeader({
    required this.workout,
    required this.hasChanges,
    required this.onBack,
    required this.onRename,
    required this.onIconColor,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
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
              border: Border.all(
                color: hasChanges
                    ? _kOrange.withOpacity(0.5)
                    : _kCyan.withOpacity(0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 15),
                  ),
                ),
                const SizedBox(width: 12),
                // FIX 1: icona tap → picker. WorkoutAvatar usa
                // workout.iconColorIndex che è l'indice in _kWorkoutColors
                GestureDetector(
                  onTap: onIconColor,
                  child: Stack(
                    children: [
                      WorkoutAvatar(
                        iconId: workout?.iconId ?? 'dumbbell',
                        iconColorIndex: workout?.iconColorIndex ?? 0,
                        size: 46,
                        iconSize: 23,
                        borderRadius: 12,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: _kCyan,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF03040A), width: 1.5),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 9, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onRename,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workout?.name ?? 'Scheda',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_rounded,
                                size: 12,
                                color: _kCyan.withOpacity(0.5)),
                          ],
                        ),
                        Text(
                          hasChanges
                              ? 'Modifiche non salvate'
                              : 'Modifica scheda',
                          style: TextStyle(
                            color: hasChanges
                                ? _kOrange.withOpacity(0.8)
                                : Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasChanges
                            ? [_kTeal, const Color(0xFF00A880)]
                            : [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.04),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasChanges
                            ? _kTeal.withOpacity(0.5)
                            : Colors.white.withOpacity(0.12),
                      ),
                      boxShadow: hasChanges
                          ? [
                              BoxShadow(
                                color: _kTeal.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      'Salva',
                      style: TextStyle(
                        color: hasChanges
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
// _EmptyWorkoutState
// ─────────────────────────────────────────────────────────────

class _EmptyWorkoutState extends StatelessWidget {
  final VoidCallback onAddExercise;
  final VoidCallback onAddCircuit;
  const _EmptyWorkoutState({
    required this.onAddExercise,
    required this.onAddCircuit,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _kCyan.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: _kCyan.withOpacity(0.12), blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 40, color: _kTeal),
            ),
            const SizedBox(height: 22),
            const Text(
              'Scheda vuota',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aggiungi esercizi o crea un circuito\nper iniziare a configurare la scheda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Aggiungi esercizi',
                    icon: Icons.add_rounded,
                    color: _kTeal,
                    onTap: onAddExercise,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: 'Crea circuito',
                    icon: Icons.loop_rounded,
                    color: _kIndigo,
                    onTap: onAddCircuit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActionBtn
// ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.4), width: 1),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseCard
// ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final HiveWorkoutExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ExerciseCard({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _kCyan.withOpacity(0.15), width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.drag_handle_rounded,
                      size: 18, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _kTeal.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.fitness_center_rounded,
                        color: _kTeal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.exerciseName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          children: [
                            _Tag('${exercise.sets} x ${exercise.targetReps}'),
                            if ((exercise.targetWeight ?? 0) > 0)
                              _Tag('${exercise.targetWeight} kg'),
                            if ((exercise.restSeconds ?? 0) > 0)
                              _Tag('${exercise.restSeconds}s rec.'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.tune_rounded,
                    color: Colors.white.withOpacity(0.45),
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: _kRed.withOpacity(0.7),
                    onTap: onDelete,
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

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kCyan.withOpacity(0.2), width: 0.7),
      ),
      child: Text(label,
          style: TextStyle(
              color: _kCyan.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitCard
// ─────────────────────────────────────────────────────────────

class _CircuitCard extends StatelessWidget {
  final HiveCircuit? circuit;
  final List<HiveWorkoutExercise> exercises;
  final VoidCallback onEditCircuit;
  final void Function(HiveWorkoutExercise) onEditExercise;
  final void Function(dynamic) onRemoveExercise;
  final VoidCallback onDelete;
  final void Function(List<HiveWorkoutExercise>) onReorderExercises;
  const _CircuitCard({
    required this.circuit,
    required this.exercises,
    required this.onEditCircuit,
    required this.onEditExercise,
    required this.onRemoveExercise,
    required this.onDelete,
    required this.onReorderExercises,
  });
  @override
  Widget build(BuildContext context) {
    final rounds = circuit?.rounds ?? 1;
    final name = circuit?.name ?? 'Circuito';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kIndigo.withOpacity(0.12),
                  _kIndigo.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kIndigo.withOpacity(0.4), width: 1),
              boxShadow: [
                BoxShadow(color: _kIndigo.withOpacity(0.1), blurRadius: 20)
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 18, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.loop_rounded,
                            color: _kIndigo, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '$rounds cicl${rounds == 1 ? 'o' : 'i'} · ${exercises.length} esercizi',
                              style: TextStyle(
                                  color: _kIndigo.withOpacity(0.8),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onEditCircuit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kIndigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kIndigo.withOpacity(0.35)),
                          ),
                          child: const Text('Modifica',
                              style: TextStyle(
                                  color: _kIndigo,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kRed.withOpacity(0.3)),
                          ),
                          child: const Text('Elimina',
                              style: TextStyle(
                                  color: _kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.7,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      _kIndigo.withOpacity(0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
                if (exercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('Nessun esercizio',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (oldIdx, newIdx) {
                        if (newIdx > oldIdx) newIdx--;
                        final r = List<HiveWorkoutExercise>.from(exercises);
                        final item = r.removeAt(oldIdx);
                        r.insert(newIdx, item);
                        onReorderExercises(r);
                      },
                      children: exercises.asMap().entries.map((e) {
                        final we = e.value;
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(we.key),
                          index: e.key,
                          child: _ExerciseCard(
                            exercise: we,
                            onEdit: () => onEditExercise(we),
                            onDelete: () => onRemoveExercise(we.key),
                          ),
                        );
                      }).toList(),
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
// Sheet: _AddExercisesToWorkoutSheet
// ─────────────────────────────────────────────────────────────

class _AddExercisesToWorkoutSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final Set<dynamic> alreadyIn;
  final void Function(Set<dynamic>) onConfirm;
  const _AddExercisesToWorkoutSheet({
    required this.allExercises,
    required this.alreadyIn,
    required this.onConfirm,
  });
  @override
  State<_AddExercisesToWorkoutSheet> createState() =>
      _AddExercisesToWorkoutSheetState();
}

class _AddExercisesToWorkoutSheetState
    extends State<_AddExercisesToWorkoutSheet> {
  String _search = '';
  String _muscle = 'Tutti';
  final Set<dynamic> _selected = {};
  @override
  Widget build(BuildContext context) {
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()
      ..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(_search.toLowerCase()) ||
              e.muscleGroup.toLowerCase().contains(_search.toLowerCase()));
    }).toList();
    return _SheetWrapper(
      title: 'Aggiungi esercizi',
      subtitle: _selected.isEmpty ? null : '${_selected.length} selezionati',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
            prefix: Icon(Icons.search_rounded,
                size: 16, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 10),
          _MuscleFilterChips(
            groups: groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isIn = widget.alreadyIn.contains(ex.key);
                final isSel = _selected.contains(ex.key);
                return _ExerciseListTile(
                  exercise: ex,
                  isAlreadyIn: isIn,
                  isSelected: isSel,
                  onTap: isIn
                      ? null
                      : () => setState(() {
                            if (isSel) _selected.remove(ex.key);
                            else _selected.add(ex.key);
                          }),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            _GlassButton(
              label: 'Aggiungi ${_selected.length} esercizi',
              color: _kTeal,
              onTap: () => widget.onConfirm(_selected),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _AddCircuitToWorkoutSheet
// ─────────────────────────────────────────────────────────────

class _AddCircuitToWorkoutSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final void Function(Set<dynamic> keys, int rounds, String name) onConfirm;
  const _AddCircuitToWorkoutSheet({
    required this.allExercises,
    required this.onConfirm,
  });
  @override
  State<_AddCircuitToWorkoutSheet> createState() =>
      _AddCircuitToWorkoutSheetState();
}

class _AddCircuitToWorkoutSheetState
    extends State<_AddCircuitToWorkoutSheet> {
  String _search = '';
  String _muscle = 'Tutti';
  final Set<dynamic> _selected = {};
  int _rounds = 3;
  final _nameCtrl = TextEditingController(text: 'Circuito');
  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()
      ..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(_search.toLowerCase()));
    }).toList();
    return _SheetWrapper(
      title: 'Nuovo circuito',
      accentColor: _kIndigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassField(
            controller: _nameCtrl,
            hintText: 'Nome circuito...',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          _RoundsControl(
            rounds: _rounds,
            onChanged: (v) => setState(() => _rounds = v),
          ),
          const SizedBox(height: 12),
          _GlassField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
            prefix: Icon(Icons.search_rounded,
                size: 16, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 10),
          _MuscleFilterChips(
            groups: groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isSel = _selected.contains(ex.key);
                return _ExerciseListTile(
                  exercise: ex,
                  isAlreadyIn: false,
                  isSelected: isSel,
                  onTap: () => setState(() {
                    if (isSel) _selected.remove(ex.key);
                    else _selected.add(ex.key);
                  }),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            _GlassButton(
              label: 'Crea · ${_selected.length} esercizi · $_rounds cicli',
              color: _kIndigo,
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
// Sheet: _EditCircuitSheet
// ─────────────────────────────────────────────────────────────

class _EditCircuitSheet extends StatefulWidget {
  final HiveCircuit circuit;
  final List<HiveWorkoutExercise> currentChildren;
  final List<HiveExercise> allExercises;
  final void Function(int rounds, Set<dynamic> toAdd,
      List<HiveWorkoutExercise> toRemove) onConfirm;
  const _EditCircuitSheet({
    required this.circuit,
    required this.currentChildren,
    required this.allExercises,
    required this.onConfirm,
  });
  @override
  State<_EditCircuitSheet> createState() => _EditCircuitSheetState();
}

class _EditCircuitSheetState extends State<_EditCircuitSheet> {
  late int _rounds;
  String _search = '';
  String _muscle = 'Tutti';
  late Set<dynamic> _existingKeys;
  final Set<dynamic> _toAdd = {};
  final Set<dynamic> _toRemove = {};
  @override
  void initState() {
    super.initState();
    _rounds = widget.circuit.rounds;
    _existingKeys = widget.currentChildren.map((e) => e.exerciseKey).toSet();
  }
  @override
  Widget build(BuildContext context) {
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()
      ..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(_search.toLowerCase()));
    }).toList();
    final hasChanges = _rounds != widget.circuit.rounds ||
        _toAdd.isNotEmpty ||
        _toRemove.isNotEmpty;
    return _SheetWrapper(
      title: 'Modifica circuito',
      subtitle: widget.circuit.name,
      accentColor: _kIndigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundsControl(
            rounds: _rounds,
            onChanged: (v) => setState(() => _rounds = v),
          ),
          const SizedBox(height: 12),
          _GlassField(
            hintText: 'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
            prefix: Icon(Icons.search_rounded,
                size: 16, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 10),
          _MuscleFilterChips(
            groups: groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isExisting =
                    _existingKeys.contains(ex.key) && !_toRemove.contains(ex.key);
                final isMarkedRemove = _toRemove.contains(ex.key);
                final isMarkedAdd = _toAdd.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: isExisting
                      ? GestureDetector(
                          onTap: () => setState(() => _toRemove.add(ex.key)),
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                                color: _kTeal,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          ),
                        )
                      : isMarkedRemove
                          ? GestureDetector(
                              onTap: () =>
                                  setState(() => _toRemove.remove(ex.key)),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: _kRed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _kRed, width: 1.2),
                                ),
                                child: const Icon(Icons.remove_rounded,
                                    size: 14, color: _kRed),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => setState(() {
                                if (isMarkedAdd) _toAdd.remove(ex.key);
                                else if (!_existingKeys.contains(ex.key))
                                  _toAdd.add(ex.key);
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isMarkedAdd ? _kIndigo : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMarkedAdd
                                        ? _kIndigo
                                        : Colors.white.withOpacity(0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: isMarkedAdd
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                  title: Text(ex.name,
                      style: TextStyle(
                          color: isMarkedRemove
                              ? Colors.white.withOpacity(0.35)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isMarkedRemove
                              ? TextDecoration.lineThrough
                              : null)),
                  subtitle: Text(ex.muscleGroup,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                );
              },
            ),
          ),
          if (hasChanges) ...[
            const SizedBox(height: 10),
            _GlassButton(
              label: 'Salva modifiche',
              color: _kIndigo,
              onTap: () {
                final toRemoveList = widget.currentChildren
                    .where((c) => _toRemove.contains(c.exerciseKey))
                    .toList();
                widget.onConfirm(_rounds, _toAdd, toRemoveList);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _RenameSheet
// ─────────────────────────────────────────────────────────────

class _RenameSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _RenameSheet(
      {required this.controller, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: 'Rinomina scheda',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassField(
            controller: controller,
            hintText: 'Nome scheda...',
            autofocus: true,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          _GlassButton(label: 'Rinomina', color: _kTeal, onTap: onConfirm),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _IconColorSheet — FIX 1 sincronizzazione icona/colore
// ─────────────────────────────────────────────────────────────

class _IconColorSheet extends StatefulWidget {
  final String currentIconId;
  final int currentColorIndex;
  final void Function(String iconId, int colorIndex) onSelect;
  const _IconColorSheet({
    required this.currentIconId,
    required this.currentColorIndex,
    required this.onSelect,
  });
  @override
  State<_IconColorSheet> createState() => _IconColorSheetState();
}

class _IconColorSheetState extends State<_IconColorSheet> {
  late String _iconId;
  late int _colorIndex;

  @override
  void initState() {
    super.initState();
    // FIX 1: carica valori da Hive con clamp difensivo
    _iconId = widget.currentIconId;
    _colorIndex = widget.currentColorIndex
        .clamp(0, _kWorkoutColors.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _kWorkoutColors[_colorIndex];
    return _SheetWrapper(
      title: 'Icona e colore',
      accentColor: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anteprima live: legge _iconId e _colorIndex da stato locale
          // setState() su tap colore/icona → rebuild → anteprima aggiornata
          Center(
            child: Column(
              children: [
                WorkoutAvatar(
                  iconId: _iconId,
                  iconColorIndex: _colorIndex,
                  size: 70,
                  iconSize: 34,
                  borderRadius: 18,
                ),
                const SizedBox(height: 6),
                Text('Anteprima',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Colore',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kWorkoutColors.asMap().entries.map((e) {
              final sel = e.key == _colorIndex;
              return GestureDetector(
                // FIX 1: setState aggiorna _colorIndex → WorkoutAvatar ricostruito
                onTap: () => setState(() => _colorIndex = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: sel
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(color: Colors.transparent),
                    boxShadow: sel
                        ? [BoxShadow(color: e.value.withOpacity(0.6), blurRadius: 10)]
                        : null,
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text('Icona',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kWorkoutIcons.map((icon) {
              final sel = icon.$1 == _iconId;
              return GestureDetector(
                // FIX 1: setState aggiorna _iconId → WorkoutAvatar ricostruito
                onTap: () => setState(() => _iconId = icon.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: sel ? accent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? accent.withOpacity(0.6) : Colors.white.withOpacity(0.1),
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 8)]
                        : null,
                  ),
                  child: Icon(icon.$2,
                      color: sel ? accent : Colors.white.withOpacity(0.45),
                      size: 22),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          // FIX 1: onSelect riceve i valori CORRENTI dello stato locale
          // che sono quelli mostrati nell'anteprima → garanzia di coerenza
          _GlassButton(
            label: 'Applica',
            color: accent,
            onTap: () => widget.onSelect(_iconId, _colorIndex),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _EditParamsSheet
// ─────────────────────────────────────────────────────────────

class _EditParamsSheet extends StatefulWidget {
  final HiveWorkoutExercise exercise;
  final void Function(int sets, int reps, double weight, int? rest) onConfirm;
  const _EditParamsSheet(
      {required this.exercise, required this.onConfirm});
  @override
  State<_EditParamsSheet> createState() => _EditParamsSheetState();
}

class _EditParamsSheetState extends State<_EditParamsSheet> {
  late int _sets;
  late int _reps;
  late double _weight;
  late int _rest;
  @override
  void initState() {
    super.initState();
    _sets = widget.exercise.sets;
    _reps = widget.exercise.targetReps;
    _weight = widget.exercise.targetWeight ?? 0;
    _rest = widget.exercise.restSeconds ?? 60;
  }
  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: widget.exercise.exerciseName,
      subtitle: 'Parametri esercizio',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IntRow(label: 'Serie', value: _sets, min: 1, max: 20,
              onChanged: (v) => setState(() => _sets = v)),
          _IntRow(label: 'Ripetizioni', value: _reps, min: 1, max: 100,
              onChanged: (v) => setState(() => _reps = v)),
          _IntRow(label: 'Recupero (sec)', value: _rest, min: 0, max: 600,
              step: 15, onChanged: (v) => setState(() => _rest = v)),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Text('Peso (kg)',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _weight > 0 ? _weight.toString() : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kCyan.withOpacity(0.3))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) =>
                        setState(() => _weight = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
          ),
          _GlassButton(
            label: 'Salva parametri',
            color: _kTeal,
            onTap: () => widget.onConfirm(
                _sets, _reps, _weight, _rest > 0 ? _rest : null),
          ),
        ],
      ),
    );
  }
}

class _IntRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;
  const _IntRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          _RoundBtn(
            icon: Icons.remove_rounded,
            onTap: (value - step >= min) ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 48,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          _RoundBtn(
            icon: Icons.add_rounded,
            onTap: (value + step <= max) ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

// FIX 4: rounds senza limite massimo
class _RoundsControl extends StatelessWidget {
  final int rounds;
  final void Function(int) onChanged;
  const _RoundsControl({required this.rounds, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Cicli:',
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        _RoundBtn(
          icon: Icons.remove_rounded,
          onTap: rounds > 1 ? () => onChanged(rounds - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text('$rounds',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        _RoundBtn(icon: Icons.add_rounded, onTap: () => onChanged(rounds + 1)),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? _kCyan.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? _kCyan.withOpacity(0.4) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? _kCyan : Colors.white.withOpacity(0.2)),
      ),
    );
  }
}

class _MuscleFilterChips extends StatelessWidget {
  final List<String> groups;
  final String selected;
  final void Function(String) onSelect;
  const _MuscleFilterChips({
    required this.groups,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final g = groups[i];
          final sel = selected == g;
          return GestureDetector(
            onTap: () => onSelect(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? _kTeal.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? _kTeal.withOpacity(0.6) : Colors.white.withOpacity(0.1),
                  width: sel ? 1.2 : 0.8,
                ),
                boxShadow: sel
                    ? [BoxShadow(color: _kTeal.withOpacity(0.15), blurRadius: 8)]
                    : null,
              ),
              child: Text(g,
                  style: TextStyle(
                      color: sel ? _kTeal : Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

class _SheetWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;
  const _SheetWrapper({
    required this.title,
    this.subtitle,
    required this.child,
    this.accentColor = _kTeal,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060B14), Color(0xFF03040A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor.withOpacity(0.3),
                  accentColor.withOpacity(0.6),
                  accentColor.withOpacity(0.3),
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: accentColor.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final Widget? prefix;
  final void Function(String) onChanged;
  final bool autofocus;
  const _GlassField({
    this.controller,
    required this.hintText,
    this.prefix,
    required this.onChanged,
    this.autofocus = false,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kCyan.withOpacity(0.2), width: 0.8),
          ),
          child: TextFormField(
            controller: controller,
            autofocus: autofocus,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14),
              prefixIcon: prefix != null
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: prefix)
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlassButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.2) ?? color],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ),
    );
  }
}

class _ExerciseListTile extends StatelessWidget {
  final HiveExercise exercise;
  final bool isAlreadyIn;
  final bool isSelected;
  final VoidCallback? onTap;
  const _ExerciseListTile({
    required this.exercise,
    required this.isAlreadyIn,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: isAlreadyIn
          ? Icon(Icons.check_circle, color: _kTeal.withOpacity(0.6), size: 20)
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isSelected ? _kTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? _kTeal
                      : Colors.white.withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
      title: Text(exercise.name,
          style: TextStyle(
              color: isAlreadyIn
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      subtitle: Text(exercise.muscleGroup,
          style: TextStyle(
              color: Colors.white.withOpacity(0.4), fontSize: 11)),
      enabled: !isAlreadyIn,
      onTap: onTap,
    );
  }
}