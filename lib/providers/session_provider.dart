import 'dart:async';
import 'package:flutter/material.dart';
import '../db/hive_database.dart';
import '../models/hive_models.dart';
import 'package:hive/hive.dart';

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

  SessionExercise({
    required this.exerciseKey,
    required this.exerciseName,
    required this.muscleGroup,
    this.restSeconds,
    this.notes,
    this.sessionNote,
  });

  dynamic get exerciseId => exerciseKey;
}

class SessionProvider extends ChangeNotifier {
  dynamic currentSessionKey;
  DateTime? _sessionStartTime;

  final Map<dynamic, List<ActiveSet>> _exerciseSets = {};
  final List<SessionExercise> _sessionExercises = [];

  Map<dynamic, List<ActiveSet>> get exerciseSets => _exerciseSets;
  List<SessionExercise> get sessionExercises => _sessionExercises;

  Timer? _restTimer;
  int _restElapsed = 0;
  dynamic _restingExerciseKey;
  int? _restingSetIndex;

  int get restElapsed => _restElapsed;
  bool get isResting => _restTimer != null && _restTimer!.isActive;
  dynamic get restingExerciseId => _restingExerciseKey;
  int? get restingSetIndex => _restingSetIndex;

  Future<void> startSession(
      List<HiveWorkoutExercise> exercises,
      dynamic workoutKey,
      String workoutName) async {
    currentSessionKey = await HiveDatabase.instance
        .createSession(workoutKey, workoutName);
    _sessionStartTime = DateTime.now();
    _exerciseSets.clear();
    _sessionExercises.clear();
    _stopRestTimer();

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

      _sessionExercises.add(SessionExercise(
        exerciseKey: ex.exerciseKey,
        exerciseName: ex.exerciseName,
        muscleGroup: ex.muscleGroup,
        restSeconds: ex.restSeconds,
        notes: ex.notes,
        sessionNote: savedNotes[ex.exerciseKey],
      ));

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

    notifyListeners();
  }

  void toggleSet(dynamic exerciseKey, int index) {
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
    notifyListeners();
  }

  void updateSet(
      dynamic exerciseKey, int index, double weight, int reps) {
    final set = _exerciseSets[exerciseKey]![index];
    set.weight = weight;
    set.reps = reps;
    notifyListeners();
  }

  void addSetToExercise(dynamic exerciseKey) {
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
    notifyListeners();
  }

  void removeSetFromExercise(dynamic exerciseKey) {
    final sets = _exerciseSets[exerciseKey];
    if (sets == null || sets.length <= 1) return;
    sets.removeLast();
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
    if (_restingExerciseKey == exerciseKey) _stopRestTimer();
    notifyListeners();
  }

  void reorderSessionExercises(int oldIndex, int newIndex) {
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
      ex.sessionNote = null;
      await HiveDatabase.instance.deleteExerciseNote(exerciseKey);
    } else {
      ex.sessionNote = note;
      await HiveDatabase.instance
          .saveExerciseNote(exerciseKey, note);
    }
    notifyListeners();
  }

  void _startRestTimer(dynamic exerciseKey, int setIndex) {
    _stopRestTimer();
    _restElapsed = 0;
    _restingExerciseKey = exerciseKey;
    _restingSetIndex = setIndex;

    final ex = _sessionExercises.firstWhere(
        (e) => e.exerciseKey == exerciseKey,
        orElse: () => _sessionExercises.first);
    final targetRest = ex.restSeconds;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _restElapsed++;
      if (targetRest != null && _restElapsed == targetRest) {
        // TODO: NotificationService.instance.playRestDone();
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

    for (final ex in _sessionExercises) {
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

    _stopRestTimer();
    _exerciseSets.clear();
    _sessionExercises.clear();
    currentSessionKey = null;
    _sessionStartTime = null;
    notifyListeners();
  }
}