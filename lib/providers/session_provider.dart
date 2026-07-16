import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../db/hive_database.dart';
import '../models/hive_models.dart';
import '../services/notification_service.dart';

class ActiveSet {
  int setNumber;
  double weight;
  int reps;
  bool completed;
  double? lastWeight;
  int? lastReps;
  int? restSeconds;

  ActiveSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.completed = false,
    this.lastWeight,
    this.lastReps,
    this.restSeconds,
  });

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'weight': weight,
        'reps': reps,
        'completed': completed,
        'lastWeight': lastWeight,
        'lastReps': lastReps,
        'restSeconds': restSeconds,
      };

  factory ActiveSet.fromJson(Map<String, dynamic> j) => ActiveSet(
        setNumber: j['setNumber'] as int,
        weight: (j['weight'] as num).toDouble(),
        reps: j['reps'] as int,
        completed: j['completed'] as bool? ?? false,
        lastWeight: (j['lastWeight'] as num?)?.toDouble(),
        lastReps: j['lastReps'] as int?,
        restSeconds: j['restSeconds'] as int?,
      );
}

class SessionExercise {
  final dynamic exerciseKey;
  final String exerciseName;
  final String muscleGroup;
  final int? restSeconds;
  final String? notes;
  String? sessionNote;
  final String? circuitId;

  SessionExercise({
    required this.exerciseKey,
    required this.exerciseName,
    required this.muscleGroup,
    this.restSeconds,
    this.notes,
    this.sessionNote,
    this.circuitId,
  });

  dynamic get exerciseId => exerciseKey;
  bool get isInCircuit => circuitId != null;

  Map<String, dynamic> toJson() => {
        'exerciseKey': exerciseKey,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'restSeconds': restSeconds,
        'notes': notes,
        'sessionNote': sessionNote,
        'circuitId': circuitId,
      };

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        exerciseKey: j['exerciseKey'],
        exerciseName: j['exerciseName'] as String,
        muscleGroup: j['muscleGroup'] as String,
        restSeconds: j['restSeconds'] as int?,
        notes: j['notes'] as String?,
        sessionNote: j['sessionNote'] as String?,
        circuitId: j['circuitId'] as String?,
      );
}

class SessionProvider extends ChangeNotifier {
  dynamic currentSessionKey;
  DateTime? _sessionStartTime;
  HiveWorkout? _currentWorkout;

  HiveWorkout? get currentWorkout => _currentWorkout;

  final Map<dynamic, List<ActiveSet>> _exerciseSets = {};
  final List<SessionExercise> _sessionExercises = [];
  final Map<String, List<Map<dynamic, List<ActiveSet>>>> _circuitRoundSets = {};
  final Map<String, int> _currentRound = {};
  final Map<String, int> _circuitTotalRounds = {};

  Box? _pauseBox;
  static const _pauseBoxName = 'paused_session';
  static const _activeSaveKey = 'active';
  static const _legacyKey = 'current';
  static const _pausedListKey = 'paused_list';

  List<Map<String, dynamic>> _pausedList = [];

  List<Map<String, dynamic>> get pausedSessions =>
      List.unmodifiable(_pausedList);

  bool get hasPausedSessions => _pausedList.isNotEmpty;

  bool hasPausedSessionForWorkout(dynamic workoutKey) {
    if (workoutKey == null) return false;
    final wk = workoutKey.toString();
    return _pausedList.any((s) => s['workoutKey']?.toString() == wk);
  }

  Map<String, dynamic>? getMostRecentPausedForWorkout(dynamic workoutKey) {
    if (workoutKey == null) return null;
    final wk = workoutKey.toString();
    try {
      return _pausedList
          .lastWhere((s) => s['workoutKey']?.toString() == wk);
    } catch (_) {
      return null;
    }
  }

  int getPausedCompletedSets(Map<String, dynamic> data) {
    int n = 0;
    final sets = data['exerciseSets'] as Map<String, dynamic>? ?? {};
    for (final setList in sets.values) {
      n += (setList as List)
          .where((s) => (s as Map)['completed'] == true)
          .length;
    }
    final circuits =
        data['circuitRoundSets'] as Map<String, dynamic>? ?? {};
    for (final rounds in circuits.values) {
      for (final roundMap in (rounds as List)) {
        for (final setList
            in (roundMap as Map<String, dynamic>).values) {
          n += (setList as List)
              .where((s) => (s as Map)['completed'] == true)
              .length;
        }
      }
    }
    return n;
  }

