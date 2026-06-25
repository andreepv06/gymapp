import 'package:hive_flutter/hive_flutter.dart';
import '../models/goal_models.dart';
import '../models/goal_models_adapter.dart';

/// Database del sistema Goals & Habits. Completamente separato da
/// HiveDatabase (sistema Fitness): box differenti, nessuna
/// dipendenza incrociata. Hive.initFlutter() è già chiamato da
/// HiveDatabase.instance.init() in main(); qui registriamo solo
/// gli adapter dedicati.
class GoalDatabase {
  static final GoalDatabase instance = GoalDatabase._internal();
  GoalDatabase._internal();

  String _userId = '';

  String get _goalsBoxName => '${_userId}_goals';
  String get _completionsBoxName => '${_userId}_goal_completions';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(HiveGoalAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(HiveGoalCompletionAdapter());
    }
  }

  Future<void> switchUser(String userId) async {
    final newId = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (newId == _userId && _boxesOpen()) return;

    _userId = newId;
    if (_userId.isEmpty) return;

    if (!Hive.isBoxOpen(_goalsBoxName)) {
      await Hive.openBox<HiveGoal>(_goalsBoxName);
    }
    if (!Hive.isBoxOpen(_completionsBoxName)) {
      await Hive.openBox<HiveGoalCompletion>(_completionsBoxName);
    }
  }

  bool _boxesOpen() {
    if (_userId.isEmpty) return false;
    return Hive.isBoxOpen(_goalsBoxName) && Hive.isBoxOpen(_completionsBoxName);
  }

  Box<HiveGoal> get _goalsBox => Hive.box<HiveGoal>(_goalsBoxName);
  Box<HiveGoalCompletion> get _completionsBox =>
      Hive.box<HiveGoalCompletion>(_completionsBoxName);

  // ── Goals ──

  List<HiveGoal> getGoals() => _goalsBox.values.toList();

  Future<dynamic> addGoal(HiveGoal goal) => _goalsBox.add(goal);

  Future<void> updateGoal(dynamic key, HiveGoal goal) => _goalsBox.put(key, goal);

  Future<void> deleteGoal(dynamic key) async {
    await _goalsBox.delete(key);
    final toDelete = _completionsBox.keys
        .where((k) => _completionsBox.get(k)?.goalKey == key)
        .toList();
    await _completionsBox.deleteAll(toDelete);
  }

  // ── Completions ──

  HiveGoalCompletion? getCompletion(dynamic goalKey, String date) {
    try {
      return _completionsBox.values
          .firstWhere((c) => c.goalKey == goalKey && c.date == date);
    } catch (_) {
      return null;
    }
  }

  List<HiveGoalCompletion> getCompletionsForGoal(dynamic goalKey) =>
      _completionsBox.values.where((c) => c.goalKey == goalKey).toList();

  List<HiveGoalCompletion> getCompletionsForDate(String date) =>
      _completionsBox.values.where((c) => c.date == date).toList();

  Future<void> setCompletion(dynamic goalKey, String date, bool completed) async {
    final existing = getCompletion(goalKey, date);
    if (existing != null) {
      existing.completed = completed;
      await existing.save();
    } else {
      await _completionsBox.add(HiveGoalCompletion(
        goalKey: goalKey,
        date: date,
        completed: completed,
      ));
    }
  }
}