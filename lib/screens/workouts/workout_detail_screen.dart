import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/jarvis_theme.dart';
import '../../widgets/workout_icon.dart';

// ─────────────────────────────────────────────────────────────
// WorkoutDetailScreen — Modifica struttura scheda
//
// Responsabilità:
//   - header Glass con modifica nome/icona/colore (FIX 4)
//   - lista esercizi drag & drop (invariata)
//   - aggiunta esercizi e circuiti alla SCHEDA (persistente)
//   - salvataggio ordine su Hive
// NON modifica la sessione attiva.
// ─────────────────────────────────────────────────────────────

enum _ItemType { exercise, circuit }

class _ListItem {
  final _ItemType type;
  final dynamic refKey;

  _ListItem({required this.type, required this.refKey});

  String get stableId => type == _ItemType.exercise
      ? 'ex_$refKey'
      : 'circ_$refKey';
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
  late HiveWorkout? _workout;
  bool _hasChanges = false;

  // Snapshot per discard
  late List<_ListItem> _snapshotItems;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
    _rebuildAll();
    _snapshotItems = List.from(_items);
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
    final allEx = context
        .read<WorkoutProvider>()
        .currentExercises;
    _circuits =
        HiveDatabase.instance.getCircuits(widget.workoutId)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // FIX 2: ordine interleaved per sortOrder unificato
    final freeEx =
        allEx.where((e) => !e.isInCircuit).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final topItems = <({int order, bool isCircuit, dynamic key})>[
      ...freeEx.map((e) =>
          (order: e.sortOrder, isCircuit: false, key: e.key as dynamic)),
      ..._circuits.map((c) =>
          (order: c.sortOrder, isCircuit: true, key: c.key as dynamic)),
    ]..sort((a, b) => a.order.compareTo(b.order));

    _items = topItems
        .map((item) => _ListItem(
              type: item.isCircuit
                  ? _ItemType.circuit
                  : _ItemType.exercise,
              refKey: item.key,
            ))
        .toList();

