import 'package:flutter/material.dart';
import '../db/training_mode_database.dart';
import '../models/training_mode.dart';
import '../services/sync/sync_trigger.dart';
import '../services/sync/delete_propagator.dart';

class TrainingModeProvider extends ChangeNotifier {
  List<TrainingMode> _modes = [];

  List<TrainingMode> get modes => _modes;

  List<TrainingMode> get availableModes => _modes.where((m) => !m.isDeleted).toList();

  TrainingMode? get defaultMode {
    try {
      return availableModes.firstWhere((m) => m.isDefault);
    } catch (_) {
      try {
        return _modes.firstWhere((m) => m.isDefault);
      } catch (_) {
        return null;
      }
    }
  }

  List<String> get availableCategories {
    final set = <String>{};
    for (final m in availableModes) {
      if (m.category.isNotEmpty) set.add(m.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  void loadModes() {
    _modes = TrainingModeDatabase.instance.getAll();
    notifyListeners();
  }

  TrainingMode? getByKey(dynamic key) => TrainingModeDatabase.instance.getByKey(key);

  Future<dynamic> addMode(TrainingMode mode) async {
    final key = await TrainingModeDatabase.instance.add(mode);
    loadModes();
    SyncTrigger.instance.requestSync();
    return key;
  }

  Future<bool> setDefault(dynamic key) async {
    final ok = await TrainingModeDatabase.instance.setDefault(key);
    if (ok) {
      loadModes();
      SyncTrigger.instance.requestSync();
    }
    return ok;
  }

  Future<bool> softDelete(dynamic key) async {
    final intKey = key is int ? key : null;
    final ok = await TrainingModeDatabase.instance.softDelete(key);
    if (ok) {
      loadModes();
      if (intKey != null) {
        unawaited(DeletePropagator.propagateTrainingModeDelete(intKey));
      }
    }
    return ok;
  }

  List<TrainingMode> filterByCategory(String category) {
    if (category.isEmpty || category == 'Tutti') return availableModes;
    return availableModes.where((m) => m.category == category).toList();
  }

  List<TrainingMode> search(String query, {String category = 'Tutti'}) {
    final base = filterByCategory(category);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((m) => m.name.toLowerCase().contains(q)).toList();
  }
}

void unawaited(Future<void> future) {}