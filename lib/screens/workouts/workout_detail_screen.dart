import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../db/hive_database.dart';

// ─────────────────────────────────────────────
// SNAPSHOT SYSTEM
//
// Cattura lo stato COMPLETO della scheda all'apertura.
// Il fingerprint confronta ordine + tutti i parametri.
// Se l'utente riporta tutto allo stato iniziale → _isDirty = false.
// ─────────────────────────────────────────────

class _ExerciseSnap {
  final int exerciseKey; // chiave box esercizi (stabile tra sessioni)
  final String exerciseName;
  final String muscleGroup;
  final int sets;
  final int targetReps;
  final double targetWeight; // 0.0 se non impostato
  final int restSeconds; // 0 se non impostato
  final String notes; // '' se null o __circuit_
  final int sortOrder;

  _ExerciseSnap.from(HiveWorkoutExercise e)
      : exerciseKey = e.exerciseKey,
        exerciseName = e.exerciseName,
        muscleGroup = e.muscleGroup,
        sets = e.sets,
        targetReps = e.targetReps,
        targetWeight = e.targetWeight ?? 0.0,
        restSeconds = e.restSeconds ?? 0,
        notes = (e.notes == null || e.notes!.startsWith('__circuit_'))
            ? ''
            : e.notes!,
        sortOrder = e.sortOrder;

  String get fingerprint =>
      '$exerciseKey:$exerciseName:$sets:$targetReps'
      ':${targetWeight.toStringAsFixed(3)}:$restSeconds:$notes:$sortOrder';
}

class _CircuitSnap {
  final String name;
  final int rounds;
  final int sortOrder;
  final List<_ExerciseSnap> children;

  _CircuitSnap.from(HiveCircuit c, List<HiveWorkoutExercise> ch)
      : name = c.name,
        rounds = c.rounds,
        sortOrder = c.sortOrder,
        children = ch.map(_ExerciseSnap.from).toList();

  String get fingerprint =>
      '$name:$rounds:$sortOrder'
      ':${children.map((e) => e.fingerprint).join("|")}';
}

class _WorkoutSnap {
  final String fingerprint;
  // Dati necessari per il ripristino (discard)
  final List<_ExerciseSnap> freeExercises;
  final List<_CircuitSnap> circuits;

  const _WorkoutSnap({
    required this.fingerprint,
    required this.freeExercises,
    required this.circuits,
  });
}

// ─────────────────────────────────────────────
// Lista piatta D&D — solo chiavi, mai oggetti
// ─────────────────────────────────────────────

enum _ItemType { exercise, circuit }

class _ListItem {
  final _ItemType type;
  final dynamic refKey;

  _ListItem({required this.type, required this.refKey});

  String get stableId =>
      type == _ItemType.exercise ? 'ex_$refKey' : 'circuit_$refKey';

  Key get widgetKey => ValueKey(stableId);
}

// ─────────────────────────────────────────────
// WorkoutDetailScreen
// ─────────────────────────────────────────────

class WorkoutDetailScreen extends StatefulWidget {
  final dynamic workoutId;
  final String workoutName;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late ExerciseProvider _exerciseProvider;
  late WorkoutProvider _workoutProvider;

  List<HiveCircuit> _circuits = [];
  List<_ListItem> _items = [];
  Map<dynamic, List<HiveWorkoutExercise>> _circuitChildren = {};
  bool _loaded = false;

  Future<void> _persistQueue = Future.value();

  final Map<String, bool> _collapsed = {};
  bool _globalCollapsed = false;

  // ── Snapshot ──────────────────────────────
  _WorkoutSnap? _initialSnapshot;
  bool _isHandlingExit = false;

  bool get _isDirty {
    if (_initialSnapshot == null || !_loaded) return false;
    return _buildCurrentSnapshot().fingerprint != _initialSnapshot!.fingerprint;
  }