    _circuitChildren = {
      for (final c in _circuits)
        c.key: allEx
            .where((e) =>
                e.isInCircuit && e.circuitId == c.key.toString())
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    };
  }

  late Map<dynamic, List<HiveWorkoutExercise>>
      _circuitChildren = {};

  HiveWorkoutExercise? _findExercise(dynamic key) {
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

  // ── Salvataggio ordine (FIX 2) ───────────────────────────

  Future<void> _persistTopLevelOrder(
      List<_ListItem> snapshot) async {
    int unifiedOrder = 0;
    for (final item in snapshot) {
      if (item.type == _ItemType.exercise) {
        final we = _findExercise(item.refKey);
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
            sortOrder: unifiedOrder++,
          ),
        );
      } else {
        final c = _findCircuit(item.refKey);
        if (c == null) continue;
        await HiveDatabase.instance
            .updateCircuitSortOrder(c.key, unifiedOrder++);
      }
    }
    context.read<WorkoutProvider>()
        .loadWorkoutExercises(widget.workoutId);
  }

  // ── Salva tutto ───────────────────────────────────────────

  Future<void> _saveAll() async {
    await _persistTopLevelOrder(_items);
    _hasChanges = false;
    if (mounted) Navigator.of(context).pop();
  }

  // ── Discard ───────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Modifiche non salvate'),
        content: const Text(
            'Vuoi salvare le modifiche alla scheda?'),
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
      await _saveAll();
      return true;
    }
    if (result == 'discard') {
      // Ripristina ordine snapshot
      await _persistTopLevelOrder(_snapshotItems);
      return true;
    }
    return false;
  }

  // ── Aggiunge esercizio alla scheda ────────────────────────

  Future<void> _showAddExerciseSheet() async {
    final allExercises =
        HiveDatabase.instance.getExercises();
    final currentKeys = context
        .read<WorkoutProvider>()
        .currentExercises
        .map((e) => e.exerciseKey)
        .toSet();

    await showJarvisSheet(
      context,
      child: _AddExercisesToWorkoutSheet(
        allExercises: allExercises,
        alreadyIn: currentKeys,
        onConfirm: (selectedKeys) async {
          final existing = context
              .read<WorkoutProvider>()
              .currentExercises;
          int nextOrder = existing.isEmpty
              ? 0
              : existing
                  .map((e) => e.sortOrder)
                  .reduce((a, b) => a > b ? a : b) + 1;

          for (final key in selectedKeys) {
            final ex = allExercises
                .firstWhere((e) => e.key == key);
            await HiveDatabase.instance
                .addWorkoutExercise(HiveWorkoutExercise(
              workoutKey: widget.workoutId,
              exerciseKey: ex.key,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              sets: 3,
              targetReps: 10,
              targetWeight: 0,
              sortOrder: nextOrder++,
            ));
          }

          if (mounted) {
            context
                .read<WorkoutProvider>()
                .loadWorkoutExercises(widget.workoutId);
            setState(() {
              _rebuildAll();
              _hasChanges = true;
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ── Aggiunge circuito alla scheda ────────────────────────

  Future<void> _showAddCircuitSheet() async {
    final allExercises =
        HiveDatabase.instance.getExercises();
    final currentKeys = context
        .read<WorkoutProvider>()
        .currentExercises
        .where((e) => e.isInCircuit)
        .map((e) => e.exerciseKey)
        .toSet();

    await showJarvisSheet(
      context,
      child: _AddCircuitToWorkoutSheet(
        allExercises: allExercises,
        alreadyInCircuit: currentKeys,
        onConfirm: (selectedKeys, rounds, name) async {
          // Crea il circuito su Hive
          final existing = context
              .read<WorkoutProvider>()
              .currentExercises;
          int nextOrder = existing.isEmpty
              ? 0
              : existing
                  .map((e) => e.sortOrder)
                  .reduce((a, b) => a > b ? a : b) + 1;

          final circuitKey =
              await HiveDatabase.instance.addCircuit(
            HiveCircuit(
              workoutKey: widget.workoutId,
              name: name,
              rounds: rounds,
              sortOrder: nextOrder,
            ),
          );

          int exOrder = 0;
          for (final key in selectedKeys) {
            final ex = allExercises
                .firstWhere((e) => e.key == key);
            await HiveDatabase.instance.addWorkoutExercise(
              HiveWorkoutExercise(
                workoutKey: widget.workoutId,
                exerciseKey: ex.key,
                exerciseName: ex.name,
                muscleGroup: ex.muscleGroup,
                sets: 3,
                targetReps: 10,
                targetWeight: 0,
                notes: '__circuit_$circuitKey',
                sortOrder: exOrder++,
              ),
            );
          }

          if (mounted) {
            context
                .read<WorkoutProvider>()
                .loadWorkoutExercises(widget.workoutId);
            setState(() {
              _rebuildAll();
              _hasChanges = true;
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ── FIX 4: modifica nome scheda ───────────────────────────

  Future<void> _showRenameSheet() async {
    if (_workout == null) return;
    final ctrl =
        TextEditingController(text: _workout!.name);
    await showJarvisSheet(
      context,
      child: _RenameWorkoutSheet(
        controller: ctrl,
        onConfirm: () {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          HiveDatabase.instance.updateWorkout(
              _workout!.key, name);
          setState(() {
            _workout!.name = name;
            _hasChanges = true;
          });
          context.read<WorkoutProvider>().loadWorkouts();
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── FIX 4: modifica icona e colore ───────────────────────

  Future<void> _showIconColorSheet() async {
    if (_workout == null) return;
    await showJarvisSheet(
      context,
      child: _IconColorSheet(
        currentIconId: _workout!.iconId ?? 'dumbbell',
        currentColorIndex: _workout!.iconColorIndex ?? 0,
        onSelect: (iconId, colorIndex) {
          // FIX: mutazione diretta + save() su Hive
          _workout!.iconId = iconId;
          _workout!.iconColorIndex = colorIndex;
          _workout!.save();
          setState(() => _hasChanges = true);
          context.read<WorkoutProvider>().loadWorkouts();
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Elimina esercizio dalla scheda ────────────────────────

  Future<void> _removeExercise(dynamic key) async {
    final we = _findExercise(key);
    if (we == null) return;
    await HiveDatabase.instance
        .deleteWorkoutExercise(we.key);
    if (mounted) {
      context
          .read<WorkoutProvider>()
          .loadWorkoutExercises(widget.workoutId);
      setState(() {
        _rebuildAll();
        _hasChanges = true;
      });
    }
  }

  // ── Elimina circuito dalla scheda ─────────────────────────

  Future<void> _removeCircuit(dynamic circuitKey) async {
    // Rimuovi esercizi del circuito
    final children = _circuitChildren[circuitKey] ?? [];
    for (final ex in children) {
      await HiveDatabase.instance
          .deleteWorkoutExercise(ex.key);
    }
    // Rimuovi il circuito
    await HiveDatabase.instance.deleteCircuit(circuitKey);
    if (mounted) {
      context
          .read<WorkoutProvider>()
          .loadWorkoutExercises(widget.workoutId);
      setState(() {
        _rebuildAll();
        _hasChanges = true;
      });
    }
  }

  // ── Modifica parametri esercizio ─────────────────────────

  Future<void> _editExerciseParams(
      HiveWorkoutExercise we) async {
    await showJarvisSheet(
      context,
      child: _EditExerciseParamsSheet(
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
            context
                .read<WorkoutProvider>()
                .loadWorkoutExercises(widget.workoutId);
            setState(() {
              _rebuildAll();
              _hasChanges = true;
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: JarvisTheme.bgPrimary,
        body: CosmicBackground(
          subtle: true,
          child: SafeArea(
            child: Column(
              children: [
                // ── Header Glass interattivo (FIX 4) ──────
                _WorkoutHeader(
                  workout: _workout,
                  hasChanges: _hasChanges,
                  onBack: () async {
                    final canPop = await _onWillPop();
                    if (canPop && mounted)
                      Navigator.of(context).pop();
                  },
                  onRename: _showRenameSheet,
                  onIconColor: _showIconColorSheet,
                  onSave: _hasChanges ? _saveAll : null,
                ),

                const SizedBox(height: 8),

                // ── Azioni rapide ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: JarvisButton(
                          color: JarvisTheme.teal,
                          outlined: true,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                          onTap: _showAddExerciseSheet,
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons
                                      .fitness_center_rounded,
                                  size: 16,
                                  color: JarvisTheme.teal),
                              SizedBox(width: 6),
                              Text('+ Esercizio',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: JarvisTheme.teal,
                                      fontWeight:
                                          FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: JarvisButton(
                          color: const Color(0xFF6366F1),
                          outlined: true,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                          onTap: _showAddCircuitSheet,
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.loop_rounded,
                                  size: 16,
                                  color: Color(0xFF6366F1)),
                              SizedBox(width: 6),
                              Text('+ Circuito',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6366F1),
                                      fontWeight:
                                          FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Lista esercizi drag & drop ─────────────
                Expanded(
                  child: _items.isEmpty
                      ? _EmptyWorkoutState(
                          onAddExercise:
                              _showAddExerciseSheet,
                          onAddCircuit:
                              _showAddCircuitSheet,
                        )
                      : ReorderableListView(
                          padding:
                              const EdgeInsets.fromLTRB(
                                  16, 0, 16, 40),
                          buildDefaultDragHandles: false,
                          physics:
                              const BouncingScrollPhysics(),
                          proxyDecorator: (child, i, anim) =>
                              AnimatedBuilder(
                            animation: anim,
                            builder: (_, __) => Material(
                              elevation: 10,
                              color: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(16),
                              child: child,
                            ),
                          ),
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex)
                              newIndex--;
                            setState(() {
                              final item =
                                  _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                              _hasChanges = true;
                            });
                            HapticFeedback.selectionClick();
                          },
                          children: _items
                              .asMap()
                              .entries
                              .map((e) {
                            final index = e.key;
                            final item = e.value;

                            if (item.type ==
                                _ItemType.exercise) {
                              final we =
                                  _findExercise(item.refKey);
                              if (we == null) {
                                return SizedBox.shrink(
                                    key: ValueKey(
                                        item.stableId));
                              }
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(item.stableId),
                                index: index,
                                child: _ExerciseCard(
                                  exercise: we,
                                  onEdit: () =>
                                      _editExerciseParams(we),
                                  onDelete: () =>
                                      _removeExercise(
                                          item.refKey),
                                ),
                              );
                            } else {
                              final c =
                                  _findCircuit(item.refKey);
                              final children =
                                  _circuitChildren[
                                          item.refKey] ??
                                      [];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(item.stableId),
                                index: index,
                                child: _CircuitCard(
                                  circuit: c,
                                  exercises: children,
                                  onEditExercise:
                                      (we) =>
                                          _editExerciseParams(
                                              we),
                                  onRemoveExercise: (weKey) =>
                                      _removeExercise(weKey),
                                  onDelete: () =>
                                      _removeCircuit(
                                          item.refKey),
                                  onReorderExercises:
                                      (reordered) async {
                                    for (int i = 0;
                                        i < reordered.length;
                                        i++) {
                                      await HiveDatabase
                                          .instance
                                          .updateWorkoutExercise(
                                        reordered[i].key,
                                        HiveWorkoutExercise(
                                          workoutKey: reordered[i]
                                              .workoutKey,
                                          exerciseKey: reordered[i]
                                              .exerciseKey,
                                          exerciseName: reordered[i]
                                              .exerciseName,
                                          muscleGroup: reordered[i]
                                              .muscleGroup,
                                          sets: reordered[i]
                                              .sets,
                                          targetReps: reordered[i]
                                              .targetReps,
                                          targetWeight: reordered[i]
                                              .targetWeight,
                                          restSeconds: reordered[i]
                                              .restSeconds,
                                          notes: reordered[i]
                                              .notes,
                                          sortOrder: i,
                                        ),
                                      );
                                    }
                                    if (mounted) {
                                      context
                                          .read<WorkoutProvider>()
                                          .loadWorkoutExercises(
                                              widget.workoutId);
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
// _WorkoutHeader — header Glass con nome/icona/colore editabili
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
      child: JarvisContainer(
        padding: const EdgeInsets.all(16),
        borderColor: hasChanges
            ? JarvisTheme.orange
            : JarvisTheme.cyan,
        borderOpacity: 0.35,
        glowColor: hasChanges
            ? JarvisTheme.orange
            : JarvisTheme.cyan,
        glowOpacity: 0.12,
        child: Row(
          children: [
            // Indietro
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

            // Icona tap → picker
            GestureDetector(
              onTap: onIconColor,
              child: Stack(
                children: [
                  WorkoutAvatar(
                    iconId: workout?.iconId ?? 'dumbbell',
                    iconColorIndex:
                        workout?.iconColorIndex ?? 0,
                    size: 48,
                    iconSize: 24,
                    borderRadius: 13,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: JarvisTheme.cyan,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: JarvisTheme.bgPrimary,
                            width: 1.5),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 10, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Nome tap → rinomina
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
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded,
                            size: 13,
                            color: JarvisTheme.cyan
                                .withOpacity(0.6)),
                      ],
                    ),
                    Text(
                      hasChanges
                          ? 'Modifiche non salvate'
                          : 'Modifica scheda',
                      style: TextStyle(
                        color: hasChanges
                            ? JarvisTheme.orange
                                .withOpacity(0.8)
                            : Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Salva
            JarvisButton(
              color: hasChanges
                  ? JarvisTheme.teal
                  : Colors.white.withOpacity(0.15),
              outlined: !hasChanges,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              onTap: onSave,
              glowOpacity: hasChanges ? 0.35 : 0.0,
              child: Text(
                'Salva',
                style: TextStyle(
                  color: hasChanges
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseCard — card esercizio nella scheda
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
      child: JarvisContainer(
        padding: const EdgeInsets.all(14),
        borderColor: JarvisTheme.cyan,
        borderOpacity: 0.15,
        child: Row(
          children: [
            Icon(Icons.drag_handle_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: JarvisTheme.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: JarvisTheme.teal.withOpacity(0.2)),
              ),
              child: const Icon(
                  Icons.fitness_center_rounded,
                  color: JarvisTheme.teal,
                  size: 18),
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _ExerciseTag(
                          '${exercise.sets} x ${exercise.targetReps}'),
                      if ((exercise.targetWeight ?? 0) > 0)
                        _ExerciseTag(
                            '${exercise.targetWeight} kg'),
                      if ((exercise.restSeconds ?? 0) > 0)
                        _ExerciseTag(
                            '${exercise.restSeconds}s rec.'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded,
                    size: 15,
                    color: Colors.white.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: JarvisTheme.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 15,
                    color: JarvisTheme.red.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTag extends StatelessWidget {
  final String label;

  const _ExerciseTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: JarvisTheme.cyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: JarvisTheme.cyan.withOpacity(0.2),
            width: 0.7),
      ),
      child: Text(label,
          style: TextStyle(
              color: JarvisTheme.cyan.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitCard — card circuito con D&D interno
// ─────────────────────────────────────────────────────────────

class _CircuitCard extends StatelessWidget {
  final HiveCircuit? circuit;
  final List<HiveWorkoutExercise> exercises;
  final void Function(HiveWorkoutExercise) onEditExercise;
  final void Function(dynamic key) onRemoveExercise;
  final VoidCallback onDelete;
  final void Function(List<HiveWorkoutExercise>)
      onReorderExercises;

  const _CircuitCard({
    required this.circuit,
    required this.exercises,
    required this.onEditExercise,
    required this.onRemoveExercise,
    required this.onDelete,
    required this.onReorderExercises,
  });

  @override
  Widget build(BuildContext context) {
    final circuitColor = const Color(0xFF6366F1);
    final rounds = circuit?.rounds ?? 1;
    final name = circuit?.name ?? 'Circuito';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: JarvisContainer(
        borderColor: circuitColor,
        borderOpacity: 0.4,
        glowColor: circuitColor,
        glowOpacity: 0.1,
        child: Column(
          children: [
            // Header circuito
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.drag_handle_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: circuitColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.loop_rounded,
                        color: circuitColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '$rounds cicl${rounds == 1 ? 'o' : 'i'} · ${exercises.length} esercizi',
                          style: TextStyle(
                              color: circuitColor
                                  .withOpacity(0.7),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: JarvisTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color:
                                JarvisTheme.red.withOpacity(0.3)),
                      ),
                      child: const Text('Elimina',
                          style: TextStyle(
                              color: JarvisTheme.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            JarvisHudLine(
                color: circuitColor, opacity: 0.15),

            // Esercizi del circuito
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
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
                  physics:
                      const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIdx, newIdx) {
                    if (newIdx > oldIdx) newIdx--;
                    final reordered =
                        List<HiveWorkoutExercise>.from(
                            exercises);
                    final item = reordered.removeAt(oldIdx);
                    reordered.insert(newIdx, item);
                    onReorderExercises(reordered);
                  },
                  children: exercises.asMap().entries.map((e) {
                    final we = e.value;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(we.key),
                      index: e.key,
                      child: _ExerciseCard(
                        exercise: we,
                        onEdit: () => onEditExercise(we),
                        onDelete: () =>
                            onRemoveExercise(we.key),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyWorkoutState — scheda vuota (FIX Part 8)
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
            // Manubrio + glow HUD
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: JarvisTheme.teal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: JarvisTheme.cyan.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: JarvisTheme.cyan.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 42,
                color: JarvisTheme.teal,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Scheda vuota',
              style: JarvisTheme.titleWhite(size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Aggiungi esercizi o crea un circuito\nper iniziare a configurare la scheda.',
              textAlign: TextAlign.center,
              style: JarvisTheme.subtitleDim(size: 13),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: JarvisButton(
                    color: JarvisTheme.teal,
                    onTap: onAddExercise,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Aggiungi esercizi'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JarvisButton(
                    color: const Color(0xFF6366F1),
                    onTap: onAddCircuit,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.loop_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Crea circuito'),
                      ],
                    ),
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
  final Set<dynamic> _selected = {};

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allExercises.where((e) {
      return _search.isEmpty ||
          e.name
              .toLowerCase()
              .contains(_search.toLowerCase()) ||
          e.muscleGroup
              .toLowerCase()
              .contains(_search.toLowerCase());
    }).toList();

    return _JarvisSheetWrapper(
      title: 'Aggiungi esercizi',
      subtitle: _selected.isEmpty
          ? null
          : '${_selected.length} selezionati',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ricerca
          _JarvisTextField(
            hintText: 'Cerca esercizio...',
            prefix: const Icon(Icons.search_rounded,
                size: 17, color: JarvisTheme.cyan),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          // Lista
          SizedBox(
            height: 300,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isIn =
                    widget.alreadyIn.contains(ex.key);
                final isSel = _selected.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: isIn
                      ? Icon(Icons.check_circle,
                          color: JarvisTheme.teal
                              .withOpacity(0.6),
                          size: 20)
                      : GestureDetector(
                          onTap: () => setState(() {
                            if (isSel) {
                              _selected.remove(ex.key);
                            } else {
                              _selected.add(ex.key);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? JarvisTheme.teal
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel
                                    ? JarvisTheme.teal
                                    : Colors.white
                                        .withOpacity(0.25),
                                width: 1.2,
                              ),
                            ),
                            child: isSel
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white)
                                : null,
                          ),
                        ),
                  title: Text(ex.name,
                      style: TextStyle(
                          color: isIn
                              ? Colors.white.withOpacity(0.35)
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
                            if (isSel) {
                              _selected.remove(ex.key);
                            } else {
                              _selected.add(ex.key);
                            }
                          }),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty)
            JarvisButton(
              color: JarvisTheme.teal,
              onTap: () => widget.onConfirm(_selected),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'Aggiungi ${_selected.length} esercizi'),
                ],
              ),
            ),
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
  final Set<dynamic> alreadyInCircuit;
  final void Function(Set<dynamic> keys, int rounds,
      String name) onConfirm;

  const _AddCircuitToWorkoutSheet({
    required this.allExercises,
    required this.alreadyInCircuit,
    required this.onConfirm,
  });

  @override
  State<_AddCircuitToWorkoutSheet> createState() =>
      _AddCircuitToWorkoutSheetState();
}

class _AddCircuitToWorkoutSheetState
    extends State<_AddCircuitToWorkoutSheet> {
  String _search = '';
  final Set<dynamic> _selected = {};
  int _rounds = 3;
  final _nameCtrl =
      TextEditingController(text: 'Circuito');

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circuitColor = const Color(0xFF6366F1);
    final filtered = widget.allExercises.where((e) {
      return _search.isEmpty ||
          e.name
              .toLowerCase()
              .contains(_search.toLowerCase());
    }).toList();

    return _JarvisSheetWrapper(
      title: 'Nuovo circuito',
      subtitle: _selected.isEmpty
          ? null
          : '${_selected.length} esercizi selezionati',
      accentColor: circuitColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nome circuito
          _JarvisTextField(
            controller: _nameCtrl,
            hintText: 'Nome circuito...',
          ),
          const SizedBox(height: 12),

          // Rounds
          Row(
            children: [
              Text('Cicli:',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              ...List.generate(5, (i) {
                final r = i + 1;
                final sel = _rounds == r;
                return GestureDetector(
                  onTap: () => setState(() => _rounds = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sel
                          ? circuitColor
                          : circuitColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? circuitColor
                            : circuitColor.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text('$r',
                          style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : circuitColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Ricerca
          _JarvisTextField(
            hintText: 'Cerca esercizio...',
            prefix: Icon(Icons.search_rounded,
                size: 17,
                color: circuitColor.withOpacity(0.7)),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),

          // Lista
          SizedBox(
            height: 280,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex = filtered[i];
                final isSel = _selected.contains(ex.key);
                return ListTile(
                  dense: true,
                  leading: GestureDetector(
                    onTap: () => setState(() {
                      if (isSel) {
                        _selected.remove(ex.key);
                      } else {
                        _selected.add(ex.key);
                      }
                    }),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSel
                            ? circuitColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSel
                              ? circuitColor
                              : Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: isSel
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
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
                    if (isSel) {
                      _selected.remove(ex.key);
                    } else {
                      _selected.add(ex.key);
                    }
                  }),
                );
              },
            ),
          ),

          if (_selected.isNotEmpty)
            JarvisButton(
              color: circuitColor,
              onTap: () => widget.onConfirm(
                _selected,
                _rounds,
                _nameCtrl.text.trim().isNotEmpty
                    ? _nameCtrl.text.trim()
                    : 'Circuito',
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.loop_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'Crea circuito · ${_selected.length} esercizi · $_rounds cicli'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _EditExerciseParamsSheet
// ─────────────────────────────────────────────────────────────

class _EditExerciseParamsSheet extends StatefulWidget {
  final HiveWorkoutExercise exercise;
  final void Function(int sets, int reps, double weight,
      int? rest) onConfirm;

  const _EditExerciseParamsSheet({
    required this.exercise,
    required this.onConfirm,
  });

  @override
  State<_EditExerciseParamsSheet> createState() =>
      _EditExerciseParamsSheetState();
}

class _EditExerciseParamsSheetState
    extends State<_EditExerciseParamsSheet> {
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
    return _JarvisSheetWrapper(
      title: widget.exercise.exerciseName,
      subtitle: 'Parametri esercizio',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ParamRow(
            label: 'Serie',
            value: _sets,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _sets = v),
          ),
          _ParamRow(
            label: 'Ripetizioni',
            value: _reps,
            min: 1,
            max: 100,
            onChanged: (v) => setState(() => _reps = v),
          ),
          _ParamRow(
            label: 'Recupero (sec)',
            value: _rest,
            min: 0,
            max: 600,
            step: 15,
            onChanged: (v) => setState(() => _rest = v),
          ),
          // Peso
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
                  child: _JarvisTextField(
                    initialValue: _weight > 0
                        ? _weight.toString()
                        : '',
                    hintText: '0',
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    onChanged: (v) {
                      setState(() =>
                          _weight = double.tryParse(v) ?? 0);
                    },
                  ),
                ),
              ],
            ),
          ),
          JarvisButton(
            color: JarvisTheme.teal,
            onTap: () => widget.onConfirm(
                _sets, _reps, _weight, _rest > 0 ? _rest : null),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded,
                    size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Salva parametri'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;

  const _ParamRow({
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
          GestureDetector(
            onTap: () {
              if (value - step >= min)
                onChanged(value - step);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: JarvisTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: JarvisTheme.cyan.withOpacity(0.2)),
              ),
              child: const Icon(Icons.remove_rounded,
                  size: 16, color: JarvisTheme.cyan),
            ),
          ),
          Container(
            width: 52,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (value + step <= max)
                onChanged(value + step);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: JarvisTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: JarvisTheme.cyan.withOpacity(0.2)),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 16, color: JarvisTheme.cyan),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _RenameWorkoutSheet
// ─────────────────────────────────────────────────────────────

class _RenameWorkoutSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;

  const _RenameWorkoutSheet({
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return _JarvisSheetWrapper(
      title: 'Rinomina scheda',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _JarvisTextField(
            controller: controller,
            hintText: 'Nome scheda...',
            autofocus: true,
          ),
          const SizedBox(height: 20),
          JarvisButton(
            color: JarvisTheme.teal,
            onTap: onConfirm,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded,
                    size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Rinomina'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: _IconColorSheet (FIX 4)
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
  State<_IconColorSheet> createState() =>
      _IconColorSheetState();
}

class _IconColorSheetState extends State<_IconColorSheet> {
  late String _iconId;
  late int _colorIndex;

  @override
  void initState() {
    super.initState();
    _iconId = widget.currentIconId;
    _colorIndex = widget.currentColorIndex
        .clamp(0, JarvisTheme.workoutColors.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = JarvisTheme.workoutColors[_colorIndex];

    return _JarvisSheetWrapper(
      title: 'Icona e colore',
      accentColor: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anteprima live
          Center(
            child: Column(
              children: [
                WorkoutAvatar(
                  iconId: _iconId,
                  iconColorIndex: _colorIndex,
                  size: 72,
                  iconSize: 36,
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

          // Colori
          Text('Colore',
              style: JarvisTheme.subtitleDim(size: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: JarvisTheme.workoutColors
                .asMap()
                .entries
                .map((e) {
              final sel = e.key == _colorIndex;
              return GestureDetector(
                onTap: () =>
                    setState(() => _colorIndex = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: sel
                        ? Border.all(
                            color: Colors.white, width: 2.5)
                        : Border.all(
                            color: Colors.transparent),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: e.value.withOpacity(0.6),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Icone
          Text('Icona', style: JarvisTheme.subtitleDim(size: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: JarvisTheme.workoutIcons.map((icon) {
              final sel = icon.$1 == _iconId;
              return GestureDetector(
                onTap: () =>
                    setState(() => _iconId = icon.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sel
                        ? accent.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? accent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: accent.withOpacity(0.2),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Icon(icon.$2,
                      color: sel
                          ? accent
                          : Colors.white.withOpacity(0.45),
                      size: 22),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          JarvisButton(
            color: accent,
            onTap: () => widget.onSelect(_iconId, _colorIndex),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded,
                    size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Applica'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers locali condivisi
// ─────────────────────────────────────────────────────────────

class _JarvisSheetWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;

  const _JarvisSheetWrapper({
    required this.title,
    this.subtitle,
    required this.child,
    this.accentColor = JarvisTheme.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF060B14),
            const Color(0xFF03040A),
          ],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          const JarvisSheetHandle(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: JarvisTheme.titleWhite(size: 18)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: accentColor.withOpacity(0.7),
                          fontSize: 12)),
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

class _JarvisTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String hintText;
  final Widget? prefix;
  final void Function(String)? onChanged;
  final bool autofocus;
  final TextInputType keyboardType;

  const _JarvisTextField({
    this.controller,
    this.initialValue,
    required this.hintText,
    this.prefix,
    this.onChanged,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
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
            border: Border.all(
              color: JarvisTheme.cyan.withOpacity(0.2),
              width: 0.8,
            ),
          ),
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14),
              prefixIcon: prefix != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      child: prefix)
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44),
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