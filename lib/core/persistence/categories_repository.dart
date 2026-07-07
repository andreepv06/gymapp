import 'package:shared_preferences/shared_preferences.dart';

/// Persistenza delle categorie degli obiettivi.
///
/// Categorie predefinite: immutabili, non rinominabili né eliminabili.
/// Categorie custom: salvate in SharedPreferences, rinominabili ed eliminabili.
/// L'eliminazione NON rompe obiettivi esistenti: il campo `category`
/// in HiveGoal rimane invariato — semplicemente quella categoria
/// non apparirà più tra le scelte future.
class CategoriesRepository {
  static const String _key = 'goal_custom_categories';
  static const int maxLength = 50;

  static const List<String> predefined = [
    'Salute',
    'Studio',
    'Sport',
    'Lavoro',
    'Alimentazione',
    'Benessere',
    'Produttività',
    'Hobby',
    'Tempo libero',
    'Finanze',
    'Lettura',
    'Meditazione',
  ];

  static Future<List<String>> loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_key) ?? []);
  }

  static Future<List<String>> loadAll() async {
    final custom = await loadCustom();
    return [...predefined, ...custom];
  }

  /// Aggiunge una categoria custom.
  /// Ritorna `null` se ok, stringa di errore se fallisce.
  static Future<String?> addCustom(String name) async {
    final t = name.trim();
    if (t.isEmpty) return 'Il nome non può essere vuoto.';
    if (t.length > maxLength) return 'Massimo $maxLength caratteri.';

    final all = await loadAll();
    if (all.any((c) => c.toLowerCase() == t.toLowerCase())) {
      return 'Esiste già una categoria con questo nome.';
    }

    final custom = await loadCustom();
    custom.add(t);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, custom);
    return null;
  }

  /// Rinomina una categoria custom.
  /// Ritorna `null` se ok, stringa di errore se fallisce.
  static Future<String?> renameCustom(String old, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) return 'Il nome non può essere vuoto.';
    if (t.length > maxLength) return 'Massimo $maxLength caratteri.';

    final custom = await loadCustom();
    final idx =
        custom.indexWhere((c) => c.toLowerCase() == old.toLowerCase());
    if (idx < 0) return 'Categoria non trovata.';

    final allExcept = [
      ...predefined,
      ...custom.where((c) => c.toLowerCase() != old.toLowerCase()),
    ];
    if (allExcept.any((c) => c.toLowerCase() == t.toLowerCase())) {
      return 'Esiste già una categoria con questo nome.';
    }

    custom[idx] = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, custom);
    return null;
  }

  /// Elimina una categoria custom. Non tocca gli obiettivi esistenti.
  static Future<void> deleteCustom(String name) async {
    final custom = await loadCustom();
    custom.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, custom);
  }

  static bool isPredefined(String name) =>
      predefined.any((c) => c.toLowerCase() == name.toLowerCase());
}