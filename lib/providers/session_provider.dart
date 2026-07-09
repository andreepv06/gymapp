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

  // circuitId → round → exerciseKey → sets
  final Map<String, List<Map<dynamic, List<ActiveSet>>>> _circuitRoundSets = {};
  final Map<String, int> _currentRound = {};
  final Map<String, int> _circuitTotalRounds = {};

  Box? _pauseBox;
  static const _pauseBoxName = 'paused_session';
  static const _pauseKey = 'current';

  Map<dynamic, List<ActiveSet>> get exerciseSets => _exerciseSets;
  List<SessionExercise> get sessionExercises => _sessionExercises;

  // ── Rest countdown timer (rimpiazza elapsed timer) ────────────
  int _restTotal = 0;
  int _restRemaining = 0;
  bool _restPaused = false;
  Timer? _restCountdownTimer;
  dynamic _restingExerciseKey;
  int? _restingSetIndex;

  int get restTotal => _restTotal;
  int get restRemaining => _restRemaining;
  bool get restPaused => _restPaused;
  bool get isResting => _restRemaining > 0;

  // Compatibilità con codice esistente
  int get restElapsed => _restTotal - _restRemaining;
  dynamic get restingExerciseId => _restingExerciseKey;
  int? get restingSetIndex => _restingSetIndex;

  // ── Nuovi getter ──────────────────────────────────────────────

  DateTime? get sessionStartTime => _sessionStartTime;

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

  bool get hasActiveSession =>
      currentSessionKey != null && _sessionExercises.isNotEmpty;

  bool get hasAnyData {
    final hasCompleted =
        _exerciseSets.values.expand((s) => s).any((s) => s.completed);
    final hasCircuitData = _circuitRoundSets.values.any((rounds) =>
        rounds.any(
            (round) => round.values.expand((s) => s).any((s) => s.completed)));
    return hasCompleted || hasCircuitData;
  }

  // ── Getter circuiti ───────────────────────────────────────────

  int getCurrentRound(String circuitId) => _currentRound[circuitId] ?? 0;
  int getTotalRounds(String circuitId) => _circuitTotalRounds[circuitId] ?? 1;

  List<ActiveSet> getCircuitSets(String circuitId, dynamic exerciseKey) {
    final round = _currentRound[circuitId] ?? 0;
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) return [];
    return rounds[round][exerciseKey] ?? [];
  }

  List<ActiveSet> getCircuitSetsForRound(
      String circuitId, int round, dynamic exerciseKey) {
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) return [];
    return rounds[round][exerciseKey] ?? [];
  }

  // ── Rest countdown ────────────────────────────────────────────

  void _startRestCountdown(int seconds) {
    _restCountdownTimer?.cancel();
    _restTotal = seconds;
    _restRemaining = seconds;
    _restPaused = false;
    _scheduleCountdownTick();
    notifyListeners();
  }

  void _scheduleCountdownTick() {
    if (_restRemaining <= 0 || _restPaused) return;
    _restCountdownTimer =
        Timer(const Duration(seconds: 1), () {
      if (_restPaused) return;
      if (_restRemaining <= 1) {
        _restRemaining = 0;
        NotificationService.instance.playRestDone();
        HapticFeedback.heavyImpact();
        notifyListeners();
        return;
      }
      _restRemaining--;
      notifyListeners();
      _scheduleCountdownTick();
    });
  }

  void toggleRestPause() {
    _restPaused = !_restPaused;
    if (!_restPaused && _restRemaining > 0) {
      _scheduleCountdownTick();
    }
    notifyListeners();
  }

  void skipRest() {
    _restCountdownTimer?.cancel();
    _restTotal = 0;
    _restRemaining = 0;
    _restPaused = false;
    _restingExerciseKey = null;
    _restingSetIndex = null;
    notifyListeners();
  }

  void addRestTime(int seconds) {
    _restRemaining = (_restRemaining + seconds).clamp(0, 600);
    if (_restRemaining > 0) {
      if (!_restPaused) {
        _restCountdownTimer?.cancel();
        _scheduleCountdownTick();
      }
    } else {
      skipRest();
      return;
    }
    notifyListeners();
  }

  // Compat: mantenuto per codice esistente
  void stopRestTimer() {
    skipRest();
  }

  void _stopRestTimer() {
    _restCountdownTimer?.cancel();
    _restCountdownTimer = null;
    _restTotal = 0;
    _restRemaining = 0;
    _restPaused = false;
    _restingExerciseKey = null;
    _restingSetIndex = null;
  }

  void _startRestTimer(dynamic exerciseKey, int setIndex,
      {String? circuitId}) {
    _stopRestTimer();
    _restingExerciseKey = exerciseKey;
    _restingSetIndex = setIndex;

    SessionExercise? ex;
    try {
      ex =
          _sessionExercises.firstWhere((e) => e.exerciseKey == exerciseKey);
    } catch (_) {}

    final targetRest = ex?.restSeconds;
    if (targetRest != null && targetRest > 0) {
      _startRestCountdown(targetRest);
    }
  }

  // ── Navigazione round ─────────────────────────────────────────

  void setRound(String circuitId, int round) {
    final total = _circuitTotalRounds[circuitId] ?? 1;
    if (round >= 0 && round < total) {
      _currentRound[circuitId] = round;
      _savePausedState();
      notifyListeners();
    }
  }

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

  // ── Reorder ───────────────────────────────────────────────────

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
        final ex = circuitExes.firstWhere((e) => e.exerciseKey == key);
        _sessionExercises.add(ex);
      } catch (_) {}
    }

    // Propaga ordine a TUTTI i round
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

  // ── Hive pause box ────────────────────────────────────────────

  Future<void> initPauseBox() async {
    if (_pauseBox == null || !_pauseBox!.isOpen) {
      _pauseBox = await Hive.openBox(_pauseBoxName);
    }
  }

  Future<bool> tryRestoreSession() async {
    await initPauseBox();
    final raw = _pauseBox?.get(_pauseKey);
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
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

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Errore ripristino sessione: $e');
      await _pauseBox?.delete(_pauseKey);
      return false;
    }
  }

  Future<void> _savePausedState() async {
    if (currentSessionKey == null) return;
    await initPauseBox();

    final setsData = <String, dynamic>{};
    for (final entry in _exerciseSets.entries) {
      setsData[entry.key.toString()] =
          entry.value.map((s) => s.toJson()).toList();
    }

    final circuitData = <String, dynamic>{};
    for (final cEntry in _circuitRoundSets.entries) {
      final rounds = cEntry.value.map((round) {
        final roundData = <String, dynamic>{};
        for (final exEntry in round.entries) {
          roundData[exEntry.key.toString()] =
              exEntry.value.map((s) => s.toJson()).toList();
        }
        return roundData;
      }).toList();
      circuitData[cEntry.key] = rounds;
    }

    final roundData = <String, dynamic>{};
    for (final e in _currentRound.entries) {
      roundData[e.key] = e.value;
    }

    final data = {
      'sessionKey': currentSessionKey,
      'workoutKey': _currentWorkout?.key,
      'startTime': _sessionStartTime?.toIso8601String(),
      'exercises': _sessionExercises.map((e) => e.toJson()).toList(),
      'exerciseSets': setsData,
      'circuitRoundSets': circuitData,
      'currentRound': roundData,
    };

    await _pauseBox?.put(_pauseKey, jsonEncode(data));
  }

  Future<void> _clearPausedState() async {
    await initPauseBox();
    await _pauseBox?.delete(_pauseKey);
  }

  // ── startSession ──────────────────────────────────────────────

  Future<void> startSession(
    List<HiveWorkoutExercise> exercises,
    dynamic workoutKey,
    String workoutName,
    HiveWorkout workout, {
    List<HiveCircuit> circuits = const [],
  }) async {
    if (currentSessionKey != null &&
        _currentWorkout?.key == workoutKey) {
      return; // Sessione già attiva per questa scheda
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
    _stopRestTimer();

    for (final circuit in circuits) {
      final cid = circuit.key.toString();
      _circuitTotalRounds[cid] = circuit.rounds;
      _currentRound[cid] = 0;
      _circuitRoundSets[cid] =
          List.generate(circuit.rounds, (_) => {});
    }

    final exerciseKeys = exercises.map((e) => e.exerciseKey).toList();
    final savedNotes =
        HiveDatabase.instance.getExerciseNotes(exerciseKeys);

    for (final ex in exercises) {
      final lastSets =
          HiveDatabase.instance.getLastExerciseSets(ex.exerciseKey);
      final Map<int, HiveSessionSet> lastBySetNumber = {};
      for (final s in lastSets) {
        lastBySetNumber[s.setNumber] = s;
      }

      final circuitId = ex.isInCircuit ? ex.circuitId : null;

      _sessionExercises.add(SessionExercise(
        exerciseKey: ex.exerciseKey,
        exerciseName: ex.exerciseName,
        muscleGroup: ex.muscleGroup,
        restSeconds: ex.restSeconds,
        notes: ex.isInCircuit ? null : ex.notes,
        sessionNote: savedNotes[ex.exerciseKey],
        circuitId: circuitId,
      ));

      if (circuitId != null) {
        final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
        final rounds = _circuitRoundSets[circuitId] ??
            List.generate(totalRounds, (_) => {});
        _circuitRoundSets[circuitId] = rounds;

        for (int r = 0; r < totalRounds; r++) {
          rounds[r][ex.exerciseKey] =
              List.generate(ex.sets, (i) {
            final setNumber = i + 1;
            final last = lastBySetNumber[setNumber];
            return ActiveSet(
              setNumber: setNumber,
              weight: 0, // Sempre vuoto: lastWeight è il placeholder
              reps: ex.targetReps,
              lastWeight: (last != null && last.completed && last.weight > 0)
                  ? last.weight
                  : null,
              lastReps:
                  (last != null && last.completed) ? last.reps : null,
            );
          });
        }
      } else {
        _exerciseSets[ex.exerciseKey] =
            List.generate(ex.sets, (i) {
          final setNumber = i + 1;
          final last = lastBySetNumber[setNumber];
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
      }
    }

    await _savePausedState();
    notifyListeners();
  }

  // ── pauseSession ──────────────────────────────────────────────

  void pauseSession() {
    _stopRestTimer();
    _savePausedState();
    notifyListeners();
  }

  // ── abandonSession ────────────────────────────────────────────

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
    currentSessionKey = null;
    _sessionStartTime = null;
    _currentWorkout = null;
    notifyListeners();
  }

  // ── toggleSet ─────────────────────────────────────────────────

  void toggleSet(dynamic exerciseKey, int index, {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets = _circuitRoundSets[circuitId]?[round][exerciseKey];
      if (sets == null || index >= sets.length) return;
      final set = sets[index];
      if (!set.completed) {
        set.completed = true;
        _startRestTimer(exerciseKey, index, circuitId: circuitId);
      } else {
        set.completed = false;
        if (_restingExerciseKey == exerciseKey) skipRest();
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
          skipRest();
        }
      }
    }
    _savePausedState();
    notifyListeners();
  }

  // ── updateSet ─────────────────────────────────────────────────

  void updateSet(dynamic exerciseKey, int index, double weight, int reps,
      {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets = _circuitRoundSets[circuitId]?[round][exerciseKey];
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

  // Aggiorna solo round specifico (per circuiti con PageView)
  void updateCircuitSetForRound(
      String circuitId, int round, dynamic exerciseKey, int index,
      double weight, int reps) {
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) return;
    final sets = rounds[round][exerciseKey];
    if (sets == null || index >= sets.length) return;
    sets[index].weight = weight;
    sets[index].reps = reps;
    _savePausedState();
    notifyListeners();
  }

  void toggleCircuitSetForRound(
      String circuitId, int round, dynamic exerciseKey, int index) {
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) return;
    final sets = rounds[round][exerciseKey];
    if (sets == null || index >= sets.length) return;
    final set = sets[index];
    if (!set.completed) {
      set.completed = true;
      _startRestTimer(exerciseKey, index, circuitId: circuitId);
    } else {
      set.completed = false;
      if (_restingExerciseKey == exerciseKey) skipRest();
    }
    _savePausedState();
    notifyListeners();
  }

  // ── addSet / removeSet ────────────────────────────────────────

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

  // ── addExerciseToSession ──────────────────────────────────────

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
    _exerciseSets[exerciseKey] =
        List.generate(defaultSets, (i) {
      final setNumber = i + 1;
      final last = lastBySetNumber[setNumber];
      return ActiveSet(
        setNumber: setNumber,
        weight: 0,
        reps: defaultReps,
        lastWeight: (last != null && last.completed && last.weight > 0)
            ? last.weight
            : null,
        lastReps: (last != null && last.completed) ? last.reps : null,
      );
    });
    await _savePausedState();
    notifyListeners();
  }

  void removeExerciseFromSession(dynamic exerciseKey) {
    _exerciseSets.remove(exerciseKey);
    _sessionExercises
        .removeWhere((e) => e.exerciseKey == exerciseKey);
    if (_restingExerciseKey == exerciseKey) skipRest();
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
      await HiveDatabase.instance
          .saveExerciseNote(exerciseKey, note);
    }
    await _savePausedState();
    notifyListeners();
  }

  // ── finishSession ─────────────────────────────────────────────

  Future<void> finishSession() async {
    if (currentSessionKey == null) return;

    final duration = _sessionStartTime != null
        ? DateTime.now()
            .difference(_sessionStartTime!)
            .inSeconds
        : null;

    if (duration != null) {
      await HiveDatabase.instance
          .updateSessionDuration(currentSessionKey, duration);
    }

    // Esercizi liberi
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

    // Circuiti — salva tutti i round
    for (final ex
        in _sessionExercises.where((e) => e.isInCircuit)) {
      final circuitId = ex.circuitId!;
      final totalRounds = _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) continue;
      for (int r = 0; r < totalRounds; r++) {
        final sets = rounds[r][ex.exerciseKey] ?? [];
        for (final set in sets) {
          await HiveDatabase.instance
              .addSessionSet(HiveSessionSet(
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