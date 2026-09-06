import 'package:shared_preferences/shared_preferences.dart';

/// Mapping persistente locale↔remoto per rendere le sincronizzazioni
/// realmente idempotenti: ogni entità locale (chiave Hive) sincronizzata
/// viene registrata con l'id remoto assegnato dal backend. Le
/// esecuzioni successive dei *SyncRepository consultano questa mappa
/// per saltare ciò che è già stato sincronizzato, invece di ricreare
/// duplicati. Dati salvati in SharedPreferences, separati per dominio
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

  /// NUOVO — rimuove la mappatura locale↔remoto. Va chiamato dopo aver
  /// propagato con successo una cancellazione al backend, così un
  /// futuro riutilizzo della stessa chiave Hive (es. dopo un reinstall)
  /// non trova un remoteId "fantasma" ormai cancellato sul server.
  Future<void> removeMapping(String domain, dynamic localKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(domain, localKey));
  }

  /// NUOVO — restituisce tutte le mappature {localKey: remoteId} per un
  /// dominio su questo dispositivo. Usato dalla riconciliazione delle
  /// cancellazioni al pull (BackendImportRepository): permette di capire
  /// quali elementi locali, già sincronizzati in passato, sono spariti
  /// dal backend (cancellati da un altro dispositivo) e vanno quindi
  /// rimossi anche qui.
  Future<Map<String, String>> getAllMappings(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'sync_map_${domain}_';
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