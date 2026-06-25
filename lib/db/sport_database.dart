import 'package:hive_flutter/hive_flutter.dart';
import '../models/sport_models.dart';
import '../models/sport_models_adapter.dart';

/// Database multi-sport (running/cycling/swimming). Indipendente
/// dal sistema Fitness "gym" (HiveDatabase) e dal sistema Goals
/// (GoalDatabase).
class SportDatabase {
  static final SportDatabase instance = SportDatabase._internal();
  SportDatabase._internal();

  String _userId = '';

  String get _boxName => '${_userId}_sport_sessions';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(HiveSportSessionAdapter());
    }
  }

  Future<void> switchUser(String userId) async {
    final newId = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    _userId = newId;
    if (_userId.isEmpty) return;
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<HiveSportSession>(_boxName);
    }
  }

  Box<HiveSportSession> get _box => Hive.box<HiveSportSession>(_boxName);

  List<HiveSportSession> getSessions() {
    final list = _box.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<HiveSportSession> getSessionsForSport(SportType type) =>
      getSessions().where((s) => s.sportType == type.id).toList();

  Future<dynamic> addSession(HiveSportSession session) => _box.add(session);

  Future<void> deleteSession(dynamic key) => _box.delete(key);
}