  // ─────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _exerciseProvider = context.read<ExerciseProvider>();
    _workoutProvider = context.read<WorkoutProvider>();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    _exerciseProvider.loadExercises();
    _circuits = HiveDatabase.instance.getCircuits(widget.workoutId);
    _workoutProvider.loadWorkoutExercises(widget.workoutId);
    if (!mounted) return;
    setState(() {
      _rebuildAll();
      _loaded = true;
      // Cattura snapshot DOPO il primo rebuild
      _initialSnapshot = _buildCurrentSnapshot();
    });
  }

  // ─────────────────────────────────────────
  // Snapshot — costruzione e confronto
  // ─────────────────────────────────────────

  _WorkoutSnap _buildCurrentSnapshot() {
    final topParts = <String>[];
    final freeExSnaps = <_ExerciseSnap>[];
    final circuitSnaps = <_CircuitSnap>[];

    for (final item in _items) {
      if (item.type == _ItemType.exercise) {
        final we = _findExercise(item.refKey);
        if (we != null) {
          final snap = _ExerciseSnap.from(we);
          topParts.add('ex:${snap.exerciseKey}');
          freeExSnaps.add(snap);
        }
      } else {
        final c = _findCircuit(item.refKey);
        if (c != null) {
          final children = _circuitChildren[c.key] ?? [];
          final snap = _CircuitSnap.from(c, children);
          topParts.add('circuit:${snap.name}');
          circuitSnaps.add(snap);
        }
      }
    }

    final fp = '${topParts.join(",")}'
        '||FX:${freeExSnaps.map((e) => e.fingerprint).join("|")}'
        '||CI:${circuitSnaps.map((c) => c.fingerprint).join("|")}';

    return _WorkoutSnap(
      fingerprint: fp,
      freeExercises: freeExSnaps,
      circuits: circuitSnaps,
    );
  }

  // ─────────────────────────────────────────
  // Exit handling — PopScope + CupertinoActionSheet
  // ─────────────────────────────────────────

  Future<void> _handleExit() async {
    if (_isHandlingExit) return;

    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _isHandlingExit = true;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Modifiche non salvate'),
        message: const Text('Cosa vuoi fare con le modifiche effettuate?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop(); // chiude l'action sheet
              // Attende il completamento della coda di persist
              await _persistQueue;
              // Aggiorna lo snapshot → isDirty diventa false → canPop diventa true
              if (mounted) {
                setState(() =>
                    _initialSnapshot = _buildCurrentSnapshot());
              }
              // Aspetta il rebuild (canPop aggiornato) poi chiude
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
            },
            child: const Text('Salva modifiche'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop(); // chiude l'action sheet
              await _discardChanges();
              // Dopo discard isDirty = false → canPop = true
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
            },
            child: const Text('Scarta modifiche'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(ctx).pop();
            _isHandlingExit = false;
          },
          child: const Text('Annulla'),
        ),
      ),
    );

    _isHandlingExit = false;
  }

  // ─────────────────────────────────────────
  // Discard — ripristino completo dal snapshot
  // ─────────────────────────────────────────

  Future<void> _discardChanges() async {
    final snap = _initialSnapshot;
    if (snap == null) return;

    // 1. Elimina tutti i circuiti (cascade ai figli __circuit_X)
    final currentCircuits =
        HiveDatabase.instance.getCircuits(widget.workoutId);
    for (final c in currentCircuits) {
      await HiveDatabase.instance.deleteCircuit(c.key);
    }

    // 2. Elimina gli esercizi liberi rimasti
    final remaining =
        HiveDatabase.instance.getWorkoutExercises(widget.workoutId);
    for (final ex in remaining) {
      await HiveDatabase.instance.deleteWorkoutExercise(ex.key);
    }

    // 3. Ricrea circuiti + figli dallo snapshot
    for (final cs in snap.circuits) {
      final newKey = await HiveDatabase.instance.addCircuit(HiveCircuit(
        workoutKey: widget.workoutId,
        name: cs.name,
        rounds: cs.rounds,
        sortOrder: cs.sortOrder,
      ));
      for (final child in cs.children) {
        await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
          workoutKey: widget.workoutId,
          exerciseKey: child.exerciseKey,
          exerciseName: child.exerciseName,
          muscleGroup: child.muscleGroup,
          sets: child.sets,
          targetReps: child.targetReps,
          targetWeight: child.targetWeight == 0.0 ? null : child.targetWeight,
          restSeconds: child.restSeconds == 0 ? null : child.restSeconds,
          notes: '__circuit_$newKey',
          sortOrder: child.sortOrder,
        ));
      }
    }

    // 4. Ricrea esercizi liberi dallo snapshot
    for (final es in snap.freeExercises) {
      await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
        workoutKey: widget.workoutId,
        exerciseKey: es.exerciseKey,
        exerciseName: es.exerciseName,
        muscleGroup: es.muscleGroup,
        sets: es.sets,
        targetReps: es.targetReps,
        targetWeight: es.targetWeight == 0.0 ? null : es.targetWeight,
        restSeconds: es.restSeconds == 0 ? null : es.restSeconds,
        notes: es.notes.isEmpty ? null : es.notes,
        sortOrder: es.sortOrder,
      ));
    }

    await _forceRebuild();
    // isDirty sarà false dopo rebuild (fingerprint = initialSnapshot)
  }

  // ─────────────────────────────────────────
  // Lookup live
  // ─────────────────────────────────────────

  HiveWorkoutExercise? _findExercise(dynamic key) {
    for (final e in _workoutProvider.currentExercises) {
      if (e.key == key) return e;
    }
    return null;
  }

  HiveCircuit? _findCircuit(dynamic key) {
    for (final c in _circuits) {
      if (c.key == key) return c;
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Rebuild
  // ─────────────────────────────────────────

  void _rebuildAll() {
    final allEx = _workoutProvider.currentExercises;
    final freeEx = allEx.where((e) => !e.isInCircuit).toList();

    // Crea lista unificata e ordina per sortOrder condiviso
    final topItems = <({int order, bool isCircuit, dynamic key})>[
      ...freeEx.map((e) =>
          (order: e.sortOrder, isCircuit: false, key: e.key as dynamic)),
      ..._circuits.map((c) =>
          (order: c.sortOrder, isCircuit: true, key: c.key as dynamic)),
    ]..sort((a, b) => a.order.compareTo(b.order));

    _items = topItems
        .map((item) => item.isCircuit
            ? _ListItem(type: _ItemType.circuit, refKey: item.key)
            : _ListItem(type: _ItemType.exercise, refKey: item.key))
        .toList();

    _circuitChildren = {
      for (final c in _circuits)
        c.key: allEx
            .where((e) => e.notes == '__circuit_${c.key}')
            .toList(),
    };
  }


  void _syncWithProvider() {
    final allEx = _workoutProvider.currentExercises;
    final freeEx = allEx.where((e) => !e.isInCircuit).toList();

    final validIds = <String>{
      for (final ex in freeEx) 'ex_${ex.key}',
      for (final c in _circuits) 'circuit_${c.key}',
    };
    final localIds = _items.map((i) => i.stableId).toSet();

    if (!(validIds.length == localIds.length &&
        validIds.containsAll(localIds))) {
      _items.removeWhere((i) => !validIds.contains(i.stableId));
      final stillLocal = _items.map((i) => i.stableId).toSet();
      for (final ex in freeEx) {
        if (!stillLocal.contains('ex_${ex.key}')) {
          _items.add(_ListItem(type: _ItemType.exercise, refKey: ex.key));
        }
      }
      for (final c in _circuits) {
        if (!stillLocal.contains('circuit_${c.key}')) {
          _items.add(_ListItem(type: _ItemType.circuit, refKey: c.key));
        }
      }
    }

    for (final c in _circuits) {
      final tag = '__circuit_${c.key}';
      final live = allEx.where((e) => e.notes == tag).toList();
      final liveIds = live.map((e) => e.key).toSet();
      final existing = _circuitChildren[c.key] ?? [];
      final existingIds = existing.map((e) => e.key).toSet();

      if (liveIds.length == existingIds.length &&
          liveIds.containsAll(existingIds)) {
        final byKey = {for (final ex in live) ex.key: ex};
        _circuitChildren[c.key] =
            existing.map((old) => byKey[old.key] ?? old).toList();
        continue;
      }

      final newList =
          existing.where((e) => liveIds.contains(e.key)).toList();
      for (final ex in live) {
        if (!existingIds.contains(ex.key)) newList.add(ex);
      }
      _circuitChildren[c.key] = newList;
    }
  }

  Future<void> _forceRebuild() async {
    _circuits = HiveDatabase.instance.getCircuits(widget.workoutId);
    _workoutProvider.loadWorkoutExercises(widget.workoutId);
    if (!mounted) return;
    setState(() => _rebuildAll());
  }

  // ─────────────────────────────────────────
  // Reorder — persistito nella coda
  // ─────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    final snapshot = List<_ListItem>.from(_items);
    _persistQueue =
        _persistQueue.then((_) => _persistTopLevelOrder(snapshot));
  }

  Future<void> _persistTopLevelOrder(
    List<_ListItem> snapshot) async {
    int unifiedOrder = 0; // Contatore unico per TUTTI gli item

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
            sortOrder: unifiedOrder++, // ← contatore unificato
          ),
        );
      } else {
        final c = _findCircuit(item.refKey);
        if (c == null) continue;
        await HiveDatabase.instance
            .updateCircuitSortOrder(c.key, unifiedOrder++); // ← stesso contatore
      }
    }
    _workoutProvider.loadWorkoutExercises(widget.workoutId);
  }



  // ─────────────────────────────────────────
  // Collapse
  // ─────────────────────────────────────────

  void _toggleCollapsed(String id) =>
      setState(() => _collapsed[id] = !(_collapsed[id] ?? false));

  void _toggleAllCollapsed() {
    setState(() {
      _globalCollapsed = !_globalCollapsed;
      for (final item in _items) {
        _collapsed[item.stableId] = _globalCollapsed;
      }
    });
  }

  bool _isCollapsed(String id) => _collapsed[id] ?? false;

  // ─────────────────────────────────────────
  // Esercizi
  // ─────────────────────────────────────────

  void _showAddExercisesSheet() {
    pushPage(
      context,
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _exerciseProvider),
          ChangeNotifierProvider.value(value: _workoutProvider),
        ],
        child: _SelectExercisesScreen(
          workoutId: widget.workoutId,
          currentExercises: _workoutProvider.currentExercises,
        ),
      ),
    ).then((_) => _forceRebuild());
  }

  void _showEditSheet(HiveWorkoutExercise we) {
    showGlassBottomSheet(
      context: context,
      child: ChangeNotifierProvider.value(
        value: _workoutProvider,
        child: _EditExerciseSheet(workoutExercise: we),
      ),
    ).then((_) => _forceRebuild());
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
            const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Rimuovi esercizio',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16))),
            ]),
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
                _forceRebuild();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Circuiti
  // ─────────────────────────────────────────

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlassSheetHandle(),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
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
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome circuito',
                    hintText: 'Es. Circuito A, Superset...',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Numero di cicli',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Row(children: [
                  _RoundsButton(
                      icon: Icons.remove,
                      onTap: rounds > 1
                          ? () => setModal(() => rounds--)
                          : null),
                  Expanded(
                      child: Center(
                          child: Text('$rounds cicli',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700)))),
                  _RoundsButton(
                      icon: Icons.add,
                      onTap: () => setModal(() => rounds++)),
                ]),
                const SizedBox(height: 20),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: 'Crea circuito',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await HiveDatabase.instance.addCircuit(HiveCircuit(
                      workoutKey: widget.workoutId,
                      name: nameCtrl.text.trim(),
                      rounds: rounds,
                      sortOrder: _circuits.length,
                    ));
                    await _forceRebuild();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCircuitSheet(HiveCircuit circuit) {
    final nameCtrl = TextEditingController(text: circuit.name);
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
          child: SingleChildScrollView(
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
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Nome circuito'),
                ),
                const SizedBox(height: 16),
                Text('Numero di cicli',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Row(children: [
                  _RoundsButton(
                      icon: Icons.remove,
                      onTap: rounds > 1
                          ? () => setModal(() => rounds--)
                          : null),
                  Expanded(
                      child: Center(
                          child: Text('$rounds cicli',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700)))),
                  _RoundsButton(
                      icon: Icons.add,
                      onTap: () => setModal(() => rounds++)),
                ]),
                const SizedBox(height: 20),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: 'Salva',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    await HiveDatabase.instance.updateCircuit(
                        circuit.key, nameCtrl.text.trim(), rounds);
                    await _forceRebuild();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
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
            const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text('Elimina circuito',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
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
                await HiveDatabase.instance.deleteCircuit(circuit.key);
                await _forceRebuild();
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openReorderCircuitScreen(HiveCircuit circuit) {
    final children = _circuitChildren[circuit.key] ?? [];
    pushPage(
      context,
      _ReorderCircuitExercisesScreen(
        circuit: circuit,
        exercises: List<HiveWorkoutExercise>.from(children),
      ),
    ).then((_) => _forceRebuild());
  }

  // ─────────────────────────────────────────
  // Build — PopScope con canPop dinamico
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
            backgroundColor: cs.surface,
            title: Text(widget.workoutName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    context.watch<WorkoutProvider>();
    _syncWithProvider();

    final cs = Theme.of(context).colorScheme;
    final isEmpty = _items.isEmpty;

    // canPop dinamico:
    // - false quando dirty → intercetta back/swipe, mostra dialog
    // - true quando clean → back e swipe funzionano normalmente
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _handleExit,
          ),
          title: Text(widget.workoutName),
          actions: [
            if (!isEmpty)
              IconButton(
                tooltip: _globalCollapsed
                    ? 'Espandi tutto'
                    : 'Compatta tutto',
                icon: Icon(
                  _globalCollapsed
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                  color: cs.primary,
                ),
                onPressed: _toggleAllCollapsed,
              ),
            GlassTextButton(
              onPressed: _showAddCircuitSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.loop_rounded, size: 16, color: cs.tertiary),
                  const SizedBox(width: 4),
                  Text('Circuito',
                      style: TextStyle(color: cs.tertiary)),
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
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 120),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) =>
                    AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: Colors.black38,
                    child: child,
                  ),
                ),
                onReorder: _onReorder,
                children: _items.asMap().entries.map((e) {
                  final index = e.key;
                  final item = e.value;
                  final collapsed = _isCollapsed(item.stableId);

                  if (item.type == _ItemType.exercise) {
                    final we = _findExercise(item.refKey);
                    if (we == null) {
                      return SizedBox.shrink(key: item.widgetKey);
                    }
                    return ReorderableDelayedDragStartListener(
                      key: item.widgetKey,
                      index: index,
                      child: _ExerciseRow(
                        workoutExercise: we,
                        collapsed: collapsed,
                        onToggleCollapse: () =>
                            _toggleCollapsed(item.stableId),
                        onEdit: () => _showEditSheet(we),
                        onDelete: () => _confirmDeleteExercise(we),
                      ),
                    );
                  } else {
                    final circuit = _findCircuit(item.refKey);
                    if (circuit == null) {
                      return SizedBox.shrink(key: item.widgetKey);
                    }
                    final children =
                        _circuitChildren[circuit.key] ?? [];
                    return ReorderableDelayedDragStartListener(
                      key: item.widgetKey,
                      index: index,
                      child: _CircuitCard(
                        circuit: circuit,
                        exercises: children,
                        collapsed: collapsed,
                        onToggleCollapse: () =>
                            _toggleCollapsed(item.stableId),
                        onAddExercise: () {
                          pushPage(
                            context,
                            MultiProvider(
                              providers: [
                                ChangeNotifierProvider.value(
                                    value: _exerciseProvider),
                                ChangeNotifierProvider.value(
                                    value: _workoutProvider),
                              ],
                              child: _SelectExercisesScreen(
                                workoutId: widget.workoutId,
                                circuitKey: circuit.key,
                                currentExercises:
                                    _workoutProvider.currentExercises,
                              ),
                            ),
                          ).then((_) => _forceRebuild());
                        },
                        onEdit: (we) => _showEditSheet(we),
                        onDelete: (we) => _confirmDeleteExercise(we),
                        onDeleteCircuit: () =>
                            _confirmDeleteCircuit(circuit),
                        onEditCircuit: () =>
                            _showEditCircuitSheet(circuit),
                        onReorder: () =>
                            _openReorderCircuitScreen(circuit),
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
                    MediaQuery.of(context).padding.bottom + 16),
                child: GlassButton(
                  onTap: _showAddExercisesSheet,
                  icon: Icons.add_rounded,
                  label: 'Aggiungi esercizi',
                ),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets invariati (identici alla versione precedente)
// ─────────────────────────────────────────────

class _ReorderCircuitExercisesScreen extends StatefulWidget {
  final HiveCircuit circuit;
  final List<HiveWorkoutExercise> exercises;

  const _ReorderCircuitExercisesScreen({
    required this.circuit,
    required this.exercises,
  });

  @override
  State<_ReorderCircuitExercisesScreen> createState() =>
      _ReorderCircuitExercisesScreenState();
}

class _ReorderCircuitExercisesScreenState
    extends State<_ReorderCircuitExercisesScreen> {
  late List<HiveWorkoutExercise> _list;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.exercises);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _list.removeAt(oldIndex);
      _list.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    int order = 0;
    for (final we in _list) {
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
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text('Riordina — ${widget.circuit.name}'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : GlassTextButton(
                  onPressed: _save,
                  child: const Text('Salva'),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: _list.isEmpty
          ? Center(
              child: Text('Nessun esercizio nel circuito',
                  style: TextStyle(color: cs.outline)))
          : ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) =>
                  AnimatedBuilder(
                animation: animation,
                builder: (_, __) => Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  shadowColor: Colors.black38,
                  child: child,
                ),
              ),
              onReorder: _onReorder,
              children: _list.asMap().entries.map((e) {
                final we = e.value;
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('reorder_${we.key}'),
                  index: e.key,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.drag_handle_rounded,
                          color: cs.outline.withOpacity(0.5)),
                      title: Text(we.exerciseName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(we.muscleGroup),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _RoundsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundsButton({required this.icon, required this.onTap});

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
                  : cs.primary.withOpacity(0.3)),
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
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onAddExercise;
  final void Function(HiveWorkoutExercise) onEdit;
  final void Function(HiveWorkoutExercise) onDelete;
  final VoidCallback onDeleteCircuit;
  final VoidCallback onEditCircuit;
  final VoidCallback onReorder;

  const _CircuitCard({
    required this.circuit,
    required this.exercises,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onAddExercise,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteCircuit,
    required this.onEditCircuit,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.tertiaryContainer.withOpacity(0.15)
            : cs.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: cs.tertiary.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggleCollapse,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
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
                        Text(circuit.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: cs.onSurface)),
                        Text(
                          collapsed
                              ? '${circuit.rounds} cicli · ${exercises.length} eserc.'
                              : '${circuit.rounds} cicl${circuit.rounds == 1 ? 'o' : 'i'}',
                          style:
                              TextStyle(fontSize: 12, color: cs.tertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: cs.tertiary,
                    size: 20,
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
          ),
          if (!collapsed) ...[
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Nessun esercizio nel circuito',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                        fontStyle: FontStyle.italic)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: exercises
                      .map((ex) => _ExerciseRow(
                            key: ValueKey('circuit_child_${ex.key}'),
                            workoutExercise: ex,
                            collapsed: false,
                            onToggleCollapse: () {},
                            onEdit: () => onEdit(ex),
                            onDelete: () => onDelete(ex),
                            compact: true,
                          ))
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  if (exercises.length > 1)
                    Expanded(
                      child: GlassOutlinedButton(
                        onPressed: onReorder,
                        foregroundColor: cs.tertiary,
                        borderColor: cs.tertiary.withOpacity(0.4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_vert_rounded,
                                size: 16, color: cs.tertiary),
                            const SizedBox(width: 6),
                            Text('Riordina',
                                style: TextStyle(
                                    fontSize: 13, color: cs.tertiary)),
                          ],
                        ),
                      ),
                    ),
                  if (exercises.length > 1) const SizedBox(width: 8),
                  Expanded(
                    child: GlassOutlinedButton(
                      onPressed: onAddExercise,
                      foregroundColor: cs.tertiary,
                      borderColor: cs.tertiary.withOpacity(0.4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 16, color: cs.tertiary),
                          const SizedBox(width: 6),
                          Text('Aggiungi',
                              style: TextStyle(
                                  fontSize: 13, color: cs.tertiary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: exercises
                    .map((ex) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                cs.tertiaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(ex.exerciseName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onTertiaryContainer)),
                        ))
                    .toList(),
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
                  color: cs.secondaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.fitness_center_outlined,
                  size: 40, color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: 20),
            Text('Scheda vuota',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
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
                minWidth: 220),
            const SizedBox(height: 12),
            GlassOutlinedButton(
              onPressed: onAddCircuit,
              foregroundColor: cs.tertiary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.loop_rounded, size: 16, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Text('Crea circuito',
                      style: TextStyle(color: cs.tertiary)),
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
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  const _ExerciseRow({
    super.key,
    required this.workoutExercise,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final we = workoutExercise;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.8) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? Colors.white.withOpacity(0.1) : cs.outlineVariant,
          width: 1.2,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                    color: Colors.black
                        .withOpacity(isDark ? 0.15 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1))
              ],
      ),
      child: collapsed
          ? _CompactTile(
              we: we,
              cs: cs,
              onExpand: onToggleCollapse,
              onEdit: onEdit,
              onDelete: onDelete)
          : _ExpandedTile(
              we: we,
              cs: cs,
              isDark: isDark,
              compact: compact,
              onCollapse: onToggleCollapse,
              onEdit: onEdit,
              onDelete: onDelete),
    );
  }
}

class _CompactTile extends StatelessWidget {
  final HiveWorkoutExercise we;
  final ColorScheme cs;
  final VoidCallback onExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompactTile({
    required this.we,
    required this.cs,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.drag_handle_rounded,
                color: cs.outline.withOpacity(0.4), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(we.exerciseName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${we.sets} serie · ${we.targetReps} reps'
                    '${we.targetWeight != null && we.targetWeight! > 0 ? ' · ${we.targetWeight} kg' : ''}',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.edit_outlined,
                    size: 14, color: cs.primary),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline,
                    size: 14, color: Colors.red),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded,
                size: 18, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

class _ExpandedTile extends StatelessWidget {
  final HiveWorkoutExercise we;
  final ColorScheme cs;
  final bool isDark;
  final bool compact;
  final VoidCallback onCollapse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpandedTile({
    required this.we,
    required this.cs,
    required this.isDark,
    required this.compact,
    required this.onCollapse,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          14, compact ? 10 : 12, 14, compact ? 8 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!compact)
            GestureDetector(
              onTap: onCollapse,
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                  ],
                ),
              ),
              if (!compact)
                GestureDetector(
                  onTap: onCollapse,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.expand_less_rounded,
                        size: 18, color: cs.outline),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _InfoChip(label: '${we.sets} serie'),
              _InfoChip(label: '${we.targetReps} reps'),
              if (we.targetWeight != null && we.targetWeight! > 0)
                _InfoChip(label: '${we.targetWeight} kg'),
              if (we.restSeconds != null)
                _InfoChip(label: '${we.restSeconds}s rec.'),
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
                  onTap: onEdit),
              const SizedBox(width: 8),
              _SmallGlassButton(
                  label: 'Rimuovi',
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onTap: onDelete),
            ],
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: cs.onSecondaryContainer)),
    );
  }
}

