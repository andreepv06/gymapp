import 'package:flutter/material.dart';
import '../db/training_mode_database.dart';
import '../models/training_mode.dart';

// ─────────────────────────────────────────────────────────────
// TrainingModeProvider — FASE 2 (Sistema Modalità di Allenamento)
//
// Wrapper ChangeNotifier su TrainingModeDatabase, stesso pattern
// già usato in questo progetto da WorkoutProvider/GoalProvider/
// SportProvider/ExerciseProvider: nessuna business logic propria
// oltre a un sottile stato osservabile dalla UI.
//
// IMPORTANTE: a differenza di ProfileProvider (che carica subito
// da SharedPreferences, disponibile prima del login), questo
// provider NON carica nulla nel costruttore. TrainingModeDatabase
// apre un box Hive per-utente solo dopo il login (switchUser),
// quindi chiamare loadModes() troppo presto causerebbe un errore
// Hive box-not-open. Le schermate che consumano questo provider
// (Fase 3+) devono chiamare loadModes() nel proprio initState,
// esattamente come già fanno le altre schermate con gli altri
// provider dell'app.
// ─────────────────────────────────────────────────────────────

class TrainingModeProvider extends ChangeNotifier {
  List<TrainingMode> _modes = [];

  /// Tutte le modalità, incluse quelle soft-deleted. Utile per
  /// risolvere riferimenti storici (sessioni che puntano a
  /// modalità non più disponibili — Parte 12/34).
  List<TrainingMode> get modes => _modes;

  /// Solo le modalità attualmente selezionabili per nuovi utilizzi.
  List<TrainingMode> get availableModes =>
      _modes.where((m) => !m.isDeleted).toList();

  /// La modalità predefinita globale attuale, se presente.
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

  /// Elenco delle categorie effettivamente presenti tra le
  /// modalità disponibili, utile per popolare i filtri (Parte 6).
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

  TrainingMode? getByKey(dynamic key) =>
      TrainingModeDatabase.instance.getByKey(key);

  Future<dynamic> addMode(TrainingMode mode) async {
    final key = await TrainingModeDatabase.instance.add(mode);
    loadModes();
    return key;
  }

  /// Imposta [key] come nuova modalità predefinita globale.
  /// Non modifica schede/esercizi/sessioni esistenti (Parte 8).
  Future<bool> setDefault(dynamic key) async {
    final ok = await TrainingModeDatabase.instance.setDefault(key);
    if (ok) loadModes();
    return ok;
  }

  /// Elimina "soft" una modalità. Fallisce se [key] è l'attuale
  /// predefinita (Parte 9): l'utente deve prima cambiare default.
  Future<bool> softDelete(dynamic key) async {
    final ok = await TrainingModeDatabase.instance.softDelete(key);
    if (ok) loadModes();
    return ok;
  }

  /// Filtra le modalità disponibili per categoria. 'Tutti' (o
  /// stringa vuota) restituisce l'elenco completo, senza
  /// modificare i dati sottostanti (Parte 6).
  List<TrainingMode> filterByCategory(String category) {
    if (category.isEmpty || category == 'Tutti') return availableModes;
    return availableModes.where((m) => m.category == category).toList();
  }

  /// Ricerca testuale (per nome) combinata con filtro categoria.
  List<TrainingMode> search(String query, {String category = 'Tutti'}) {
    final base = filterByCategory(category);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((m) => m.name.toLowerCase().contains(q)).toList();
  }
}