  int getPausedTotalSets(Map<String, dynamic> data) {
    int n = 0;
    final sets = data['exerciseSets'] as Map<String, dynamic>? ?? {};
    for (final setList in sets.values) {
      n += (setList as List).length;
    }
    final circuits =
        data['circuitRoundSets'] as Map<String, dynamic>? ?? {};
    for (final rounds in circuits.values) {
      for (final roundMap in (rounds as List)) {
        for (final setList
            in (roundMap as Map<String, dynamic>).values) {
          n += (setList as List).length;
        }
      }
    }
    return n;
  }

  Timer? _restTimer;
  int _restElapsed = 0;
  dynamic _restingExerciseKey;
  int? _restingSetIndex;
  bool _restDoneNotified = false;

  int get restElapsed => _restElapsed;
  bool get isResting => _restTimer != null && _restTimer!.isActive;
  dynamic get restingExerciseId => _restingExerciseKey;
  int? get restingSetIndex => _restingSetIndex;

  Map<dynamic, List<ActiveSet>> get exerciseSets => _exerciseSets;
  List<SessionExercise> get sessionExercises => _sessionExercises;

  bool get hasActiveSession =>
      currentSessionKey != null && _sessionExercises.isNotEmpty;

  bool get hasAnyData {
    final hasCompleted =
        _exerciseSets.values.expand((s) => s).any((s) => s.completed);
    final hasCircuitData = _circuitRoundSets.values.any((rounds) =>
        rounds.any((round) =>
            round.values.expand((s) => s).any((s) => s.completed)));
    return hasCompleted || hasCircuitData;
  }

  int get elapsedSeconds => _sessionStartTime != null
      ? DateTime.now().difference(_sessionStartTime!).inSeconds
      : 0;

  int get completedSetsCount {
    int n = 0;
    for (final sets in _exerciseSets.values) {
      n += sets.where((s) => s.completed).length;
    }
    for (final rounds in _circuitRoundSets.values) {
      for (final round in rounds) {
        for (final sets in round.values) {
          n += sets.where((s) => s.completed).length;
        }
      }
    }
    return n;
  }

  int get totalSetsCount {
    int n = 0;
    for (final sets in _exerciseSets.values) {
      n += sets.length;
    }
    for (final rounds in _circuitRoundSets.values) {
      for (final round in rounds) {
        for (final sets in round.values) {
          n += sets.length;
        }
      }
    }
    return n;
  }

  int getCurrentRound(String circuitId) => _currentRound[circuitId] ?? 0;
  int getTotalRounds(String circuitId) => _circuitTotalRounds[circuitId] ?? 1;

