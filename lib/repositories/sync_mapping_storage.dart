import 'package:shared_preferences/shared_preferences.dart';
import '../db/hive_database.dart';

/// FIX CRITICO — le chiavi sono ora scoped per utente V1 locale
/// (HiveDatabase.instance.currentUserId). Prima, più account V1
/// sullo stesso dispositivo condividevano lo stesso SharedPreferences
/// e, avendo entrambi chiavi Hive numeriche che ripartono da 0,
/// finivano per "trovarsi" a vicenda le mappature — puntando a
/// risorse remote di un ALTRO account (causa dei 403 Forbidden su
/// operazioni come setDefault, e di collegamenti esercizi->schede
/// falliti silenziosamente).
class SyncMappingStorage {
  static String _key(String domain, dynamic localKey) {
    final uid = HiveDatabase.instance.currentUserId;
    return 'sync_map_${uid}_${domain}_$localKey';
  }

  static String _prefix(String domain) {
    final uid = HiveDatabase.instance.currentUserId;
    return 'sync_map_${uid}_${domain}_';
  }

  Future<String?> getRemoteId(String domain, dynamic localKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(domain, localKey));
  }

  Future<void> setRemoteId(
      String domain, dynamic localKey, String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(domain, localKey), remoteId);
  }

  Future<void> removeMapping(String domain, dynamic localKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(domain, localKey));
  }

  Future<Map<String, String>> getAllMappings(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefix(domain);
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        final localKey = key.substring(prefix.length);
        final remoteId = prefs.getString(key);
        if (remoteId != null) result[localKey] = remoteId;
      }
    }
    return result;
  }
}