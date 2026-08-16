import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../models/training_mode.dart';
import '../../providers/training_mode_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart'; // FIX: import centralizzato
import '../training_modes/training_mode_picker_sheet.dart';

// ─── Accent tokens ─────────────────────────────────────────────
const _kCyan   = MarkFitColors.cyan;
const _kTeal   = MarkFitColors.teal;
const _kTealDk = MarkFitColors.tealDk;
const _kRed    = MarkFitColors.red;
const _kIndigo = MarkFitColors.indigo;
const _kOrange = MarkFitColors.orange;

// RIMOSSO: _kWorkoutColors, _kWorkoutIcons
// → ora in workout_icon.dart come kWorkoutPaletteExtended e kWorkoutIconLibrary
// La logica di risoluzione è centralizzata in resolveWorkoutColor()

const _kMuscleGroups = [
  'Tutti', 'Petto', 'Schiena', 'Spalle',
  'Bicipiti', 'Tricipiti', 'Gambe', 'Addominali',
];

// FASE 3 — Sistema Modalità di Allenamento: helper per convertire
// in modo sicuro la chiave dinamica di Hive in int? (le chiavi dei
// box con add() sono int auto-incrementali). Mai un cast diretto
// che possa lanciare un'eccezione (Parte 63 — nessun crash).
int? _asIntKey(dynamic k) => k is int ? k : null;

enum _ItemType { exercise, circuit }

class _ListItem {
  final _ItemType type;
  final dynamic   refKey;
  _ListItem({required this.type, required this.refKey});
  String get stableId =>
      type == _ItemType.exercise ? 'ex_$refKey' : 'circ_$refKey';
}

// ─────────────────────────────────────────────────────────────
// WorkoutDetailScreen
// ─────────────────────────────────────────────────────────────
class WorkoutDetailScreen extends StatefulWidget {
  final dynamic workoutId;
  final String  workoutName;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<WorkoutDetailScreen> createState() =>
      _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late List<_ListItem>                         _items;
  late List<HiveCircuit>                       _circuits;
  HiveWorkout?                                 _workout;
  bool                                         _hasChanges = false;
  late List<_ListItem>                         _snapshot;
  late Map<dynamic, List<HiveWorkoutExercise>> _circuitChildren;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
    _rebuildAll();
    _snapshot = List.from(_items);
    // FASE 3 — necessario per assegnare la modalità predefinita ai
    // nuovi esercizi/membri circuito e per il selettore modalità
    // nel popup "Modifica parametri".
    Future.microtask(
        () => context.read<TrainingModeProvider>().loadModes());
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
    final wp    = context.read<WorkoutProvider>();
    final allEx = wp.currentExercises;

    _circuits = HiveDatabase.instance
        .getCircuits(widget.workoutId)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final freeEx = allEx.where((e) => !e.isInCircuit).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final topItems = <({int order, bool isCircuit, dynamic key})>[
      ...freeEx.map((e) =>
          (order: e.sortOrder, isCircuit: false, key: e.key as dynamic)),
      ..._circuits.map((c) =>
          (order: c.sortOrder, isCircuit: true, key: c.key as dynamic)),
    ]..sort((a, b) => a.order.compareTo(b.order));

    _items = topItems
        .map((i) => _ListItem(
              type:   i.isCircuit ? _ItemType.circuit : _ItemType.exercise,
              refKey: i.key,
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
            workoutKey:   we.workoutKey,
            exerciseKey:  we.exerciseKey,
            exerciseName: we.exerciseName,
            muscleGroup:  we.muscleGroup,
            sets:         we.sets,
            targetReps:   we.targetReps,
            targetWeight: we.targetWeight,
            restSeconds:  we.restSeconds,
            notes:        we.notes,
            sortOrder:    order++,
            trainingModeKey: we.trainingModeKey,
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
      context
          .read<WorkoutProvider>()
          .loadWorkoutExercises(widget.workoutId);
    }
  }