class _SelectExercisesScreen extends StatefulWidget {
  final dynamic workoutId;
  final dynamic circuitKey;
  final List<HiveWorkoutExercise> currentExercises;

  const _SelectExercisesScreen({
    required this.workoutId,
    required this.currentExercises,
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

  @override
  void initState() {
    super.initState();
    context.read<ExerciseProvider>().loadExercises();
  }

  void _toggle(dynamic key) => setState(() => _selected.contains(key)
      ? _selected.remove(key)
      : _selected.add(key));

  Future<void> _confirmAdd() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final allEx = context.read<ExerciseProvider>().exercises;
      final provider = context.read<WorkoutProvider>();
      final existing = widget.currentExercises;
      final sel = _selected.toList();
      final toAdd = <HiveWorkoutExercise>[];
      for (int i = 0; i < sel.length; i++) {
        final matches = allEx.where((e) => e.key == sel[i]);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEx = context.watch<ExerciseProvider>().exercises;
    final muscleGroups =
        ({...allEx.map((e) => e.muscleGroup)}.toList()..sort());
    final groups = ['Tutti', ...muscleGroups];
    final filtered = allEx.where((e) {
      final mm =
          _muscleFilter == 'Tutti' || e.muscleGroup == _muscleFilter;
      final ms = _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
      return mm && ms;
    }).toList();

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
                            strokeWidth: 2)))
                : GlassTextButton(
                    onPressed: _confirmAdd,
                    child: const Text('Aggiungi')),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Cerca esercizio...',
                prefixIcon: Icon(Icons.search),
                isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
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
                onSelected: (_) =>
                    setState(() => _muscleFilter = g),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: allEx.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Caricamento esercizi...',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context
                              .read<ExerciseProvider>()
                              .loadExercises(),
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final ex = filtered[i];
                    final isSel = _selected.contains(ex.key);
                    final alreadyAdded =
                        widget.currentExercises.any((we) {
                      if (we.exerciseKey != ex.key) return false;
                      return widget.circuitKey != null
                          ? we.notes ==
                              '__circuit_${widget.circuitKey}'
                          : !we.isInCircuit;
                    });
                    return ListTile(
                      leading: alreadyAdded
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)
                          : Checkbox(
                              value: isSel,
                              onChanged: (_) => _toggle(ex.key)),
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
                      onTap:
                          alreadyAdded ? null : () => _toggle(ex.key),
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
      ]),
    );
  }
}

