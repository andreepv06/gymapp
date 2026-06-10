import 'dart:async';
import 'package:flutter/material.dart';
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
}

/// Dati di un singolo ciclo per un esercizio di circuito
class CircuitRoundData {
  final Map<String, List<ActiveSet>> setsByExercise;
  CircuitRoundData()
      : setsByExercise = {};
}

class SessionProvider extends ChangeNotifier {
  dynamic currentSessionKey;
  DateTime? _sessionStartTime;
  HiveWorkout? _currentWorkout;

  HiveWorkout? get currentWorkout => _currentWorkout;

  final Map<dynamic, List<ActiveSet>> _exerciseSets = {};
  final List<SessionExercise> _sessionExercises = [];

  // Dati cicli: circuitId -> round (0-based) -> exerciseKey -> sets
  final Map<String, List<Map<dynamic, List<ActiveSet>>>>
      _circuitRoundSets = {};
  // Round corrente per ogni circuito
  final Map<String, int> _currentRound = {};
  // Info circuiti: circuitId -> numero rounds totali
  final Map<String, int> _circuitTotalRounds = {};

  Map<dynamic, List<ActiveSet>> get exerciseSets =>
      _exerciseSets;
  List<SessionExercise> get sessionExercises =>
      _sessionExercises;

  Timer? _restTimer;
  int _restElapsed = 0;
  dynamic _restingExerciseKey;
  int? _restingSetIndex;
  bool _restDoneNotified = false;

  int get restElapsed => _restElapsed;
  bool get isResting =>
      _restTimer != null && _restTimer!.isActive;
  dynamic get restingExerciseId => _restingExerciseKey;
  int? get restingSetIndex => _restingSetIndex;

  bool get hasActiveSession =>
      currentSessionKey != null &&
      _sessionExercises.isNotEmpty;

  bool get hasAnyData {
    final hasCompleted = _exerciseSets.values
        .expand((s) => s)
        .any((s) => s.completed);
    final hasCircuitData = _circuitRoundSets.values.any(
        (rounds) => rounds.any((round) => round.values
            .expand((s) => s)
            .any((s) => s.completed)));
    return hasCompleted || hasCircuitData;
  }

  // Restituisce il round corrente per un circuito
  int getCurrentRound(String circuitId) =>
      _currentRound[circuitId] ?? 0;

  // Restituisce il totale rounds per un circuito
  int getTotalRounds(String circuitId) =>
      _circuitTotalRounds[circuitId] ?? 1;

  // Restituisce i set del round corrente per un esercizio di circuito
  List<ActiveSet> getCircuitSets(
      String circuitId, dynamic exerciseKey) {
    final round = _currentRound[circuitId] ?? 0;
    final rounds = _circuitRoundSets[circuitId];
    if (rounds == null || round >= rounds.length) {
      return [];
    }
    return rounds[round][exerciseKey] ?? [];
  }

  void nextRound(String circuitId) {
    final total = _circuitTotalRounds[circuitId] ?? 1;
    final current = _currentRound[circuitId] ?? 0;
    if (current < total - 1) {
      _currentRound[circuitId] = current + 1;
      notifyListeners();
    }
  }