  List<ActiveSet> getCircuitSets(String circuitId, dynamic exerciseKey) {
    final round = _currentRound[circuitId] ?? 0;
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) return [];
    return rounds[round][exerciseKey] ?? [];
  }

  // ── Nomi circuiti sesssione (solo in-memory) ──────────────
  final Map<String, String> _sessionCircuitNames = {};

  String getCircuitName(String circuitId) =>
      _sessionCircuitNames[circuitId] ?? 'Circuito';

  void nextRound(String circuitId) {
    final total = _circuitTotalRounds[circuitId] ?? 1;
    final current = _currentRound[circuitId] ?? 0;
    if (current < total - 1) {
      _currentRound[circuitId] = current + 1;
      _savePausedState();
      notifyListeners();
    }
  }

  void prevRound(String circuitId) {
    final current = _currentRound[circuitId] ?? 0;
    if (current > 0) {
      _currentRound[circuitId] = current - 1;
      _savePausedState();
      notifyListeners();
    }
  }

  void reorderSessionExercisesFlat(List<SessionExercise> newOrder) {
    _sessionExercises.clear();
    _sessionExercises.addAll(newOrder);
    _savePausedState();
    notifyListeners();
  }

  void reorderCircuitExercises(
      String circuitId, List<SessionExercise> reordered) {
    final newKeyOrder = reordered.map((e) => e.exerciseKey).toList();
    final circuitExes = _sessionExercises
        .where((e) => e.circuitId == circuitId)
        .toList();
    _sessionExercises.removeWhere((e) => e.circuitId == circuitId);
    for (final key in newKeyOrder) {
      try {
        _sessionExercises
            .add(circuitExes.firstWhere((e) => e.exerciseKey == key));
      } catch (_) {}
    }
    final rounds = _circuitRoundSets[circuitId];
    if (rounds != null) {
      for (int r = 0; r < rounds.length; r++) {
        final oldRound = Map<dynamic, List<ActiveSet>>.from(rounds[r]);
        final newRound = <dynamic, List<ActiveSet>>{};
        for (final key in newKeyOrder) {
          newRound[key] = oldRound[key] ?? [];
        }
        rounds[r] = newRound;
      }
    }
    _savePausedState();
    notifyListeners();
  }

  void reorderSessionExercises(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _sessionExercises.removeAt(oldIndex);
    _sessionExercises.insert(newIndex, item);
    notifyListeners();
  }

  // ── PARTE 4: Aggiunta esercizio a circuito in sessione ────
  // NON modifica Hive — solo in-memory.

  void addExerciseToCircuitInSession({
    required String circuitId,
    required dynamic exerciseKey,
    required String exerciseName,
    required String muscleGroup,
  }) {
    if (!_circuitRoundSets.containsKey(circuitId)) return;

    // Evita duplicati nello stesso circuito
    if (_sessionExercises.any((e) =>
        e.circuitId == circuitId &&
        e.exerciseKey == exerciseKey)) {
      return;
    }

    final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
    final rounds = _circuitRoundSets[circuitId]!;

    _sessionExercises.add(SessionExercise(
      exerciseKey: exerciseKey,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      circuitId: circuitId,
    ));

    const defaultSets = 3;
    const defaultReps = 8;

    for (int r = 0; r < totalRounds; r++) {
      final lastSets =
          HiveDatabase.instance.getLastExerciseSets(exerciseKey);
      final Map<int, HiveSessionSet> lastBySetNumber = {
        for (final s in lastSets) s.setNumber: s
      };
      rounds[r][exerciseKey] = List.generate(defaultSets, (i) {
        final sn = i + 1;
        final last = lastBySetNumber[sn];
        return ActiveSet(
          setNumber: sn,
          weight: 0,
          reps: defaultReps,
          lastWeight: (last != null && last.completed && last.weight > 0)
              ? last.weight
              : null,
          lastReps:
              (last != null && last.completed) ? last.reps : null,
        );
      });
    }

    _savePausedState();
    notifyListeners();
  }

  // ── PARTE 4: Rimozione esercizio da circuito in sessione ──
  // NON modifica Hive.

  void removeExerciseFromCircuitInSession({
    required String circuitId,
    required dynamic exerciseKey,
  }) {
    _sessionExercises.removeWhere(
      (e) => e.circuitId == circuitId && e.exerciseKey == exerciseKey,
    );

    final rounds = _circuitRoundSets[circuitId];
    if (rounds != null) {
      for (final round in rounds) {
        round.remove(exerciseKey);
      }
    }

    if (_restingExerciseKey == exerciseKey) _stopRestTimer();

    _savePausedState();
    notifyListeners();
  }

  // ── PARTE 4: Modifica numero cicli circuito in sessione ───
  // NON modifica Hive.

  void setCircuitRoundsInSession(String circuitId, int newRounds) {
    if (newRounds < 1) return;
    final currentRounds = _circuitTotalRounds[circuitId] ?? 1;
    if (newRounds == currentRounds) return;

    final exercises = _sessionExercises
        .where((e) => e.circuitId == circuitId)
        .toList();

    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null) return;

    if (newRounds > currentRounds) {
      final template =
          rounds.isNotEmpty ? rounds[0] : <dynamic, List<ActiveSet>>{};
      for (int r = currentRounds; r < newRounds; r++) {
        final newRound = <dynamic, List<ActiveSet>>{};
        for (final ex in exercises) {
          final tmpl = template[ex.exerciseKey] ?? [];
          newRound[ex.exerciseKey] = tmpl
              .map((s) => ActiveSet(
                    setNumber: s.setNumber,
                    weight: 0,
                    reps: s.reps,
                    lastWeight: s.lastWeight,
                    lastReps: s.lastReps,
                  ))
              .toList();
        }
        rounds.add(newRound);
      }
    } else {
      rounds.removeRange(newRounds, currentRounds);
      final cur = _currentRound[circuitId] ?? 0;
      if (cur >= newRounds) {
        _currentRound[circuitId] = newRounds - 1;
      }
    }

    _circuitTotalRounds[circuitId] = newRounds;
    _savePausedState();
    notifyListeners();
  }

  // ── Hive init ─────────────────────────────────────────────

  Future<void> initPauseBox() async {
    if (_pauseBox == null || !_pauseBox!.isOpen) {
      _pauseBox = await Hive.openBox(_pauseBoxName);
    }
  }

  Map<String, dynamic> _buildStateMap({int? elapsedAtPause}) {
    final setsData = <String, dynamic>{};
    for (final entry in _exerciseSets.entries) {
      setsData[entry.key.toString()] =
          entry.value.map((s) => s.toJson()).toList();
    }
    final circuitData = <String, dynamic>{};
    for (final cEntry in _circuitRoundSets.entries) {
      circuitData[cEntry.key] = cEntry.value.map((round) {
        final roundData = <String, dynamic>{};
        for (final exEntry in round.entries) {
          roundData[exEntry.key.toString()] =
              exEntry.value.map((s) => s.toJson()).toList();
        }
        return roundData;
      }).toList();
    }
    final roundData = <String, dynamic>{};
    for (final e in _currentRound.entries) {
      roundData[e.key] = e.value;
    }
    return {
      'sessionKey': currentSessionKey,
      'workoutKey': _currentWorkout?.key,
      'workoutName': _currentWorkout?.name,
      'startTime': _sessionStartTime?.toIso8601String(),
      'elapsedAtPause': elapsedAtPause ??
          (_sessionStartTime != null
              ? DateTime.now().difference(_sessionStartTime!).inSeconds
              : 0),
      'exercises': _sessionExercises.map((e) => e.toJson()).toList(),
      'exerciseSets': setsData,
      'circuitRoundSets': circuitData,
      'currentRound': roundData,
    };
  }

  Future<void> _savePausedState() async {
    if (currentSessionKey == null) return;
    await initPauseBox();
    await _pauseBox?.put(_activeSaveKey, jsonEncode(_buildStateMap()));
  }

  Future<void> _clearActiveSave() async {
    await initPauseBox();
    await _pauseBox?.delete(_activeSaveKey);
    await _pauseBox?.delete(_legacyKey);
  }

  Future<void> _clearPausedState() async => _clearActiveSave();

  Future<void> _savePausedList() async {
    await initPauseBox();
    await _pauseBox?.put(_pausedListKey, jsonEncode(_pausedList));
  }

  Future<bool> tryRestoreSession() async {
    await initPauseBox();
    final rawList = _pauseBox?.get(_pausedListKey);
    if (rawList != null) {
      try {
        _pausedList = (jsonDecode(rawList as String) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        _pausedList = [];
      }
    }
    final raw = _pauseBox?.get(_activeSaveKey) ??
        _pauseBox?.get(_legacyKey);
    if (raw == null) {
      if (_pausedList.isNotEmpty) notifyListeners();
      return false;
    }
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final success = await _restoreFromData(data);
      if (success) {
        if (_pauseBox?.get(_activeSaveKey) == null) {
          await _pauseBox?.put(_activeSaveKey, raw);
          await _pauseBox?.delete(_legacyKey);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Errore ripristino sessione: $e');
      await _clearActiveSave();
      return false;
    }
  }

  Future<bool> _restoreFromData(Map<String, dynamic> data) async {
    try {
      currentSessionKey = data['sessionKey'];
      _sessionStartTime = data['startTime'] != null
          ? DateTime.parse(data['startTime'] as String)
          : null;
      _sessionExercises.clear();
      for (final e in (data['exercises'] as List)) {
        _sessionExercises.add(
            SessionExercise.fromJson(e as Map<String, dynamic>));
      }
      _exerciseSets.clear();
      final setsData = data['exerciseSets'] as Map<String, dynamic>;
      for (final entry in setsData.entries) {
        final key = int.tryParse(entry.key) ?? entry.key;
        final setsList = (entry.value as List)
            .map((s) => ActiveSet.fromJson(s as Map<String, dynamic>))
            .toList();
        _exerciseSets[key] = setsList;
      }
      _circuitRoundSets.clear();
      _currentRound.clear();
      _circuitTotalRounds.clear();
      final circuitData =
          data['circuitRoundSets'] as Map<String, dynamic>?;
      if (circuitData != null) {
        for (final cEntry in circuitData.entries) {
          final circuitId = cEntry.key;
          final roundsList = cEntry.value as List;
          final rounds = <Map<dynamic, List<ActiveSet>>>[];
          for (final roundData in roundsList) {
            final round = <dynamic, List<ActiveSet>>{};
            for (final exEntry
                in (roundData as Map<String, dynamic>).entries) {
              final exKey = int.tryParse(exEntry.key) ?? exEntry.key;
              final sets = (exEntry.value as List)
                  .map((s) =>
                      ActiveSet.fromJson(s as Map<String, dynamic>))
                  .toList();
              round[exKey] = sets;
            }
            rounds.add(round);
          }
          _circuitRoundSets[circuitId] = rounds;
          _circuitTotalRounds[circuitId] = rounds.length;
        }
      }
      final roundsData = data['currentRound'] as Map<String, dynamic>?;
      if (roundsData != null) {
        for (final e in roundsData.entries) {
          _currentRound[e.key] = e.value as int;
        }
      }
      final workoutKey = data['workoutKey'];
      if (workoutKey != null) {
        final workouts = HiveDatabase.instance.getWorkouts();
        try {
          _currentWorkout =
              workouts.firstWhere((w) => w.key == workoutKey);
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('Errore ripristino da dati: $e');
      return false;
    }
  }

  Future<void> pauseSession() async {
    _stopRestTimer();
    if (currentSessionKey == null) return;
    final elapsed = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;
    final state = _buildStateMap(elapsedAtPause: elapsed);
    final id =
        '${currentSessionKey}_${DateTime.now().millisecondsSinceEpoch}';
    state['id'] = id;
    _pausedList.add(state);
    await _savePausedList();
    await _clearActiveSave();
    _resetSession();
  }

  Future<bool> resumePausedSession(String id) async {
    final index = _pausedList.indexWhere((s) => s['id'] == id);
    if (index < 0) return false;
    if (currentSessionKey != null) await abandonSession();
    final data = _pausedList[index];
    final success = await _restoreFromData(data);
    if (success) {
      _pausedList.removeAt(index);
      await _savePausedList();
      await _savePausedState();
      notifyListeners();
    }
    return success;
  }

  Future<void> deletePausedSession(String id) async {
    final index = _pausedList.indexWhere((s) => s['id'] == id);
    if (index < 0) return;
    final data = _pausedList[index];
    final sessionKey = data['sessionKey'];
    if (sessionKey != null) {
      try {
        await HiveDatabase.instance.deleteSession(sessionKey);
      } catch (_) {}
    }
    _pausedList.removeAt(index);
    await _savePausedList();
    notifyListeners();
  }

  Future<void> startSession(
    List<HiveWorkoutExercise> exercises,
    dynamic workoutKey,
    String workoutName,
    HiveWorkout workout, {
    List<HiveCircuit> circuits = const [],
  }) async {
    if (currentSessionKey != null &&
        _currentWorkout?.key == workoutKey) {
      return;
    }
    currentSessionKey = await HiveDatabase.instance
        .createSession(workoutKey, workoutName);
    _sessionStartTime = DateTime.now();
    _currentWorkout = workout;
    _exerciseSets.clear();
    _sessionExercises.clear();
    _circuitRoundSets.clear();
    _currentRound.clear();
    _circuitTotalRounds.clear();
    _sessionCircuitNames.clear();
    _stopRestTimer();

    for (final circuit in circuits) {
      final cid = circuit.key.toString();
      _circuitTotalRounds[cid] = circuit.rounds;
      _currentRound[cid] = 0;
      _circuitRoundSets[cid] = List.generate(circuit.rounds, (_) => {});
      _sessionCircuitNames[cid] = circuit.name;
    }

    final exerciseKeys = exercises.map((e) => e.exerciseKey).toList();
    final savedNotes =
        HiveDatabase.instance.getExerciseNotes(exerciseKeys);
    final Map<dynamic, Map<int, HiveSessionSet>> allLastSets = {};
    for (final ex in exercises) {
      if (allLastSets.containsKey(ex.exerciseKey)) continue;
      final lastSets =
          HiveDatabase.instance.getLastExerciseSets(ex.exerciseKey);
      allLastSets[ex.exerciseKey] = {
        for (final s in lastSets) s.setNumber: s
      };
    }

    final freeExercises = exercises.where((e) => !e.isInCircuit).toList();
    final topItems = <({int order, bool isCircuit, dynamic data})>[
      ...freeExercises.map((e) =>
          (order: e.sortOrder, isCircuit: false, data: e as dynamic)),
      ...circuits.map((c) =>
          (order: c.sortOrder, isCircuit: true, data: c as dynamic)),
    ]..sort((a, b) => a.order.compareTo(b.order));

    for (final topItem in topItems) {
      if (!topItem.isCircuit) {
        final ex = topItem.data as HiveWorkoutExercise;
        final lastSets = allLastSets[ex.exerciseKey] ?? {};
        _sessionExercises.add(SessionExercise(
          exerciseKey: ex.exerciseKey,
          exerciseName: ex.exerciseName,
          muscleGroup: ex.muscleGroup,
          restSeconds: ex.restSeconds,
          notes: ex.notes,
          sessionNote: savedNotes[ex.exerciseKey],
          circuitId: null,
        ));
        _exerciseSets[ex.exerciseKey] = List.generate(ex.sets, (i) {
          final setNumber = i + 1;
          final last = lastSets[setNumber];
          return ActiveSet(
            setNumber: setNumber,
            weight: 0,
            reps: ex.targetReps,
            lastWeight: (last != null && last.completed && last.weight > 0)
                ? last.weight
                : null,
            lastReps:
                (last != null && last.completed) ? last.reps : null,
          );
        });
      } else {
        final c = topItem.data as HiveCircuit;
        final cid = c.key.toString();
        final rounds = _circuitRoundSets[cid]!;
        final circuitExercises = exercises
            .where((e) => e.isInCircuit && e.circuitId == cid)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final ex in circuitExercises) {
          final lastSets = allLastSets[ex.exerciseKey] ?? {};
          _sessionExercises.add(SessionExercise(
            exerciseKey: ex.exerciseKey,
            exerciseName: ex.exerciseName,
            muscleGroup: ex.muscleGroup,
            restSeconds: ex.restSeconds,
            notes: null,
            sessionNote: savedNotes[ex.exerciseKey],
            circuitId: cid,
          ));
          for (int r = 0; r < rounds.length; r++) {
            rounds[r][ex.exerciseKey] = List.generate(ex.sets, (i) {
              final setNumber = i + 1;
              final last = lastSets[setNumber];
              return ActiveSet(
                setNumber: setNumber,
                weight: 0,
                reps: ex.targetReps,
                lastWeight:
                    (last != null && last.completed && last.weight > 0)
                        ? last.weight
                        : null,
                lastReps:
                    (last != null && last.completed) ? last.reps : null,
              );
            });
          }
        }
      }
    }

    await _savePausedState();
    notifyListeners();
  }

  /// Aggiunge un circuito TEMPORANEO alla sessione.
  /// NON modifica Hive — esiste solo nello storico finale.
  Future<void> addCircuitToSession({
    required List<({
      dynamic exerciseKey,
      String exerciseName,
      String muscleGroup,
    })>
        exercises,
    required int rounds,
    String name = 'Circuito',
  }) async {
    if (exercises.isEmpty || currentSessionKey == null) return;
    final circuitId =
        'sess_circ_${DateTime.now().millisecondsSinceEpoch}';
    _circuitTotalRounds[circuitId] = rounds;
    _currentRound[circuitId] = 0;
    _circuitRoundSets[circuitId] =
        List.generate(rounds, (_) => <dynamic, List<ActiveSet>>{});
    _sessionCircuitNames[circuitId] = name;

    for (final ex in exercises) {
      final lastSets =
          HiveDatabase.instance.getLastExerciseSets(ex.exerciseKey);
      final Map<int, HiveSessionSet> lastBySetNumber = {
        for (final s in lastSets) s.setNumber: s
      };
      final savedNote =
          HiveDatabase.instance.getExerciseNote(ex.exerciseKey);
      _sessionExercises.add(SessionExercise(
        exerciseKey: ex.exerciseKey,
        exerciseName: ex.exerciseName,
        muscleGroup: ex.muscleGroup,
        circuitId: circuitId,
        sessionNote: savedNote,
      ));
      const defaultSets = 3;
      const defaultReps = 8;
      for (int r = 0; r < rounds; r++) {
        _circuitRoundSets[circuitId]![r][ex.exerciseKey] =
            List.generate(defaultSets, (i) {
          final sn = i + 1;
          final last = lastBySetNumber[sn];
          return ActiveSet(
            setNumber: sn,
            weight: 0,
            reps: defaultReps,
            lastWeight:
                (last != null && last.completed && last.weight > 0)
                    ? last.weight
                    : null,
            lastReps:
                (last != null && last.completed) ? last.reps : null,
          );
        });
      }
    }

    await _savePausedState();
    notifyListeners();
  }

  Future<void> abandonSession() async {
    if (currentSessionKey != null) {
      await HiveDatabase.instance.deleteSession(currentSessionKey);
    }
    await _clearPausedState();
    _resetSession();
  }

  void _resetSession() {
    _stopRestTimer();
    _exerciseSets.clear();
    _sessionExercises.clear();
    _circuitRoundSets.clear();
    _currentRound.clear();
    _circuitTotalRounds.clear();
    _sessionCircuitNames.clear();
    currentSessionKey = null;
    _sessionStartTime = null;
    _currentWorkout = null;
    notifyListeners();
  }

  void toggleSet(dynamic exerciseKey, int index, {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets =
          _circuitRoundSets[circuitId]?[round][exerciseKey];
      if (sets == null || index >= sets.length) return;
      final set = sets[index];
      if (!set.completed) {
        set.completed = true;
        _startRestTimer(exerciseKey, index, circuitId: circuitId);
      } else {
        set.completed = false;
        if (_restingExerciseKey == exerciseKey) _stopRestTimer();
      }
    } else {
      final set = _exerciseSets[exerciseKey]?[index];
      if (set == null) return;
      if (!set.completed) {
        set.completed = true;
        _startRestTimer(exerciseKey, index);
      } else {
        set.completed = false;
        if (_restingExerciseKey == exerciseKey &&
            _restingSetIndex == index) {
          _stopRestTimer();
        }
      }
    }
    _savePausedState();
    notifyListeners();
  }

  void updateSet(dynamic exerciseKey, int index, double weight, int reps,
      {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets =
          _circuitRoundSets[circuitId]?[round][exerciseKey];
      if (sets == null || index >= sets.length) return;
      sets[index].weight = weight;
      sets[index].reps = reps;
    } else {
      final set = _exerciseSets[exerciseKey]?[index];
      if (set == null) return;
      set.weight = weight;
      set.reps = reps;
    }
    _savePausedState();
    notifyListeners();
  }

  void addSetToExercise(dynamic exerciseKey, {String? circuitId}) {
    if (circuitId != null) {
      final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) return;
      for (int r = 0; r < totalRounds; r++) {
        final sets = rounds[r][exerciseKey] ?? [];
        final last = sets.isNotEmpty ? sets.last : null;
        sets.add(ActiveSet(
          setNumber: sets.length + 1,
          weight: 0,
          reps: last?.reps ?? 8,
          lastWeight: last?.lastWeight,
          lastReps: last?.lastReps,
        ));
        rounds[r][exerciseKey] = sets;
      }
    } else {
      final sets = _exerciseSets[exerciseKey];
      if (sets == null) return;
      final last = sets.isNotEmpty ? sets.last : null;
      sets.add(ActiveSet(
        setNumber: sets.length + 1,
        weight: 0,
        reps: last?.reps ?? 8,
        lastWeight: last?.lastWeight,
        lastReps: last?.lastReps,
      ));
    }
    _savePausedState();
    notifyListeners();
  }

  void removeSetFromExercise(dynamic exerciseKey, {String? circuitId}) {
    if (circuitId != null) {
      final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) return;
      for (int r = 0; r < totalRounds; r++) {
        final sets = rounds[r][exerciseKey] ?? [];
        if (sets.length > 1) {
          sets.removeLast();
          rounds[r][exerciseKey] = sets;
        }
      }
    } else {
      final sets = _exerciseSets[exerciseKey];
      if (sets == null || sets.length <= 1) return;
      sets.removeLast();
    }
    _savePausedState();
    notifyListeners();
  }

  Future<void> addExerciseToSession({
    required dynamic exerciseKey,
    required String exerciseName,
    required String muscleGroup,
    int defaultSets = 3,
    int defaultReps = 8,
    String? notes,
  }) async {
    if (_exerciseSets.containsKey(exerciseKey)) return;
    final lastSets =
        HiveDatabase.instance.getLastExerciseSets(exerciseKey);
    final Map<int, HiveSessionSet> lastBySetNumber = {};
    for (final s in lastSets) {
      lastBySetNumber[s.setNumber] = s;
    }
    final savedNote =
        HiveDatabase.instance.getExerciseNote(exerciseKey);
    _sessionExercises.add(SessionExercise(
      exerciseKey: exerciseKey,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      notes: notes,
      sessionNote: savedNote,
    ));
    _exerciseSets[exerciseKey] = List.generate(defaultSets, (i) {
      final setNumber = i + 1;
      final last = lastBySetNumber[setNumber];
      return ActiveSet(
        setNumber: setNumber,
        weight: 0,
        reps: defaultReps,
        lastWeight:
            (last != null && last.completed && last.weight > 0)
                ? last.weight
                : null,
        lastReps:
            (last != null && last.completed) ? last.reps : null,
      );
    });
    await _savePausedState();
    notifyListeners();
  }

  void removeExerciseFromSession(dynamic exerciseKey) {
    _exerciseSets.remove(exerciseKey);
    _sessionExercises
        .removeWhere((e) => e.exerciseKey == exerciseKey);
    if (_restingExerciseKey == exerciseKey) _stopRestTimer();
    _savePausedState();
    notifyListeners();
  }

  Future<void> updateExerciseNote(
      dynamic exerciseKey, String note) async {
    try {
      final ex = _sessionExercises
          .firstWhere((e) => e.exerciseKey == exerciseKey);
      ex.sessionNote = note.isEmpty ? null : note;
    } catch (_) {}
    if (note.isEmpty) {
      await HiveDatabase.instance.deleteExerciseNote(exerciseKey);
    } else {
      await HiveDatabase.instance.saveExerciseNote(exerciseKey, note);
    }
    await _savePausedState();
    notifyListeners();
  }

  void _startRestTimer(dynamic exerciseKey, int setIndex,
      {String? circuitId}) {
    _stopRestTimer();
    _restElapsed = 0;
    _restDoneNotified = false;
    _restingExerciseKey = exerciseKey;
    _restingSetIndex = setIndex;
    SessionExercise? ex;
    try {
      ex = _sessionExercises
          .firstWhere((e) => e.exerciseKey == exerciseKey);
    } catch (_) {}
    final targetRest = ex?.restSeconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _restElapsed++;
      if (targetRest != null &&
          _restElapsed >= targetRest &&
          !_restDoneNotified) {
        _restDoneNotified = true;
        NotificationService.instance.playRestDone();
        HapticFeedback.heavyImpact();
      }
      notifyListeners();
    });
  }

  void stopRestTimer() {
    if (_restingExerciseKey != null && _restingSetIndex != null) {
      final set =
          _exerciseSets[_restingExerciseKey]?[_restingSetIndex!];
      if (set != null) set.restSeconds = _restElapsed;
    }
    _stopRestTimer();
    notifyListeners();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _restElapsed = 0;
    _restDoneNotified = false;
    _restingExerciseKey = null;
    _restingSetIndex = null;
  }

  Future<void> finishSession() async {
    if (currentSessionKey == null) return;
    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : null;
    if (duration != null) {
      await HiveDatabase.instance
          .updateSessionDuration(currentSessionKey, duration);
    }
    for (final ex
        in _sessionExercises.where((e) => !e.isInCircuit)) {
      final sets = _exerciseSets[ex.exerciseKey] ?? [];
      for (final set in sets) {
        await HiveDatabase.instance.addSessionSet(HiveSessionSet(
          sessionKey: currentSessionKey,
          exerciseKey: ex.exerciseKey,
          exerciseName: ex.exerciseName,
          muscleGroup: ex.muscleGroup,
          setNumber: set.setNumber,
          weight: set.weight,
          reps: set.reps,
          completed: set.completed,
          restSeconds: set.restSeconds,
        ));
      }
    }
    for (final ex in _sessionExercises.where((e) => e.isInCircuit)) {
      final circuitId = ex.circuitId!;
      final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) continue;
      for (int r = 0; r < totalRounds; r++) {
        final sets = rounds[r][ex.exerciseKey] ?? [];
        for (final set in sets) {
          await HiveDatabase.instance.addSessionSet(HiveSessionSet(
            sessionKey: currentSessionKey,
            exerciseKey: ex.exerciseKey,
            exerciseName: '${ex.exerciseName} (Ciclo ${r + 1})',
            muscleGroup: ex.muscleGroup,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            completed: set.completed,
            restSeconds: set.restSeconds,
          ));
        }
      }
    }
    await _clearPausedState();
    _resetSession();
  }
}