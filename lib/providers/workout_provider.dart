import 'package:flutter/material.dart';
import '../models/hive_models.dart';
import '../db/hive_database.dart';
import '../services/sync/sync_trigger.dart';
import '../services/sync/delete_propagator.dart';

void _unawaited(Future<void> future) {}

class WorkoutProvider extends ChangeNotifier {
  List<HiveWorkout> _workouts = [];
  List<HiveWorkoutExercise> _currentExercises = [];

  List<HiveWorkout> get workouts => _workouts;
  List<HiveWorkoutExercise> get currentExercises =>
      _currentExercises;

  void loadWorkouts() {
    _workouts = HiveDatabase.instance.getWorkouts();
    notifyListeners();
  }

  void loadWorkoutExercises(dynamic workoutKey) {
    _currentExercises = HiveDatabase.instance
        .getWorkoutExercises(workoutKey);
    notifyListeners();
  }

  Future<dynamic> addWorkout(String name) async {
    final workout = HiveWorkout(
      name: name,
      createdAt: DateTime.now().toIso8601String(),
    );
    final key =
        await HiveDatabase.instance.addWorkout(workout);
    loadWorkouts();
    SyncTrigger.instance.requestSync();
    return key;
  }

  Future<void> renameWorkout(
      dynamic key, String newName) async {
    await HiveDatabase.instance
        .updateWorkout(key, newName);
    loadWorkouts();
    SyncTrigger.instance.requestSync();
  }

  // MODIFICATO — propaga la cancellazione al backend tramite
  // DeletePropagator (già esistente nel progetto, best-effort e
  // silenzioso: il delete locale avviene comunque sempre per primo).
  Future<void> deleteWorkout(dynamic key) async {
    final intKey = key is int ? key : null;
    await HiveDatabase.instance.deleteWorkout(key);
    loadWorkouts();
    if (intKey != null) {
      _unawaited(DeletePropagator.propagateWorkoutDelete(intKey));
    }
  }

  Future<void> addExercisesToWorkout(
      List<HiveWorkoutExercise> list) async {
    for (final we in list) {
      await HiveDatabase.instance
          .addWorkoutExercise(we);
    }
    if (list.isNotEmpty) {
      loadWorkoutExercises(list.first.workoutKey);
      SyncTrigger.instance.requestSync();
    }
  }

  Future<void> updateExerciseInWorkout(
      dynamic key, HiveWorkoutExercise updated) async {
    await HiveDatabase.instance
        .updateWorkoutExercise(key, updated);
    loadWorkoutExercises(updated.workoutKey);
    SyncTrigger.instance.requestSync();
  }

  Future<void> removeExerciseFromWorkout(
      dynamic key, dynamic workoutKey) async {
    await HiveDatabase.instance
        .deleteWorkoutExercise(key);
    loadWorkoutExercises(workoutKey);
    SyncTrigger.instance.requestSync();
  }

  Future<void> reorderExercises(dynamic workoutKey,
      List<HiveWorkoutExercise> reordered) async {
    _currentExercises = reordered;
    notifyListeners();
    await HiveDatabase.instance
        .reorderWorkoutExercises(reordered);
  }

  Future<void> updateExerciseSortOrder(
      dynamic key, int sortOrder) async {
    final we = HiveDatabase.instance
        .getWorkoutExerciseByKey(key);
    if (we != null) {
      we.sortOrder = sortOrder;
      await HiveDatabase.instance
          .updateWorkoutExercise(key, we);
    }
    notifyListeners();
  }

  Future<void> reorderWorkoutExercises(
      dynamic workoutId,
      List<HiveWorkoutExercise> exercises) async {
    for (int i = 0; i < exercises.length; i++) {
      final updated = HiveWorkoutExercise(
        workoutKey: exercises[i].workoutKey,
        exerciseKey: exercises[i].exerciseKey,
        exerciseName: exercises[i].exerciseName,
        muscleGroup: exercises[i].muscleGroup,
        sets: exercises[i].sets,
        targetReps: exercises[i].targetReps,
        targetWeight: exercises[i].targetWeight,
        restSeconds: exercises[i].restSeconds,
        notes: exercises[i].notes,
        sortOrder: i,
      );
      await HiveDatabase.instance
          .updateWorkoutExercise(
              exercises[i].key, updated);
    }
    // FIX: loadWorkoutExercises è void, non Future
    loadWorkoutExercises(workoutId);
  }
}