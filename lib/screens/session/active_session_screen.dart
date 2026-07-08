import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';

// ─────────────────────────────────────────────────────────────
// ActiveSessionScreen — tracker sessione LIVE.
//
// Responsabilità ESCLUSIVA di questo file:
//   avviare una sessione, registrare serie/peso/reps,
//   gestire timer elapsed e timer recupero, salvare nello storico.
//
// NON contiene WorkoutDetailScreen (editor struttura scheda).
// WorkoutDetailScreen vive in workout_detail_screen.dart.
//
// Flusso:
//   SessionSelectorScreen
//     → seleziona scheda
//     → pushPage(ActiveSessionScreen)   ← questo file
//
//   WorkoutsScreen / AllenamentiScreen
//     → apri/modifica scheda
//     → pushPage(WorkoutDetailScreen)   ← workout_detail_screen.dart
// ─────────────────────────────────────────────────────────────

// ── Modello dati per una singola serie durante la sessione ──

class _SetData {
  double weight;
  int reps;
  bool completed;

  _SetData({
    required this.weight,
    required this.reps,
    this.completed = false,
  });
}

// ── Lista piatta della sessione: esercizio libero o circuito ──

sealed class _SessionItem {}

class _FreeExerciseItem extends _SessionItem {
  final HiveWorkoutExercise exercise;
  _FreeExerciseItem(this.exercise);
}

class _CircuitItem extends _SessionItem {
  final HiveCircuit circuit;
  final List<HiveWorkoutExercise> children;
  _CircuitItem(this.circuit, this.children);
}

