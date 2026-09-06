import 'package:flutter/material.dart';
import '../models/hive_models.dart';
import '../db/hive_database.dart';
import '../services/sync/sync_trigger.dart';
import '../services/sync/delete_propagator.dart';

void _unawaited(Future<void> future) {}

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
    SyncTrigger.instance.requestSync();
  }

  // MODIFICATO — propaga la cancellazione al backend tramite
  // DeletePropagator. Nota: il backend usa onDelete: Restrict per
  // Exercise, quindi se l'esercizio è ancora referenziato da dati
  // remoti la propagazione fallirà silenziosamente (best-effort) —
  // il delete locale resta comunque sempre valido.
  Future<void> deleteExercise(dynamic key) async {
    final intKey = key is int ? key : null;
    await HiveDatabase.instance.deleteExercise(key);
    loadExercises();
    if (intKey != null) {
      _unawaited(DeletePropagator.propagateExerciseDelete(intKey));
    }
  }
}