  void prevRound(String circuitId) {
    final current = _currentRound[circuitId] ?? 0;
    if (current > 0) {
      _currentRound[circuitId] = current - 1;
      notifyListeners();
    }
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
    _stopRestTimer();

    // Inizializza info circuiti
    for (final circuit in circuits) {
      final cid = circuit.key.toString();
      _circuitTotalRounds[cid] = circuit.rounds;
      _currentRound[cid] = 0;
      // Inizializza rounds vuoti
      _circuitRoundSets[cid] = List.generate(
          circuit.rounds, (_) => {});
    }

    final exerciseKeys =
        exercises.map((e) => e.exerciseKey).toList();
    final savedNotes =
        HiveDatabase.instance.getExerciseNotes(exerciseKeys);

    for (final ex in exercises) {
      final lastSets = HiveDatabase.instance
          .getLastExerciseSets(ex.exerciseKey);
      final Map<int, HiveSessionSet> lastBySetNumber = {};
      for (final s in lastSets) {
        lastBySetNumber[s.setNumber] = s;
      }

      final circuitId =
          ex.isInCircuit ? ex.circuitId : null;

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
        // Inizializza i set per ogni round del circuito
        final totalRounds =
            _circuitTotalRounds[circuitId] ?? 1;
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
              weight: ex.targetWeight ?? 0,
              reps: ex.targetReps,
              lastWeight: last?.weight,
              lastReps: last?.reps,
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
            weight: ex.targetWeight ?? 0,
            reps: ex.targetReps,
            lastWeight: last?.weight,
            lastReps: last?.reps,
          );
        });
      }
    }

    notifyListeners();
  }

  void pauseSession() {
    _stopRestTimer();
    notifyListeners();
  }

  Future<void> abandonSession() async {
    if (currentSessionKey != null) {
      await HiveDatabase.instance
          .deleteSession(currentSessionKey);
    }
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

  void toggleSet(dynamic exerciseKey, int index,
      {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets = _circuitRoundSets[circuitId]
          ?[round][exerciseKey];
      if (sets == null || index >= sets.length) return;
      final set = sets[index];
      if (!set.completed) {
        set.completed = true;
        _startRestTimer(exerciseKey, index,
            circuitId: circuitId);
      } else {
        set.completed = false;
        if (_restingExerciseKey == exerciseKey) {
          _stopRestTimer();
        }
      }
    } else {
      final set = _exerciseSets[exerciseKey]![index];
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
    notifyListeners();
  }

  void updateSet(dynamic exerciseKey, int index,
      double weight, int reps,
      {String? circuitId}) {
    if (circuitId != null) {
      final round = _currentRound[circuitId] ?? 0;
      final sets = _circuitRoundSets[circuitId]
          ?[round][exerciseKey];
      if (sets == null || index >= sets.length) return;
      sets[index].weight = weight;
      sets[index].reps = reps;
    } else {
      final set = _exerciseSets[exerciseKey]![index];
      set.weight = weight;
      set.reps = reps;
    }
    notifyListeners();
  }

  void addSetToExercise(dynamic exerciseKey,
      {String? circuitId}) {
    if (circuitId != null) {
      final totalRounds =
          _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) return;
      for (int r = 0; r < totalRounds; r++) {
        final sets = rounds[r][exerciseKey] ?? [];
        final last =
            sets.isNotEmpty ? sets.last : null;
        sets.add(ActiveSet(
          setNumber: sets.length + 1,
          weight: last?.weight ?? 0,
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
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 8,
        lastWeight: last?.lastWeight,
        lastReps: last?.lastReps,
      ));
    }
    notifyListeners();
  }

  void removeSetFromExercise(dynamic exerciseKey,
      {String? circuitId}) {
    if (circuitId != null) {
      final totalRounds =
          _circuitTotalRounds[circuitId] ?? 1;
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

    final lastSets = HiveDatabase.instance
        .getLastExerciseSets(exerciseKey);
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
        lastWeight: last?.weight,
        lastReps: last?.reps,
      );
    });

    notifyListeners();
  }

  void removeExerciseFromSession(dynamic exerciseKey) {
    _exerciseSets.remove(exerciseKey);
    _sessionExercises
        .removeWhere((e) => e.exerciseKey == exerciseKey);
    if (_restingExerciseKey == exerciseKey)
      _stopRestTimer();
    notifyListeners();
  }

  void reorderSessionExercises(
      int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _sessionExercises.removeAt(oldIndex);
    _sessionExercises.insert(newIndex, item);
    notifyListeners();
  }

  Future<void> updateExerciseNote(
      dynamic exerciseKey, String note) async {
    final ex = _sessionExercises
        .firstWhere((e) => e.exerciseKey == exerciseKey);
    if (note.isEmpty) {
      await HiveDatabase.instance
          .deleteExerciseNote(exerciseKey);
    } else {
      await HiveDatabase.instance
          .saveExerciseNote(exerciseKey, note);
    }
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
      ex = _sessionExercises.firstWhere(
          (e) => e.exerciseKey == exerciseKey);
    } catch (_) {}
    final targetRest = ex?.restSeconds;

    _restTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      _restElapsed++;
      if (targetRest != null &&
          _restElapsed >= targetRest &&
          !_restDoneNotified) {
        _restDoneNotified = true;
        NotificationService.instance.playRestDone();
      }
      notifyListeners();
    });
  }

  void stopRestTimer() {
    if (_restingExerciseKey != null &&
        _restingSetIndex != null) {
      final set =
          _exerciseSets[_restingExerciseKey]
              ?[_restingSetIndex!];
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
        ? DateTime.now()
            .difference(_sessionStartTime!)
            .inSeconds
        : null;

    if (duration != null) {
      await HiveDatabase.instance
          .updateSessionDuration(
              currentSessionKey, duration);
    }

    // Salva esercizi liberi
    for (final ex in _sessionExercises
        .where((e) => !e.isInCircuit)) {
      final sets = _exerciseSets[ex.exerciseKey] ?? [];
      for (final set in sets) {
        await HiveDatabase.instance
            .addSessionSet(HiveSessionSet(
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

    // Salva esercizi dei circuiti (tutti i round)
    for (final ex in _sessionExercises
        .where((e) => e.isInCircuit)) {
      final circuitId = ex.circuitId!;
      final totalRounds =
          _circuitTotalRounds[circuitId] ?? 1;
      final rounds = _circuitRoundSets[circuitId];
      if (rounds == null) continue;

      for (int r = 0; r < totalRounds; r++) {
        final sets =
            rounds[r][ex.exerciseKey] ?? [];
        for (final set in sets) {
          await HiveDatabase.instance
              .addSessionSet(HiveSessionSet(
            sessionKey: currentSessionKey,
            exerciseKey: ex.exerciseKey,
            exerciseName:
                '${ex.exerciseName} (Ciclo ${r + 1})',
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

    _resetSession();
  }
}