  Future<void> _saveAndPop() async {
    await _persistOrder(_items);
    if (mounted) {
      context.read<WorkoutProvider>().loadWorkouts();
      Navigator.of(context).pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showGlassDialog<String>(
      context:     context,
      accentColor: _kOrange,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color:     _kOrange.withOpacity(0.12),
          shape:     BoxShape.circle,
          border:    Border.all(color: _kOrange.withOpacity(0.4), width: 1),
          boxShadow: [BoxShadow(
              color: _kOrange.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.edit_rounded, color: _kOrange, size: 20)),
      title:   'Modifiche non salvate',
      message: 'Vuoi salvare le modifiche alla scheda prima di uscire?',
      actions: [
        GlassDialogAction(
          label:         'Scarta',
          isDestructive: true,
          onTap:         () => Navigator.pop(context, 'discard'),
        ),
        GlassDialogAction(
          label: 'Annulla',
          onTap: () => Navigator.pop(context, 'cancel'),
        ),
        GlassDialogAction(
          label:     'Salva',
          isDefault: true,
          color:     _kTeal,
          onTap:     () => Navigator.pop(context, 'save'),
        ),
      ],
    );
    if (result == 'save') {
      await _persistOrder(_items);
      if (mounted) context.read<WorkoutProvider>().loadWorkouts();
      return true;
    }
    if (result == 'discard') {
      await _persistOrder(_snapshot);
      if (mounted) {
        context
            .read<WorkoutProvider>()
            .loadWorkoutExercises(widget.workoutId);
      }
      return true;
    }
    return false;
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

  Future<void> _showAddExerciseSheet() async {
    final allExercises = HiveDatabase.instance.getExercises();
    final currentKeys  = context
        .read<WorkoutProvider>()
        .currentExercises
        .map((e) => e.exerciseKey)
        .toSet();

    await _openSheet(_AddExercisesToWorkoutSheet(
      allExercises: allExercises,
      alreadyIn:    currentKeys,
      onConfirm: (keys) async {
        final existing = context
            .read<WorkoutProvider>()
            .currentExercises;
        int nextOrder = existing.isEmpty
            ? 0
            : existing
                    .map((e) => e.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
        // FASE 3 — Parte 7/15: i nuovi esercizi ricevono la modalità
        // predefinita globale ATTUALE. Letta una sola volta prima
        // del loop così resta stabile per tutti gli esercizi
        // aggiunti in questa singola operazione.
        final defaultModeKey = _asIntKey(
            context.read<TrainingModeProvider>().defaultMode?.key);
        for (final key in keys) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance
                .addWorkoutExercise(HiveWorkoutExercise(
              workoutKey:   widget.workoutId,
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
              sets:         3,
              targetReps:   10,
              targetWeight: 0,
              sortOrder:    nextOrder++,
              trainingModeKey: defaultModeKey,
            ));
          } catch (_) {}
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
    ));
  }

  Future<void> _showAddCircuitSheet() async {
    final allExercises = HiveDatabase.instance.getExercises();
    await _openSheet(_AddCircuitToWorkoutSheet(
      allExercises: allExercises,
      onConfirm: (keys, rounds, name) async {
        final existing = context
            .read<WorkoutProvider>()
            .currentExercises;
        int nextOrder = existing.isEmpty
            ? 0
            : existing
                    .map((e) => e.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
        final circuitKey = await HiveDatabase.instance
            .addCircuit(HiveCircuit(
          workoutKey: widget.workoutId,
          name:       name,
          rounds:     rounds,
          sortOrder:  nextOrder,
        ));
        // FASE 3 — stessa assegnazione automatica anche per i membri
        // di un nuovo circuito.
        final defaultModeKey = _asIntKey(
            context.read<TrainingModeProvider>().defaultMode?.key);
        int exOrder = 0;
        for (final key in keys) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance
                .addWorkoutExercise(HiveWorkoutExercise(
              workoutKey:   widget.workoutId,
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
              sets:         3,
              targetReps:   10,
              targetWeight: 0,
              notes:        '__circuit_$circuitKey',
              sortOrder:    exOrder++,
              trainingModeKey: defaultModeKey,
            ));
          } catch (_) {}
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
    ));
  }

  Future<void> _showEditCircuitSheet(
    HiveCircuit circuit,
    List<HiveWorkoutExercise> children,
  ) async {
    final allExercises = HiveDatabase.instance.getExercises();
    await _openSheet(_EditCircuitSheet(
      circuit:         circuit,
      currentChildren: children,
      allExercises:    allExercises,
      onConfirm: (rounds, toAdd, toRemove) async {
        if (rounds != circuit.rounds) {
          circuit.rounds = rounds;
          await circuit.save();
        }
        for (final we in toRemove) {
          await HiveDatabase.instance.deleteWorkoutExercise(we.key);
        }
        int nextOrder = children.isEmpty
            ? 0
            : children
                    .map((e) => e.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
        // FASE 3 — stessa assegnazione automatica per i nuovi
        // membri aggiunti a un circuito esistente.
        final defaultModeKey = _asIntKey(
            context.read<TrainingModeProvider>().defaultMode?.key);
        for (final key in toAdd) {
          try {
            final ex = allExercises.firstWhere((e) => e.key == key);
            await HiveDatabase.instance
                .addWorkoutExercise(HiveWorkoutExercise(
              workoutKey:   widget.workoutId,
              exerciseKey:  ex.key,
              exerciseName: ex.name,
              muscleGroup:  ex.muscleGroup,
              sets:         3,
              targetReps:   10,
              targetWeight: 0,
              notes:        '__circuit_${circuit.key}',
              sortOrder:    nextOrder++,
              trainingModeKey: defaultModeKey,
            ));
          } catch (_) {}
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
        setState(() {
          _workout!.name = name;
          _hasChanges    = true;
        });
        context.read<WorkoutProvider>().loadWorkouts();
        Navigator.pop(context);
      },
    ));
  }

  // FIX PRINCIPALE: usa showWorkoutIconColorSheet — popup a layout
  // fisso (anteprima + tab Icona/Colore + pulsanti sempre visibili)
  // aperto direttamente (non annidato in _openSheet) per poter
  // gestire un'altezza fissa con area centrale scrollabile.
  Future<void> _showIconColorSheet() async {
    if (_workout == null) return;
    await showWorkoutIconColorSheet(
      context,
      initialIconId:     _workout!.iconId,
      initialColorValue: _workout!.iconColorIndex,
      onSelect: (iconId, colorArgb) {
        // FIX: salva ARGB diretto, non indice
        _workout!.iconId         = iconId;
        _workout!.iconColorIndex = colorArgb;
        _workout!.save();
        setState(() => _hasChanges = true);
        context.read<WorkoutProvider>().loadWorkouts();
        Navigator.pop(context);
      },
    );
  }

  Future<void> _removeExercise(dynamic key) async {
    final we = _findEx(key);
    if (we == null) return;
    await HiveDatabase.instance.deleteWorkoutExercise(we.key);
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

  Future<void> _removeCircuit(dynamic circuitKey) async {
    final children = _circuitChildren[circuitKey] ?? [];
    for (final ex in children) {
      await HiveDatabase.instance.deleteWorkoutExercise(ex.key);
    }
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

  Future<void> _editExerciseParams(HiveWorkoutExercise we) async {
    await _openSheet(_EditParamsSheet(
      exercise: we,
      onConfirm: (sets, reps, weight, rest, trainingModeKey) async {
        await HiveDatabase.instance.updateWorkoutExercise(
          we.key,
          HiveWorkoutExercise(
            workoutKey:   we.workoutKey,
            exerciseKey:  we.exerciseKey,
            exerciseName: we.exerciseName,
            muscleGroup:  we.muscleGroup,
            sets:         sets,
            targetReps:   reps,
            targetWeight: weight,
            restSeconds:  rest,
            notes:        we.notes,
            sortOrder:    we.sortOrder,
            trainingModeKey: _asIntKey(trainingModeKey),
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.mfc;
    final isEmpty = _items.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CosmicBackground(
          subtle: true,
          child: SafeArea(
            child: Column(
              children: [
                _WorkoutHeader(
                  workout:    _workout,
                  hasChanges: _hasChanges,
                  onBack: () async {
                    final canPop = await _onWillPop();
                    if (canPop && mounted) Navigator.of(context).pop();
                  },
                  onRename:    _showRenameSheet,
                  onIconColor: _showIconColorSheet,
                  onSave:      _hasChanges ? _saveAndPop : null,
                ),
                const SizedBox(height: 8),
                if (!isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: '+ Esercizio',
                            icon:  Icons.fitness_center_rounded,
                            color: _kTeal,
                            onTap: _showAddExerciseSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            label: '+ Circuito',
                            icon:  Icons.loop_rounded,
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
                          onAddCircuit:  _showAddCircuitSheet,
                        )
                      : ReorderableListView(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 40),
                          buildDefaultDragHandles: false,
                          physics: const BouncingScrollPhysics(),
                          proxyDecorator: (child, i, anim) =>
                              AnimatedBuilder(
                            animation: anim,
                            builder: (_, __) => Material(
                              elevation: 0,
                              color:     Colors.transparent,
                              child:     child,
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
                            final idx  = entry.key;
                            final item = entry.value;

                            if (item.type == _ItemType.exercise) {
                              final we = _findEx(item.refKey);
                              if (we == null) {
                                return SizedBox.shrink(
                                    key: ValueKey(item.stableId));
                              }
                              return ReorderableDelayedDragStartListener(
                                key:   ValueKey(item.stableId),
                                index: idx,
                                child: _ExerciseCard(
                                  exercise: we,
                                  c:        c,
                                  onEdit:   () => _editExerciseParams(we),
                                  onDelete: () =>
                                      _removeExercise(item.refKey),
                                ),
                              );
                            } else {
                              final circ     = _findCircuit(item.refKey);
                              final children =
                                  _circuitChildren[item.refKey] ?? [];
                              return ReorderableDelayedDragStartListener(
                                key:   ValueKey(item.stableId),
                                index: idx,
                                child: _CircuitCard(
                                  circuit:   circ,
                                  exercises: children,
                                  c:         c,
                                  onEditCircuit: circ == null
                                      ? () {}
                                      : () => _showEditCircuitSheet(
                                          circ, children),
                                  onEditExercise: (we) =>
                                      _editExerciseParams(we),
                                  onRemoveExercise: (weKey) =>
                                      _removeExercise(weKey),
                                  onDelete: () =>
                                      _removeCircuit(item.refKey),
                                  onReorderExercises: (reordered) async {
                                    for (int i = 0;
                                        i < reordered.length;
                                        i++) {
                                      await HiveDatabase.instance
                                          .updateWorkoutExercise(
                                        reordered[i].key,
                                        HiveWorkoutExercise(
                                          workoutKey:   reordered[i].workoutKey,
                                          exerciseKey:  reordered[i].exerciseKey,
                                          exerciseName: reordered[i].exerciseName,
                                          muscleGroup:  reordered[i].muscleGroup,
                                          sets:         reordered[i].sets,
                                          targetReps:   reordered[i].targetReps,
                                          targetWeight: reordered[i].targetWeight,
                                          restSeconds:  reordered[i].restSeconds,
                                          notes:        reordered[i].notes,
                                          sortOrder:    i,
                                          trainingModeKey:
                                              reordered[i].trainingModeKey,
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
// _WorkoutHeader — ADATTIVO
// WorkoutAvatar usa ora resolveWorkoutColor() centralmente
// ─────────────────────────────────────────────────────────────
class _WorkoutHeader extends StatelessWidget {
  final HiveWorkout?  workout;
  final bool          hasChanges;
  final VoidCallback  onBack, onRename, onIconColor;
  final VoidCallback? onSave;

  const _WorkoutHeader({
    required this.workout,
    required this.hasChanges,
    required this.onBack,
    required this.onRename,
    required this.onIconColor,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        c.glassCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasChanges
                    ? _kOrange.withOpacity(0.5)
                    : _kCyan.withOpacity(0.25),
                width: 0.8,
              ),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color:      c.elevationColor,
                      blurRadius: 12,
                      offset:     const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width:  36,
                    height: 36,
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
                GestureDetector(
                  onTap: onIconColor,
                  child: Stack(
                    children: [
                      // FIX: usa WorkoutAvatar con resolveWorkoutColor()
                      WorkoutAvatar(
                        iconId:         workout?.iconId,
                        iconColorIndex: workout?.iconColorIndex,
                        size:           46,
                        iconSize:       23,
                        borderRadius:   12,
                      ),
                      Positioned(
                        right:  -2,
                        bottom: -2,
                        child: Container(
                          width:  17,
                          height: 17,
                          decoration: BoxDecoration(
                            color:  _kCyan,
                            shape:  BoxShape.circle,
                            border: Border.all(
                                color: c.scaffoldBg, width: 1.5),
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
                                style: TextStyle(
                                  color:      c.textPrimary,
                                  fontSize:   16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_rounded,
                                size:  12,
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
                                : c.textTertiary,
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
                      gradient: hasChanges
                          ? const LinearGradient(
                              colors: [_kTeal, _kTealDk])
                          : null,
                      color: hasChanges ? null : c.glassCardInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasChanges
                            ? _kTeal.withOpacity(0.5)
                            : c.glassBorder,
                      ),
                      boxShadow: hasChanges
                          ? [BoxShadow(
                              color:      _kTeal.withOpacity(0.3),
                              blurRadius: 12,
                              offset:     const Offset(0, 3))]
                          : null,
                    ),
                    child: Text(
                      'Salva',
                      style: TextStyle(
                        color: hasChanges
                            ? Colors.white
                            : c.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize:   13,
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
// _EmptyWorkoutState — ADATTIVO
// ─────────────────────────────────────────────────────────────
class _EmptyWorkoutState extends StatelessWidget {
  final VoidCallback onAddExercise, onAddCircuit;
  const _EmptyWorkoutState({
    required this.onAddExercise, required this.onAddCircuit});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  86,
              height: 86,
              decoration: BoxDecoration(
                color:     _kTeal.withOpacity(0.08),
                shape:     BoxShape.circle,
                border:    Border.all(
                    color: _kCyan.withOpacity(0.3), width: 1),
                boxShadow: [BoxShadow(
                    color: _kCyan.withOpacity(0.12), blurRadius: 24)],
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 40, color: _kTeal),
            ),
            const SizedBox(height: 22),
            Text('Scheda vuota', style: TextStyle(
                color:      c.textPrimary,
                fontSize:   20,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Aggiungi esercizi o crea un circuito\n'
              'per iniziare a configurare la scheda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textTertiary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Aggiungi esercizi',
                    icon:  Icons.add_rounded,
                    color: _kTeal,
                    onTap: onAddExercise,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: 'Crea circuito',
                    icon:  Icons.loop_rounded,
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
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label, required this.icon,
    required this.color, required this.onTap});

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
              color:        color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: color.withOpacity(0.4), width: 1),
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.15), blurRadius: 12)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(
                    color:      color,
                    fontSize:   13,
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
// _ExerciseCard — ADATTIVO
// ─────────────────────────────────────────────────────────────
class _ExerciseCard extends StatelessWidget {
  final HiveWorkoutExercise exercise;
  final MarkFitColors       c;
  final VoidCallback        onEdit, onDelete;
  const _ExerciseCard({
    required this.exercise, required this.c,
    required this.onEdit,   required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color:        c.glassCard,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color:     c.elevationColor,
                      blurRadius: 6,
                      offset:    const Offset(0, 1))]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.drag_handle_rounded,
                      size: 18, color: c.iconSecondary),
                  const SizedBox(width: 10),
                  Container(
                    width:  36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:        _kTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _kTeal.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.fitness_center_rounded,
                        color: _kTeal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.exerciseName, style: TextStyle(
                            color:      c.textPrimary,
                            fontSize:   14,
                            fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Wrap(spacing: 6, children: [
                          _Tag('${exercise.sets} x ${exercise.targetReps}', c),
                          if ((exercise.targetWeight ?? 0) > 0)
                            _Tag('${exercise.targetWeight} kg', c),
                          if ((exercise.restSeconds ?? 0) > 0)
                            _Tag('${exercise.restSeconds}s rec.', c),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(icon: Icons.tune_rounded,
                      color: c.iconPrimary, onTap: onEdit),
                  const SizedBox(width: 6),
                  _IconBtn(icon: Icons.delete_outline_rounded,
                      color: _kRed.withOpacity(0.7), onTap: onDelete),
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
  final String        label;
  final MarkFitColors c;
  const _Tag(this.label, this.c);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        _kCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kCyan.withOpacity(0.2), width: 0.7),
      ),
      child: Text(label, style: TextStyle(
          color:      _kCyan.withOpacity(0.8),
          fontSize:   10,
          fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:  32,
      height: 32,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// _CircuitCard — ADATTIVO
// ─────────────────────────────────────────────────────────────
class _CircuitCard extends StatelessWidget {
  final HiveCircuit?               circuit;
  final List<HiveWorkoutExercise>  exercises;
  final MarkFitColors              c;
  final VoidCallback               onEditCircuit, onDelete;
  final void Function(HiveWorkoutExercise)       onEditExercise;
  final void Function(dynamic)                   onRemoveExercise;
  final void Function(List<HiveWorkoutExercise>) onReorderExercises;

  const _CircuitCard({
    required this.circuit,
    required this.exercises,
    required this.c,
    required this.onEditCircuit,
    required this.onEditExercise,
    required this.onRemoveExercise,
    required this.onDelete,
    required this.onReorderExercises,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = circuit?.rounds ?? 1;
    final name   = circuit?.name   ?? 'Circuito';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color:        c.glassCard,
              borderRadius: BorderRadius.circular(18),
              border: Border(
                left:   BorderSide(
                    color: _kIndigo.withOpacity(0.6), width: 3),
                top:    BorderSide(
                    color: _kIndigo.withOpacity(0.15), width: 0.7),
                right:  BorderSide(
                    color: _kIndigo.withOpacity(0.15), width: 0.7),
                bottom: BorderSide(
                    color: _kIndigo.withOpacity(0.15), width: 0.7),
              ),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8)]
                  : [BoxShadow(
                      color:      _kIndigo.withOpacity(0.05),
                      blurRadius: 14)],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 18, color: c.iconSecondary),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:        _kIndigo.withOpacity(0.15),
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
                            Text(name, style: TextStyle(
                                color:      c.textPrimary,
                                fontSize:   14,
                                fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '$rounds cicl${rounds == 1 ? 'o' : 'i'} · '
                              '${exercises.length} esercizi',
                              style: TextStyle(
                                  color:    _kIndigo.withOpacity(0.8),
                                  fontSize: 11)),
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
                          child: const Text('Modifica', style: TextStyle(
                              color:      _kIndigo,
                              fontSize:   11,
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
                          child: const Text('Elimina', style: TextStyle(
                              color:      _kRed,
                              fontSize:   11,
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
                            color:     c.textTertiary,
                            fontSize:  12,
                            fontStyle: FontStyle.italic)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics:    const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      proxyDecorator:
                          (child, index, animation) => AnimatedBuilder(
                        animation: animation,
                        builder: (_, __) => Material(
                          elevation: 0,
                          color:     Colors.transparent,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _kCyan.withOpacity(0.5),
                                width: 1.2,
                              ),
                              boxShadow: [BoxShadow(
                                  color:     _kCyan.withOpacity(0.12),
                                  blurRadius: 10)],
                            ),
                            child: child,
                          ),
                        ),
                      ),
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
                          key:   ValueKey(we.key),
                          index: e.key,
                          child: _ExerciseCard(
                            exercise: we,
                            c:        c,
                            onEdit:   () => onEditExercise(we),
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

// ═════════════════════════════════════════════════════════════
// SHEET WIDGETS (privati a workout_detail_screen)
// ═════════════════════════════════════════════════════════════

class _AddExercisesToWorkoutSheet extends StatefulWidget {
  final List<HiveExercise>       allExercises;
  final Set<dynamic>             alreadyIn;
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
  String             _search   = '';
  String             _muscle   = 'Tutti';
  final Set<dynamic> _selected = {};

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(_search.toLowerCase()) ||
              e.muscleGroup
                  .toLowerCase()
                  .contains(_search.toLowerCase()));
    }).toList();

    return GlassSheetWrapper(
      title:    'Aggiungi esercizi',
      subtitle: _selected.isEmpty
          ? null
          : '${_selected.length} selezionati',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            hintText:  'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          _MuscleChips(
            groups:   groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: filtered.isEmpty
                ? Center(
                    child: Text('Nessun esercizio trovato',
                        style: TextStyle(
                            color:     c.textTertiary,
                            fontSize:  13,
                            fontStyle: FontStyle.italic)))
                : ListView.builder(
                    physics:   const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ex    = filtered[i];
                      final isIn  = widget.alreadyIn.contains(ex.key);
                      final isSel = _selected.contains(ex.key);
                      return _ExerciseTile(
                        exercise:    ex,
                        isAlreadyIn: isIn,
                        isSelected:  isSel,
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
            GlassPrimaryButton(
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

class _AddCircuitToWorkoutSheet extends StatefulWidget {
  final List<HiveExercise> allExercises;
  final void Function(Set<dynamic> keys, int rounds, String name) onConfirm;
  const _AddCircuitToWorkoutSheet({
    required this.allExercises, required this.onConfirm});
  @override
  State<_AddCircuitToWorkoutSheet> createState() =>
      _AddCircuitToWorkoutSheetState();
}

class _AddCircuitToWorkoutSheetState
    extends State<_AddCircuitToWorkoutSheet> {
  String             _search   = '';
  String             _muscle   = 'Tutti';
  final Set<dynamic> _selected = {};
  int                _rounds   = 3;
  final _nameCtrl = TextEditingController(text: 'Circuito');

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }
    final filtered = widget.allExercises.where((e) {
      return (_muscle == 'Tutti' || e.muscleGroup == _muscle) &&
          (_search.isEmpty ||
              e.name.toLowerCase().contains(_search.toLowerCase()));
    }).toList();

    return GlassSheetWrapper(
      title:       'Nuovo circuito',
      accentColor: _kIndigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: _nameCtrl,
            hintText:   'Nome circuito...',
            onChanged:  (_) {},
          ),
          const SizedBox(height: 12),
          _RoundsRow(
            rounds:    _rounds,
            onChanged: (v) => setState(() => _rounds = v),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            hintText:  'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          _MuscleChips(
            groups:   groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: filtered.isEmpty
                ? Center(
                    child: Text('Nessun esercizio trovato',
                        style: TextStyle(
                            color:     c.textTertiary,
                            fontSize:  13,
                            fontStyle: FontStyle.italic)))
                : ListView.builder(
                    physics:   const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ex    = filtered[i];
                      final isSel = _selected.contains(ex.key);
                      return _ExerciseTile(
                        exercise:    ex,
                        isAlreadyIn: false,
                        isSelected:  isSel,
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
            GlassPrimaryButton(
              label: 'Crea · ${_selected.length} eserc. · $_rounds cicli',
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

class _EditCircuitSheet extends StatefulWidget {
  final HiveCircuit               circuit;
  final List<HiveWorkoutExercise> currentChildren;
  final List<HiveExercise>        allExercises;
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
  late int           _rounds;
  String             _search = '';
  String             _muscle = 'Tutti';
  late Set<dynamic>  _existingKeys;
  final Set<dynamic> _toAdd    = {};
  final Set<dynamic> _toRemove = {};

  @override
  void initState() {
    super.initState();
    _rounds       = widget.circuit.rounds;
    _existingKeys = widget.currentChildren
        .map((e) => e.exerciseKey)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final groups = <String>{
      ..._kMuscleGroups,
      ...widget.allExercises.map((e) => e.muscleGroup),
    }.toList()..sort();
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

    return GlassSheetWrapper(
      title:       'Modifica circuito',
      subtitle:    widget.circuit.name,
      accentColor: _kIndigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundsRow(
            rounds:    _rounds,
            onChanged: (v) => setState(() => _rounds = v),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            hintText:  'Cerca esercizio...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          _MuscleChips(
            groups:   groups,
            selected: _muscle,
            onSelect: (g) => setState(() => _muscle = g),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: ListView.builder(
              physics:   const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final ex          = filtered[i];
                final isExisting  = _existingKeys.contains(ex.key) &&
                    !_toRemove.contains(ex.key);
                final isMarkedRem = _toRemove.contains(ex.key);
                final isMarkedAdd = _toAdd.contains(ex.key);

                return ListTile(
                  dense: true,
                  leading: isExisting
                      ? GestureDetector(
                          onTap: () =>
                              setState(() => _toRemove.add(ex.key)),
                          child: Container(
                            width:  22,
                            height: 22,
                            decoration: BoxDecoration(
                                color:        _kTeal,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          ),
                        )
                      : isMarkedRem
                          ? GestureDetector(
                              onTap: () => setState(
                                  () => _toRemove.remove(ex.key)),
                              child: Container(
                                width:  22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color:        _kRed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _kRed, width: 1.2),
                                ),
                                child: const Icon(Icons.remove_rounded,
                                    size: 14, color: _kRed),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => setState(() {
                                if (isMarkedAdd) {
                                  _toAdd.remove(ex.key);
                                } else if (!_existingKeys
                                    .contains(ex.key)) {
                                  _toAdd.add(ex.key);
                                }
                              }),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                width:  22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isMarkedAdd
                                      ? _kIndigo
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMarkedAdd
                                        ? _kIndigo
                                        : c.glassBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: isMarkedAdd
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                  title: Text(ex.name, style: TextStyle(
                      color: isMarkedRem
                          ? c.textTertiary
                          : c.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      decoration: isMarkedRem
                          ? TextDecoration.lineThrough
                          : null)),
                  subtitle: Text(ex.muscleGroup, style: TextStyle(
                      color: c.textTertiary, fontSize: 11)),
                );
              },
            ),
          ),
          if (hasChanges) ...[
            const SizedBox(height: 10),
            GlassPrimaryButton(
              label: 'Salva modifiche',
              color: _kIndigo,
              onTap: () {
                final toRemoveList = widget.currentChildren
                    .where((we) => _toRemove.contains(we.exerciseKey))
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

class _RenameSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback          onConfirm;
  const _RenameSheet({required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title: 'Rinomina scheda',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: controller,
            hintText:   'Nome scheda...',
            autofocus:  true,
            onChanged:  (_) {},
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            label: 'Rinomina',
            color: _kTeal,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ModeStructurePreview — FIX FASE 3
//
// Rappresenta la struttura PREVISTA da una TrainingMode in sola
// lettura (Parte 6/14/15 del fix): ogni serie della modalità,
// nell'ordine definito, con la propria etichetta (reps fisse
// oppure range "min-max" — TrainingModeSet.label già gestisce
// entrambi i casi). Nessun controllo interattivo: la modifica
// della struttura avviene esclusivamente tramite la Gestione
// modalità, mai da qui.
// ─────────────────────────────────────────────────────────────
class _ModeStructurePreview extends StatelessWidget {
  final TrainingMode  mode;
  final MarkFitColors c;
  const _ModeStructurePreview({required this.mode, required this.c});

  @override
  Widget build(BuildContext context) {
    final ordered = mode.orderedSets;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.glassCardInset,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.glassBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lock_outline_rounded,
                    size: 13, color: c.textTertiary),
                const SizedBox(width: 6),
                Text('Definito dalla modalità', style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
              ]),
              const SizedBox(height: 10),
              if (ordered.isEmpty)
                Text('Nessuna serie definita', style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic))
              else
                ...ordered.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                              color: _kIndigo.withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: Center(child: Text('${s.order}',
                              style: const TextStyle(
                                  color: _kIndigo,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: 10),
                        Text('Serie ${s.order}', style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kCyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kCyan.withOpacity(0.2), width: 0.7),
                          ),
                          child: Text('${s.label} reps', style: const TextStyle(
                              color: _kCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditParamsSheet extends StatefulWidget {
  final HiveWorkoutExercise exercise;
  // FASE 3 — firma estesa con trainingModeKey (dynamic: Hive key).
  // NOTA: sets/reps sono ora SEMPRE calcolati da questo widget prima
  // di essere passati al chiamante — derivati dalla modalità quando
  // presente (FIX), altrimenti dagli stepper legacy. Il chiamante
  // (workout_detail_screen._editExerciseParams) non cambia.
  final void Function(int sets, int reps, double weight, int? rest,
      dynamic trainingModeKey) onConfirm;
  const _EditParamsSheet({required this.exercise, required this.onConfirm});
  @override
  State<_EditParamsSheet> createState() => _EditParamsSheetState();
}

class _EditParamsSheetState extends State<_EditParamsSheet> {
  // Usati SOLO quando l'esercizio non ha una modalità associata
  // (dato legacy — Parte 17 del fix: piena compatibilità con le
  // schede create prima della Fase 3).
  late int    _legacySets, _legacyReps;
  late int    _rest;
  late double _weight;
  dynamic     _selectedModeKey;

  @override
  void initState() {
    super.initState();
    _legacySets = widget.exercise.sets;
    _legacyReps = widget.exercise.targetReps;
    _weight     = widget.exercise.targetWeight ?? 0;
    _rest       = widget.exercise.restSeconds  ?? 60;
    _selectedModeKey = widget.exercise.trainingModeKey;
  }

  Future<void> _openModePicker() async {
    await showModalBottomSheet(
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
              child: TrainingModePickerSheet(
                currentModeKey: _selectedModeKey,
                // FIX: selezionare una nuova modalità aggiorna subito
                // lo stato locale → la struttura visualizzata sotto
                // (letta SEMPRE dalla modalità corrente tramite
                // Provider.getByKey nel build) cambia immediatamente,
                // senza alcun intervento manuale sull'utente.
                onSelect: (m) => setState(() => _selectedModeKey = m.key),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// FIX FASE 3 — deriva (sets, reps legacy) dalla struttura della
  /// modalità selezionata. `reps` è calcolato dalla prima serie
  /// (valore fisso, oppure il minimo se la serie è a range — Parte 13
  /// del fix: "il minimo può essere usato come valore iniziale/
  /// predefinito"), e resta un dato DERIVATO di compatibilità per il
  /// campo legacy HiveWorkoutExercise.targetReps (consumato oggi dalla
  /// generazione della sessione attiva, che la Fase 4 sostituirà con
  /// la copia integrale della struttura). La UI in sola lettura invece
  /// mostra SEMPRE la struttura completa e corretta di ogni serie.
  ({int sets, int reps}) _deriveLegacyFromMode(TrainingMode mode) {
    final ordered = mode.orderedSets;
    if (ordered.isEmpty) {
      return (sets: _legacySets, reps: _legacyReps);
    }
    final first = ordered.first;
    final reps = first.isRange
        ? (first.minReps ?? _legacyReps)
        : (first.fixedReps ?? _legacyReps);
    return (sets: ordered.length, reps: reps);
  }

  void _save(BuildContext context) {
    final mode = _selectedModeKey != null
        ? context.read<TrainingModeProvider>().getByKey(_selectedModeKey)
        : null;
    if (mode != null) {
      final derived = _deriveLegacyFromMode(mode);
      widget.onConfirm(derived.sets, derived.reps, _weight,
          _rest > 0 ? _rest : null, _selectedModeKey);
    } else {
      widget.onConfirm(_legacySets, _legacyReps, _weight,
          _rest > 0 ? _rest : null, _selectedModeKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final currentMode =
        context.watch<TrainingModeProvider>().getByKey(_selectedModeKey);

    return GlassSheetWrapper(
      title:    widget.exercise.exerciseName,
      subtitle: 'Parametri esercizio',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selettore modalità — SEMPRE modificabile (Parte 15).
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: _openModePicker,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: c.glassBlur, sigmaY: c.glassBlur),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _kIndigo.withOpacity(0.25), width: 0.8),
                    ),
                    child: Row(children: [
                      Icon(Icons.repeat_rounded,
                          color: _kIndigo.withOpacity(0.8), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Modalità', style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                            const SizedBox(height: 2),
                            Text(
                              currentMode?.structureLabel ??
                                  'Nessuna (legacy)',
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: c.iconSecondary, size: 18),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // FIX FASE 3 — struttura: SOLA LETTURA derivata dalla
          // modalità quando presente, altrimenti stepper legacy
          // editabili per piena compatibilità con schede pre-Fase 3.
          if (currentMode != null) ...[
            _ModeStructurePreview(mode: currentMode, c: c),
            const SizedBox(height: 14),
          ] else ...[
            _ParamRow(label: 'Serie', value: _legacySets, min: 1, max: 20,
                onChanged: (v) => setState(() => _legacySets = v)),
            _ParamRow(label: 'Ripetizioni', value: _legacyReps, min: 1,
                max: 100,
                onChanged: (v) => setState(() => _legacyReps = v)),
          ],

          // Recupero e peso: SEMPRE editabili — non fanno parte della
          // struttura definita dalla modalità.
          _ParamRow(label: 'Recupero (sec)', value: _rest, min: 0,
              max: 600, step: 15,
              onChanged: (v) => setState(() => _rest = v)),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Text('Peso (kg)', style: TextStyle(
                    color:      c.textSecondary,
                    fontSize:   14,
                    fontWeight: FontWeight.w600)),
                const Spacer(),
                SizedBox(
                  width: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color:        c.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: c.inputBorder,
                            width: isDark ? 0.8 : 1.1),
                      ),
                      child: TextFormField(
                        initialValue: _weight > 0
                            ? _weight.toString() : '',
                        keyboardType: const TextInputType
                            .numberWithOptions(decimal: true),
                        keyboardAppearance: isDark
                            ? Brightness.dark : Brightness.light,
                        textAlign:   TextAlign.center,
                        cursorColor: _kTeal,
                        style: TextStyle(color: c.inputText, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:  '0',
                          hintStyle: TextStyle(color: c.inputHint),
                          border:    InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        onChanged: (v) =>
                            setState(() => _weight = double.tryParse(v) ?? 0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GlassPrimaryButton(
            label: 'Salva parametri',
            color: _kTeal,
            onTap: () => _save(context),
          ),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final String            label;
  final int               value, min, max, step;
  final void Function(int) onChanged;
  const _ParamRow({
    required this.label,   required this.value,
    required this.min,     required this.max,
    required this.onChanged, this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(label, style: TextStyle(
              color: c.textSecondary, fontSize: 14,
              fontWeight: FontWeight.w600)),
          const Spacer(),
          _StepBtn(
            icon:  Icons.remove_rounded,
            onTap: value - step >= min ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.center,
                style: TextStyle(
                    color:      c.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w800)),
          ),
          _StepBtn(
            icon:  Icons.add_rounded,
            onTap: value + step <= max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c       = context.mfc;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:  enabled ? _kCyan.withOpacity(0.1) : c.glassCardInset,
          shape:  BoxShape.circle,
          border: Border.all(
            color: enabled ? _kCyan.withOpacity(0.4) : c.glassBorder,
            width: 1,
          ),
        ),
        child: Icon(icon, size: 18,
            color: enabled ? _kCyan : c.textTertiary),
      ),
    );
  }
}

class _RoundsRow extends StatelessWidget {
  final int                rounds;
  final void Function(int) onChanged;
  const _RoundsRow({required this.rounds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(
      children: [
        Text('Cicli:', style: TextStyle(
            color:      c.textSecondary,
            fontSize:   14,
            fontWeight: FontWeight.w600)),
        const Spacer(),
        _StepBtn(
          icon:  Icons.remove_rounded,
          onTap: rounds > 1 ? () => onChanged(rounds - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text('$rounds', textAlign: TextAlign.center,
              style: TextStyle(
                  color:      c.textPrimary,
                  fontSize:   18,
                  fontWeight: FontWeight.w800)),
        ),
        _StepBtn(
          icon:  Icons.add_rounded,
          onTap: () => onChanged(rounds + 1),
        ),
      ],
    );
  }
}

class _MuscleChips extends StatelessWidget {
  final List<String>          groups;
  final String                selected;
  final void Function(String) onSelect;
  const _MuscleChips({
    required this.groups, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final g   = groups[i];
          final sel = selected == g;
          return GestureDetector(
            onTap: () => onSelect(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel
                    ? _kTeal.withOpacity(0.2)
                    : c.glassCardInset,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? _kTeal.withOpacity(0.6) : c.glassBorder,
                  width: sel ? 1.2 : 0.8,
                ),
                boxShadow: sel
                    ? [BoxShadow(
                        color:     _kTeal.withOpacity(0.15),
                        blurRadius: 8)]
                    : null,
              ),
              child: Text(g, style: TextStyle(
                  color: sel ? _kTeal : c.textTertiary,
                  fontSize:   12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final HiveExercise  exercise;
  final bool          isAlreadyIn, isSelected;
  final VoidCallback? onTap;
  const _ExerciseTile({
    required this.exercise, required this.isAlreadyIn,
    required this.isSelected, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ListTile(
      dense: true,
      leading: isAlreadyIn
          ? Icon(Icons.check_circle,
              color: _kTeal.withOpacity(0.6), size: 20)
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? _kTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? _kTeal : c.glassBorder,
                  width: 1.2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
      title: Text(exercise.name, style: TextStyle(
          color: isAlreadyIn ? c.textTertiary : c.textPrimary,
          fontSize:   14,
          fontWeight: FontWeight.w600)),
      subtitle: Text(exercise.muscleGroup, style: TextStyle(
          color: c.textTertiary, fontSize: 11)),
      enabled: !isAlreadyIn,
      onTap:   onTap,
    );
  }
}