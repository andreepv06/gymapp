import 'package:flutter/material.dart';
import '../db/goal_database.dart';
import '../models/goal_models.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Provider del sistema Goals & Habits. Non conosce e non
/// referenzia nulla del sistema Fitness.
class GoalProvider extends ChangeNotifier {
  List<HiveGoal> _goals = [];

  List<HiveGoal> get goals => _goals;
  List<HiveGoal> get activeGoals =>
      _goals.where((g) => g.status == 'active').toList();

  void loadGoals() {
    _goals = GoalDatabase.instance.getGoals();
    notifyListeners();
  }

  // ── Scheduling ──

  /// Determina se un goal è programmato per una determinata data.
  bool isScheduledOn(HiveGoal goal, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    switch (goal.scheduleType) {
      case 'daily':
        return true;
      case 'specificDays':
        return (goal.scheduleDaysOfWeek ?? []).contains(d.weekday);
      case 'weekend':
        return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      case 'weekdays':
        return d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;
      case 'dateRange':
        final start = DateTime.tryParse(goal.scheduleStartDate ?? '');
        final end = DateTime.tryParse(goal.scheduleEndDate ?? '');
        if (start == null || end == null) return false;
        return !d.isBefore(DateTime(start.year, start.month, start.day)) &&
            !d.isAfter(DateTime(end.year, end.month, end.day));
      case 'customInterval':
        final anchor = DateTime.tryParse(goal.scheduleStartDate ?? '') ??
            DateTime.tryParse(goal.createdAt);
        final interval = goal.scheduleCustomInterval ?? 1;
        if (anchor == null || interval <= 0) return false;
        final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
        final diff = d.difference(anchorDay).inDays;
        return diff >= 0 && diff % interval == 0;
      default:
        return false;
    }
  }

  List<HiveGoal> goalsForDate(DateTime date) => activeGoals
      .where((g) => isScheduledOn(g, date))
      .toList();

  bool isCompletedOn(HiveGoal goal, DateTime date) {
    final c = GoalDatabase.instance.getCompletion(goal.key, _fmtDate(date));
    return c?.completed ?? false;
  }

  double completionPercentageForDate(DateTime date) {
    final scheduled = goalsForDate(date);
    if (scheduled.isEmpty) return 0;
    final done = scheduled.where((g) => isCompletedOn(g, date)).length;
    return done / scheduled.length;
  }

  // ── CRUD ──

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
    await GoalDatabase.instance.addGoal(HiveGoal(
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
    ));
    loadGoals();
  }

  Future<void> updateGoal(dynamic key, HiveGoal updated) async {
    await GoalDatabase.instance.updateGoal(key, updated);
    loadGoals();
  }

  Future<void> deleteGoal(dynamic key) async {
    await GoalDatabase.instance.deleteGoal(key);
    loadGoals();
  }

  Future<void> setStatus(HiveGoal goal, String status) async {
    goal.status = status;
    await goal.save();
    loadGoals();
  }

  // ── Completion + streak ──

  Future<void> toggleCompletion(HiveGoal goal, DateTime date) async {
    final dateStr = _fmtDate(date);
    final current = GoalDatabase.instance.getCompletion(goal.key, dateStr);
    final newValue = !(current?.completed ?? false);
    await GoalDatabase.instance.setCompletion(goal.key, dateStr, newValue);
    _recalcStreak(goal);
    notifyListeners();
  }

  void _recalcStreak(HiveGoal goal) {
    int streak = 0;
    DateTime cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    // Cammina indietro nel tempo: per ogni giorno SCHEDULATO,
    // deve esserci un completamento positivo, altrimenti la
    // catena si interrompe.
    while (true) {
      if (isScheduledOn(goal, cursor)) {
        final c = GoalDatabase.instance.getCompletion(goal.key, _fmtDate(cursor));
        if (c != null && c.completed) {
          streak++;
        } else {
          break;
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
      // Limite di sicurezza per non girare all'infinito su goal
      // creati molto tempo fa senza alcun completamento.
      if (DateTime.now().difference(cursor).inDays > 3650) break;
    }

    goal.currentStreak = streak;
    if (streak > goal.bestStreak) goal.bestStreak = streak;
    goal.save();
  }

  // ── Storico (per la sezione Obiettivi dello Storico) ──

  List<HiveGoalCompletion> completionsForGoal(dynamic goalKey) =>
      GoalDatabase.instance.getCompletionsForGoal(goalKey);
}