import 'package:shared_preferences/shared_preferences.dart';

/// Mapping persistente locale↔remoto per rendere le sincronizzazioni
/// realmente idempotenti: ogni entità locale (chiave Hive) sincronizzata
/// viene registrata con l'id remoto assegnato dal backend. Le
/// esecuzioni successive dei *SyncRepository consultano questa mappa
/// per saltare ciò che è già stato sincronizzato, invece di ricreare
/// duplicati — risolve strutturalmente il limite dichiarato negli
/// Step 6-11. Dati salvati in SharedPreferences, separati per dominio
/// e chiave locale, nessuna sovrapposizione con dati V1 esistenti.
class SyncMappingStorage {
  static String _key(String domain, dynamic localKey) =>
      'sync_map_${domain}_$localKey';

  Future<String?> getRemoteId(String domain, dynamic localKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(domain, localKey));
  }

  Future<void> setRemoteId(
      String domain, dynamic localKey, String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(domain, localKey), remoteId);
  }
}