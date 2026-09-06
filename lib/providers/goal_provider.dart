import 'package:flutter/material.dart';
import '../db/goal_database.dart';
import '../models/goal_models.dart';
import '../services/sync/sync_trigger.dart';
import '../services/sync/delete_propagator.dart';

class GoalProvider extends ChangeNotifier {
  List<HiveGoal> _goals = [];
  List<HiveGoal> get goals => _goals;

  void loadGoals() {
    _goals = GoalDatabase.instance.getGoals();
    notifyListeners();
  }

  List<HiveGoal> goalsForDate(DateTime date) {
    return _goals.where((g) => g.status == 'active' && _isScheduledOn(g, date)).toList();
  }

  double completionPercentageForDate(DateTime date) {
    final scheduled = goalsForDate(date);
    if (scheduled.isEmpty) return 0;
    final dateStr = _fmt(date);
    final completed = scheduled
        .where((g) =>
            GoalDatabase.instance.getCompletion(g.key, dateStr)?.completed == true)
        .length;
    return completed / scheduled.length;
  }

  bool isCompletedOn(HiveGoal goal, DateTime date) {
    final c = GoalDatabase.instance.getCompletion(goal.key, _fmt(date));
    return c?.completed ?? false;
  }

  Future<void> toggleCompletion(HiveGoal goal, DateTime date) async {
    final dateStr = _fmt(date);
    final current = isCompletedOn(goal, date);
    await GoalDatabase.instance.setCompletion(goal.key, dateStr, !current);
    _updateStreak(goal);
    notifyListeners();
    SyncTrigger.instance.requestSync();
  }

  List<HiveGoalCompletion> completionsForGoal(dynamic key) =>
      GoalDatabase.instance.getCompletionsForGoal(key);

  Future<void> addGoal({
    required String title,
    String? description,
    required String category,
    required String scheduleType,
    List<int>? scheduleDaysOfWeek,
    String? scheduleStartDate,
    String? scheduleEndDate,
    int? scheduleCustomInterval,
    String? deadlineDate,
    int colorIndex = 0,
  }) async {
    final goal = HiveGoal(
      title: title,
      description: description,
      category: category,
      createdAt: DateTime.now().toIso8601String(),
      scheduleType: scheduleType,
      scheduleDaysOfWeek: scheduleDaysOfWeek,
      scheduleStartDate: scheduleStartDate,
      scheduleEndDate: scheduleEndDate,
      scheduleCustomInterval: scheduleCustomInterval,
      deadlineDate: deadlineDate,
      colorIndex: colorIndex,
    );
    await GoalDatabase.instance.addGoal(goal);
    loadGoals();
    SyncTrigger.instance.requestSync();
  }

  Future<void> updateGoal(dynamic key, HiveGoal updated) async {
    await GoalDatabase.instance.updateGoal(key, updated);
    loadGoals();
    SyncTrigger.instance.requestSync();
  }

  Future<void> deleteGoal(dynamic key) async {
    final intKey = key is int ? key : null;
    await GoalDatabase.instance.deleteGoal(key);
    loadGoals();
    if (intKey != null) {
      unawaited(DeletePropagator.propagateGoalDelete(intKey));
    }
  }

  Future<void> setStatus(HiveGoal goal, String status) async {
    goal.status = status;
    await goal.save();
    loadGoals();
    SyncTrigger.instance.requestSync();
  }

  bool _isScheduledOn(HiveGoal goal, DateTime date) {
    switch (goal.scheduleType) {
      case 'daily':
        return true;
      case 'specificDays':
        return (goal.scheduleDaysOfWeek ?? []).contains(date.weekday);
      case 'weekend':
        return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      case 'weekdays':
        return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
      case 'dateRange':
        final start = goal.scheduleStartDate != null ? DateTime.tryParse(goal.scheduleStartDate!) : null;
        final end = goal.scheduleEndDate != null ? DateTime.tryParse(goal.scheduleEndDate!) : null;
        final d = DateTime(date.year, date.month, date.day);
        if (start != null) {
          final s = DateTime(start.year, start.month, start.day);
          if (d.isBefore(s)) return false;
        }
        if (end != null) {
          final e = DateTime(end.year, end.month, end.day);
          if (d.isAfter(e)) return false;
        }
        return true;
      case 'customInterval':
        final start = goal.scheduleStartDate != null ? DateTime.tryParse(goal.scheduleStartDate!) : null;
        if (start == null) return true;
        final interval = goal.scheduleCustomInterval ?? 1;
        final s = DateTime(start.year, start.month, start.day);
        final d = DateTime(date.year, date.month, date.day);
        final diff = d.difference(s).inDays;
        return diff >= 0 && diff % interval == 0;
      default:
        return true;
    }
  }

  void _updateStreak(HiveGoal goal) {
    final completions = GoalDatabase.instance.getCompletionsForGoal(goal.key);
    final completedDates = completions.where((c) => c.completed).map((c) => c.date).toSet();
    int streak = 0;
    DateTime date = DateTime.now();
    for (int guard = 0; guard < 1000; guard++) {
      if (!_isScheduledOn(goal, date)) {
        date = date.subtract(const Duration(days: 1));
        continue;
      }
      if (!completedDates.contains(_fmt(date))) break;
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    goal.currentStreak = streak;
    if (streak > goal.bestStreak) goal.bestStreak = streak;
    goal.save();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void unawaited(Future<void> future) {}