// ─────────────────────────────────────────────────────────────
// ActiveSessionScreen
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
  // Sessione DB
  dynamic _sessionKey;
  bool _initialized = false;
  bool _finishing = false;

  // Lista esercizi organizzata
  List<_SessionItem> _items = [];

  // Dati serie: key HiveWorkoutExercise → lista _SetData
  final Map<dynamic, List<_SetData>> _setData = {};

  // Timer elapsed
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // Timer recupero
  Timer? _restTimer;
  int _restRemaining = 0;
  String? _restExerciseName;
  int? _restSetIndex;

  // ── Init ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final db = HiveDatabase.instance;
    final allEx = db.getWorkoutExercises(widget.workoutId);
    final circuits = db.getCircuits(widget.workoutId);

    allEx.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    circuits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Pre-popola dati da ultima sessione
    for (final ex in allEx) {
      final lastSets = db.getLastExerciseSets(ex.exerciseKey);
      final sets = List.generate(ex.sets, (i) {
        double w = ex.targetWeight ?? 0;
        int r = ex.targetReps;
        if (i < lastSets.length && lastSets[i].completed) {
          w = lastSets[i].weight;
          r = lastSets[i].reps;
        }
        return _SetData(weight: w, reps: r);
      });
      _setData[ex.key] = sets;
    }

    // Costruisce lista piatta: esercizi liberi → circuiti
    final freeEx = allEx.where((e) => !e.isInCircuit).toList();
    final items = <_SessionItem>[
      ...freeEx.map(_FreeExerciseItem.new),
      ...circuits.map((c) {
        final children = allEx
            .where((e) => e.notes == '__circuit_${c.key}')
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return _CircuitItem(c, children);
      }),
    ];

    // Crea la sessione nel DB
    final sessionKey = await db.createSession(
      widget.workoutId,
      widget.workoutName,
    );

    // Avvia timer elapsed
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    if (mounted) {
      setState(() {
        _sessionKey = sessionKey;
        _items = items;
        _initialized = true;
      });
    }
  }

  // ── Timer recupero ──────────────────────────────────────────

  void _startRestTimer(int seconds, String exerciseName, int setIndex) {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = seconds;
      _restExerciseName = exerciseName;
      _restSetIndex = setIndex;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() {
          _restRemaining = 0;
          _restExerciseName = null;
          _restSetIndex = null;
        });
        NotificationService.instance.playRestDone();
      } else {
        setState(() => _restRemaining--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = 0;
      _restExerciseName = null;
      _restSetIndex = null;
    });
  }

  // ── Toggle completamento serie ──────────────────────────────

  void _toggleSet(dynamic exKey, int setIdx, int? restSeconds,
      String exerciseName) {
    final sets = _setData[exKey];
    if (sets == null || setIdx >= sets.length) return;
    final wasCompleted = sets[setIdx].completed;
    setState(() => sets[setIdx].completed = !wasCompleted);
    if (!wasCompleted && (restSeconds ?? 0) > 0) {
      _startRestTimer(restSeconds!, exerciseName, setIdx);
    }
  }

  // ── Statistiche ─────────────────────────────────────────────

  int get _completedSets => _setData.values
      .fold(0, (s, l) => s + l.where((d) => d.completed).length);

  int get _totalSets =>
      _setData.values.fold(0, (s, l) => s + l.length);

  double get _progress =>
      _totalSets > 0 ? _completedSets / _totalSets : 0.0;

  // ── Uscita ──────────────────────────────────────────────────

  Future<void> _handleExit() async {
    final hasCompleted = _completedSets > 0;

    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(hasCompleted
            ? 'Sessione in corso'
            : 'Uscire dalla sessione?'),
        message: Text(hasCompleted
            ? 'Hai completato $_completedSets/$_totalSets serie.'
            : 'Non hai ancora completato nessuna serie.'),
        actions: [
          if (hasCompleted)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Salva e termina'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Annulla sessione'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('Continua allenamento'),
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'save') {
      await _saveSession();
    } else if (result == 'discard') {
      _elapsedTimer?.cancel();
      _restTimer?.cancel();
      // Elimina sessione vuota dal DB se nessuna serie completata
      if (_sessionKey != null && _completedSets == 0) {
        await HiveDatabase.instance.deleteSession(_sessionKey);
      }
      if (mounted) Navigator.of(context).pop();
    }
    // 'cancel' o null → rimane nella schermata
  }

  // ── Salvataggio ─────────────────────────────────────────────

  Future<void> _saveSession() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    _elapsedTimer?.cancel();
    _restTimer?.cancel();

    if (_sessionKey != null) {
      for (final item in _items) {
        if (item is _FreeExerciseItem) {
          await _saveExerciseSets(item.exercise, _sessionKey);
        } else if (item is _CircuitItem) {
          for (final ex in item.children) {
            await _saveExerciseSets(ex, _sessionKey);
          }
        }
      }
      await HiveDatabase.instance
          .updateSessionDuration(_sessionKey, _elapsedSeconds);
    }

    if (mounted) {
      // Ricarica provider sessioni se presente nel contesto
      try {
        context.read<WorkoutProvider>().loadWorkouts();
      } catch (_) {}
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveExerciseSets(
      HiveWorkoutExercise ex, dynamic sessionKey) async {
    final sets = _setData[ex.key] ?? [];
    for (int i = 0; i < sets.length; i++) {
      await HiveDatabase.instance.addSessionSet(HiveSessionSet(
        sessionKey: sessionKey,
        exerciseKey: ex.exerciseKey,
        exerciseName: ex.exerciseName,
        muscleGroup: ex.muscleGroup,
        setNumber: i + 1,
        weight: sets[i].weight,
        reps: sets[i].reps,
        completed: sets[i].completed,
        restSeconds: ex.restSeconds,
      ));
    }
  }

  // ── Formato tempo ────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────

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
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                _fmtTime(_elapsedSeconds),
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
                    onPressed: _saveSession,
                    foregroundColor: cs.primary,
                    child: const Text(
                      'Termina',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // Banner recupero attivo
            if (_restRemaining > 0 && _restExerciseName != null) ...[
              _RestBanner(
                remaining: _restRemaining,
                exerciseName: _restExerciseName!,
                setIndex: _restSetIndex ?? 0,
                onSkip: _skipRest,
              ),
              const SizedBox(height: 8),
            ],

            // Barra avanzamento
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: cs.primary.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_completedSets / $_totalSets serie completate',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
            const SizedBox(height: 16),

            // Lista esercizi e circuiti
            ..._items.map((item) {
              if (item is _FreeExerciseItem) {
                final ex = item.exercise;
                return _ExerciseCard(
                  exercise: ex,
                  sets: _setData[ex.key] ?? [],
                  onToggleSet: (i) => _toggleSet(
                      ex.key, i, ex.restSeconds, ex.exerciseName),
                  onWeightChanged: (i, w) => setState(
                      () => (_setData[ex.key] ?? [])[i].weight = w),
                  onRepsChanged: (i, r) => setState(
                      () => (_setData[ex.key] ?? [])[i].reps = r),
                );
              } else if (item is _CircuitItem) {
                return _CircuitSessionCard(
                  circuit: item.circuit,
                  children: item.children,
                  setData: _setData,
                  onToggleSet: (ex, i) => _toggleSet(
                      ex.key, i, ex.restSeconds, ex.exerciseName),
                  onWeightChanged: (ex, i, w) => setState(
                      () => (_setData[ex.key] ?? [])[i].weight = w),
                  onRepsChanged: (ex, i, r) => setState(
                      () => (_setData[ex.key] ?? [])[i].reps = r),
                );
              }
              return const SizedBox.shrink();
            }),
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
            onTap: _finishing ? () {} : _saveSession,
            icon: Icons.check_circle_outline_rounded,
            label: _finishing ? 'Salvataggio...' : 'Termina sessione',
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _RestBanner
// ─────────────────────────────────────────────────────────────

class _RestBanner extends StatelessWidget {
  final int remaining;
  final String exerciseName;
  final int setIndex;
  final VoidCallback onSkip;

  const _RestBanner({
    required this.remaining,
    required this.exerciseName,
    required this.setIndex,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: cs.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recupero',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$exerciseName — serie ${setIndex + 1}',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassTextButton(
            onPressed: onSkip,
            child: const Text('Salta'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseCard — card esercizio durante la sessione
// ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final HiveWorkoutExercise exercise;
  final List<_SetData> sets;
  final void Function(int) onToggleSet;
  final void Function(int, double) onWeightChanged;
  final void Function(int, int) onRepsChanged;
  final bool compact;

  const _ExerciseCard({
    required this.exercise,
    required this.sets,
    required this.onToggleSet,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.8) : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : cs.outlineVariant,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header esercizio
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  exercise.muscleGroup,
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                if (exercise.restSeconds != null &&
                    exercise.restSeconds! > 0)
                  Text(
                    'Recupero: ${exercise.restSeconds}s',
                    style: TextStyle(
                        fontSize: 11, color: cs.primary.withOpacity(0.7)),
                  ),
              ],
            ),
          ),

          // Intestazioni colonne
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Text(
                    'Peso (kg)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Reps',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 52),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Righe serie
          ...sets.asMap().entries.map(
                (e) => _SetRow(
                  index: e.key,
                  data: e.value,
                  onToggle: () => onToggleSet(e.key),
                  onWeightChanged: (w) => onWeightChanged(e.key, w),
                  onRepsChanged: (r) => onRepsChanged(e.key, r),
                ),
              ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SetRow — riga singola serie
// ─────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final int index;
  final _SetData data;
  final VoidCallback onToggle;
  final void Function(double) onWeightChanged;
  final void Function(int) onRepsChanged;

  const _SetRow({
    required this.index,
    required this.data,
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
    final w = widget.data.weight;
    _wCtrl = TextEditingController(
      text: w > 0
          ? (w % 1 == 0 ? w.toInt().toString() : w.toString())
          : '',
    );
    _rCtrl = TextEditingController(text: '${widget.data.reps}');
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
    final done = widget.data.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: done ? cs.primary.withOpacity(0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Numero serie
          SizedBox(
            width: 36,
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

          // Campo peso
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _wCtrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  filled: done,
                  fillColor:
                      done ? cs.primary.withOpacity(0.05) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  color: done ? cs.primary : null,
                  fontWeight:
                      done ? FontWeight.w600 : FontWeight.normal,
                ),
                onChanged: (v) =>
                    widget.onWeightChanged(double.tryParse(v) ?? 0),
              ),
            ),
          ),

          // Campo reps
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _rCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  filled: done,
                  fillColor:
                      done ? cs.primary.withOpacity(0.05) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  color: done ? cs.primary : null,
                  fontWeight:
                      done ? FontWeight.w600 : FontWeight.normal,
                ),
                onChanged: (v) =>
                    widget.onRepsChanged(int.tryParse(v) ?? 0),
              ),
            ),
          ),

          // Pulsante completa
          GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
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
                size: 22,
                color: done ? cs.onPrimary : cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CircuitSessionCard — circuito durante la sessione
// ─────────────────────────────────────────────────────────────

class _CircuitSessionCard extends StatelessWidget {
  final HiveCircuit circuit;
  final List<HiveWorkoutExercise> children;
  final Map<dynamic, List<_SetData>> setData;
  final void Function(HiveWorkoutExercise, int) onToggleSet;
  final void Function(HiveWorkoutExercise, int, double) onWeightChanged;
  final void Function(HiveWorkoutExercise, int, int) onRepsChanged;

  const _CircuitSessionCard({
    required this.circuit,
    required this.children,
    required this.setData,
    required this.onToggleSet,
    required this.onWeightChanged,
    required this.onRepsChanged,
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
        border: Border.all(
          color: cs.tertiary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header circuito
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.loop_rounded,
                    color: cs.onTertiaryContainer,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        circuit.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${circuit.rounds} cicl${circuit.rounds == 1 ? 'o' : 'i'} · ${children.length} esercizi',
                        style: TextStyle(
                            fontSize: 12, color: cs.tertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Esercizi del circuito
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Nessun esercizio nel circuito',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: children
                    .map(
                      (ex) => _ExerciseCard(
                        exercise: ex,
                        sets: setData[ex.key] ?? [],
                        compact: true,
                        onToggleSet: (i) => onToggleSet(ex, i),
                        onWeightChanged: (i, w) =>
                            onWeightChanged(ex, i, w),
                        onRepsChanged: (i, r) =>
                            onRepsChanged(ex, i, r),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}