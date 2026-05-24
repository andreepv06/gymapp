import 'package:flutter/material.dart';
import '../models/hive_models.dart';
import '../db/hive_database.dart';

class WorkoutProvider extends ChangeNotifier {
  List<HiveWorkout> _workouts = [];
  List<HiveWorkoutExercise> _currentExercises = [];

  List<HiveWorkout> get workouts => _workouts;
  List<HiveWorkoutExercise> get currentExercises => _currentExercises;

  void loadWorkouts() {
    _workouts = HiveDatabase.instance.getWorkouts();
    notifyListeners();
  }

  void loadWorkoutExercises(dynamic workoutKey) {
    _currentExercises =
        HiveDatabase.instance.getWorkoutExercises(workoutKey);
    notifyListeners();
  }

  Future<dynamic> addWorkout(String name) async {
    final workout = HiveWorkout(
      name: name,
      createdAt: DateTime.now().toIso8601String(),
    );
    final key = await HiveDatabase.instance.addWorkout(workout);
    loadWorkouts();
    return key;
  }

  Future<void> renameWorkout(dynamic key, String newName) async {
    await HiveDatabase.instance.updateWorkout(key, newName);
    loadWorkouts();
  }

  Future<void> deleteWorkout(dynamic key) async {
    await HiveDatabase.instance.deleteWorkout(key);
    loadWorkouts();
  }

  Future<void> addExercisesToWorkout(
      List<HiveWorkoutExercise> list) async {
    for (final we in list) {
      await HiveDatabase.instance.addWorkoutExercise(we);
    }
    if (list.isNotEmpty) {
      loadWorkoutExercises(list.first.workoutKey);
    }
  }

  Future<void> updateExerciseInWorkout(
      dynamic key, HiveWorkoutExercise updated) async {
    await HiveDatabase.instance.updateWorkoutExercise(key, updated);
    loadWorkoutExercises(updated.workoutKey);
  }

  Future<void> removeExerciseFromWorkout(
      dynamic key, dynamic workoutKey) async {
    await HiveDatabase.instance.deleteWorkoutExercise(key);
    loadWorkoutExercises(workoutKey);
  }

  Future<void> reorderExercises(
      dynamic workoutKey, List<HiveWorkoutExercise> reordered) async {
    _currentExercises = reordered;
    notifyListeners();
    await HiveDatabase.instance.reorderWorkoutExercises(reordered);
  }
}