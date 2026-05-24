import 'package:flutter/material.dart';
import '../models/hive_models.dart';
import '../db/hive_database.dart';

class ExerciseProvider extends ChangeNotifier {
  List<HiveExercise> _exercises = [];
  String _selectedMuscleGroup = 'Tutti';

  List<HiveExercise> get exercises => _exercises;
  String get selectedMuscleGroup => _selectedMuscleGroup;

  List<String> get muscleGroups {
    final groups =
        _exercises.map((e) => e.muscleGroup).toSet().toList();
    groups.sort();
    return ['Tutti', ...groups];
  }

  List<HiveExercise> get filtered {
    if (_selectedMuscleGroup == 'Tutti') return _exercises;
    return _exercises
        .where((e) => e.muscleGroup == _selectedMuscleGroup)
        .toList();
  }

  List<HiveExercise> get defaultExercises =>
      filtered.where((e) => !e.isCustom).toList();

  List<HiveExercise> get customExercises =>
      filtered.where((e) => e.isCustom).toList();

  bool exerciseNameExists(String name) {
    return HiveDatabase.instance.exerciseNameExists(name);
  }

  void loadExercises() {
    _exercises = HiveDatabase.instance.getExercises();
    notifyListeners();
  }

  void selectMuscleGroup(String group) {
    _selectedMuscleGroup = group;
    notifyListeners();
  }

  Future<void> addExercise(HiveExercise exercise) async {
    await HiveDatabase.instance.addExercise(exercise);
    loadExercises();
  }

  Future<void> deleteExercise(dynamic key) async {
    await HiveDatabase.instance.deleteExercise(key);
    loadExercises();
  }
}