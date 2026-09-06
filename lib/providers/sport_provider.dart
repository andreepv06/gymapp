import 'package:flutter/material.dart';
import '../db/sport_database.dart';
import '../models/sport_models.dart';
import '../services/sync/sync_trigger.dart';

class SportStats {
  final int count;
  final int totalSeconds;
  final double totalKm;
  final double avgSecondsPerSession;
  final double avgKmPerSession;
  final Map<String, int> sessionsByMonth;
  final Map<String, double> kmByMonth;
  const SportStats({
    required this.count,
    required this.totalSeconds,
    required this.totalKm,
    required this.avgSecondsPerSession,
    required this.avgKmPerSession,
    required this.sessionsByMonth,
    required this.kmByMonth,
  });
}

class SportProvider extends ChangeNotifier {
  List<HiveSportSession> _sessions = [];
  List<HiveSportSession> get sessions => _sessions;

  void loadSessions() {
    _sessions = SportDatabase.instance.getSessions();
    notifyListeners();
  }

  List<HiveSportSession> sessionsForSport(SportType type) =>
      _sessions.where((s) => s.sportType == type.id).toList();

  Future<void> addSession({
    required SportType type,
    required int durationSeconds,
    double? distanceKm,
    String? notes,
  }) async {
    await SportDatabase.instance.addSession(HiveSportSession(
      sportType: type.id,
      date: DateTime.now().toIso8601String(),
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      notes: notes,
    ));
    loadSessions();
    SyncTrigger.instance.requestSync();
  }

  Future<void> deleteSession(dynamic key) async {
    await SportDatabase.instance.deleteSession(key);
    loadSessions();
    // Nessuna propagazione DELETE al backend in questo blocco (limite
    // dichiarato): la sessione sportiva resta orfana sul backend fino
    // a un'estensione futura di DeletePropagator per questo dominio.
  }

  SportStats statsFor(SportType type) {
    final list = sessionsForSport(type);
    final totalSeconds = list.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final totalKm = list.fold<double>(0, (sum, s) => sum + (s.distanceKm ?? 0));
    final count = list.length;
    final sessionsByMonth = <String, int>{};
    final kmByMonth = <String, double>{};
    for (final s in list) {
      final dt = DateTime.tryParse(s.date);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      sessionsByMonth[key] = (sessionsByMonth[key] ?? 0) + 1;
      kmByMonth[key] = (kmByMonth[key] ?? 0) + (s.distanceKm ?? 0);
    }
    return SportStats(
      count: count,
      totalSeconds: totalSeconds,
      totalKm: totalKm,
      avgSecondsPerSession: count > 0 ? totalSeconds / count : 0,
      avgKmPerSession: count > 0 ? totalKm / count : 0,
      sessionsByMonth: sessionsByMonth,
      kmByMonth: kmByMonth,
    );
  }
}