class _EditExerciseSheet extends StatefulWidget {
  final HiveWorkoutExercise workoutExercise;
  const _EditExerciseSheet({required this.workoutExercise});

  @override
  State<_EditExerciseSheet> createState() => _EditExerciseSheetState();
}

class _EditExerciseSheetState extends State<_EditExerciseSheet> {
  late final TextEditingController _restCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();
  late List<_SerieRow> _series;

  @override
  void initState() {
    super.initState();
    final we = widget.workoutExercise;
    _restCtrl =
        TextEditingController(text: we.restSeconds?.toString() ?? '');
    final displayNotes =
        (we.notes != null && we.notes!.startsWith('__circuit_'))
            ? ''
            : we.notes ?? '';
    _notesCtrl = TextEditingController(text: displayNotes);
    _series = List.generate(we.sets,
        (i) => _SerieRow(
            reps: we.targetReps, weight: we.targetWeight ?? 0));
  }

  @override
  void dispose() {
    _restCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addSerie() {
    setState(() {
      final last = _series.isNotEmpty ? _series.last : null;
      _series.add(_SerieRow(
        reps: last?.reps ?? widget.workoutExercise.targetReps,
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
    final orig = we.notes;
    final isCirc = orig != null && orig.startsWith('__circuit_');
    final newNotes = isCirc
        ? orig
        : (_notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim());

    context.read<WorkoutProvider>().updateExerciseInWorkout(
        we.key,
        HiveWorkoutExercise(
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
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCircuit = widget.workoutExercise.isInCircuit;

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
                  style: Theme.of(context).textTheme.titleMedium),
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
                    prefixIcon: Icon(Icons.timer_outlined)),
                keyboardType: TextInputType.number,
              ),
              if (!isCircuit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Es. presa prona, ROM completo...',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Text('Serie',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                _SmallGlassButton(
                    label: 'Aggiungi',
                    icon: Icons.add,
                    color: cs.primary,
                    onTap: _addSerie),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  const SizedBox(width: 32),
                  Expanded(
                      child: Text('Peso kg',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: cs.outline))),
                  Expanded(
                      child: Text('Reps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: cs.outline))),
                  const SizedBox(width: 32),
                ]),
              ),
              const SizedBox(height: 4),
              ..._series.asMap().entries.map((entry) {
                final i = entry.key;
                return _SerieEditRow(
                  index: i,
                  serie: entry.value,
                  canDelete: _series.length > 1,
                  onDelete: () => _removeSerie(i),
                  onChanged: (w, r) => setState(() =>
                      _series[i] = _SerieRow(weight: w, reps: r)),
                );
              }),
              const SizedBox(height: 20),
              GlassFilledButton(
                  onPressed: _save, child: const Text('Salva')),
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
  final void Function(double w, int r) onChanged;

  const _SerieEditRow({
    required this.index,
    required this.serie,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_SerieEditRow> createState() => _SerieEditRowState();
}

class _SerieEditRowState extends State<_SerieEditRow> {
  late TextEditingController _wCtrl;
  late TextEditingController _rCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(
        text: widget.serie.weight > 0
            ? widget.serie.weight.toString()
            : '');
    _rCtrl =
        TextEditingController(text: widget.serie.reps.toString());
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _rCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: Text('${widget.index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: cs.primary)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _wCtrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => widget.onChanged(
                double.tryParse(v) ?? 0,
                int.tryParse(_rCtrl.text) ?? widget.serie.reps,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _rCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                hintText: '8',
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => widget.onChanged(
                double.tryParse(_wCtrl.text) ??
                    widget.serie.weight,
                int.tryParse(v) ?? widget.serie.reps,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: widget.canDelete
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 18, color: Colors.red),
                  onPressed: widget.onDelete)
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}