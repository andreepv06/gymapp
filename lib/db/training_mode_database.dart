import 'package:hive_flutter/hive_flutter.dart';
import '../models/training_mode.dart';
import '../models/training_mode_adapter.dart';

// ─────────────────────────────────────────────────────────────
// TrainingModeDatabase — FASE 1 (fondamenta dati)
//
// Database dedicato al sistema Modalità di Allenamento,
// completamente separato da HiveDatabase (Fitness), GoalDatabase
// e SportDatabase: box differenti, nessuna dipendenza incrociata.
// Stesso pattern per-utente già usato da GoalDatabase/SportDatabase.
//
// Al primo accesso di un utente (box vuoto) semina un catalogo
// ampio di modalità predefinite e ne marca una come predefinita
// globale. Il seed NON viene mai rieseguito su un box già popolato.
// ─────────────────────────────────────────────────────────────
class TrainingModeDatabase {
  static final TrainingModeDatabase instance =
      TrainingModeDatabase._internal();
  TrainingModeDatabase._internal();

  String _userId = '';

  String get _boxName => '${_userId}_training_modes';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TrainingModeAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(TrainingModeSetAdapter());
    }
  }

  Future<void> switchUser(String userId) async {
    final newId = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (newId == _userId && _boxOpenForCurrentUser()) return;

    _userId = newId;
    if (_userId.isEmpty) return;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<TrainingMode>(_boxName);
    }

    if (_box.isEmpty) {
      await _seedDefaults();
    } else {
      await _ensureDefaultExists();
    }
  }

  bool _boxOpenForCurrentUser() {
    if (_userId.isEmpty) return false;
    return Hive.isBoxOpen(_boxName);
  }

  Box<TrainingMode> get _box => Hive.box<TrainingMode>(_boxName);

  // ── Query ────────────────────────────────────────────────

  /// Tutte le modalità, incluse quelle eliminate (soft-delete).
  /// Utile per lo storico, che deve poter risolvere anche
  /// modalità non più disponibili per nuovi utilizzi.
  List<TrainingMode> getAll() => _box.values.toList();

  /// Solo le modalità attualmente selezionabili per nuovi utilizzi.
  List<TrainingMode> getAvailable() =>
      _box.values.where((m) => !m.isDeleted).toList();

  TrainingMode? getByKey(dynamic key) {
    if (key == null) return null;
    try {
      return _box.get(key);
    } catch (_) {
      return null;
    }
  }

  /// La modalità predefinita globale attuale. Il sistema garantisce
  /// che ne esista sempre esattamente una tra quelle disponibili.
  TrainingMode? getDefault() {
    try {
      return _box.values.firstWhere((m) => m.isDefault && !m.isDeleted);
    } catch (_) {
      try {
        return _box.values.firstWhere((m) => m.isDefault);
      } catch (_) {
        return _box.values.isNotEmpty ? _box.values.first : null;
      }
    }
  }

  // ── Mutazioni ────────────────────────────────────────────

  Future<dynamic> add(TrainingMode mode) => _box.add(mode);

  /// Imposta [key] come nuova modalità predefinita globale.
  /// Non modifica nessuna scheda/esercizio/sessione esistente:
  /// il default vale solo per i nuovi esercizi aggiunti in futuro.
  Future<bool> setDefault(dynamic key) async {
    final target = _box.get(key);
    if (target == null || target.isDeleted) return false;
    for (final m in _box.values) {
      if (m.isDefault && m.key != key) {
        m.isDefault = false;
        await m.save();
      }
    }
    target.isDefault = true;
    target.updatedAt = DateTime.now().toIso8601String();
    await target.save();
    return true;
  }

  /// Elimina "soft" una modalità: diventa non disponibile per nuovi
  /// utilizzi ma resta nel box (mai box.delete) così lo storico che
  /// la referenzia tramite trainingModeKey continua a risolverla.
  /// Non è possibile eliminare la modalità predefinita corrente:
  /// l'utente deve prima impostarne un'altra come predefinita.
  Future<bool> softDelete(dynamic key) async {
    final target = _box.get(key);
    if (target == null) return false;
    if (target.isDefault) return false;
    target.isDeleted = true;
    target.updatedAt = DateTime.now().toIso8601String();
    await target.save();
    return true;
  }

  // ── Seed catalogo predefinito ──────────────────────────────

  Future<void> _seedDefaults() async {
    final now = DateTime.now().toIso8601String();
    final defaults = _buildDefaultCatalog(now);

    dynamic firstKey;
    dynamic threeByEightKey;
    for (final m in defaults) {
      final k = await _box.add(m);
      firstKey ??= k;
      if (m.name == '3×8') threeByEightKey = k;
    }

    final defaultKey = threeByEightKey ?? firstKey;
    if (defaultKey != null) {
      final mode = _box.get(defaultKey);
      if (mode != null) {
        mode.isDefault = true;
        await mode.save();
      }
    }
  }

  Future<void> _ensureDefaultExists() async {
    final hasDefault = _box.values.any((m) => m.isDefault && !m.isDeleted);
    if (hasDefault) return;
    // Difesa contro dati corrotti/incoerenti: promuove la prima
    // modalità disponibile a predefinita, per non lasciare mai il
    // sistema senza un default valido.
    TrainingMode? candidate;
    for (final m in _box.values) {
      if (!m.isDeleted) {
        candidate = m;
        break;
      }
    }
    candidate ??= _box.values.isNotEmpty ? _box.values.first : null;
    if (candidate != null) {
      candidate.isDefault = true;
      await candidate.save();
    }
  }

  List<TrainingMode> _buildDefaultCatalog(String now) {
    List<TrainingModeSet> fixedSets(int n, int reps) => List.generate(
        n, (i) => TrainingModeSet(order: i + 1, fixedReps: reps));

    List<TrainingModeSet> rangeSets(int n, int min, int max) =>
        List.generate(n,
            (i) => TrainingModeSet(order: i + 1, minReps: min, maxReps: max));

    TrainingMode fixedMode(String name, int n, int reps) => TrainingMode(
        name: name,
        category: 'fixed',
        createdAt: now,
        origin: 'predefined',
        sets: fixedSets(n, reps));

    TrainingMode rangeMode(String name, int n, int min, int max) =>
        TrainingMode(
            name: name,
            category: 'range',
            createdAt: now,
            origin: 'predefined',
            sets: rangeSets(n, min, max));

    TrainingMode pyramidMode(String name, List<int> repsSequence) =>
        TrainingMode(
          name: name,
          category: 'pyramid',
          createdAt: now,
          origin: 'predefined',
          sets: List.generate(
              repsSequence.length,
              (i) => TrainingModeSet(
                  order: i + 1, fixedReps: repsSequence[i])),
        );

    final list = <TrainingMode>[];

    // ── Serie fisse: 3/4/5 × 5/6/8/10/12 ──────────────────────
    for (final n in [3, 4, 5]) {
      for (final reps in [5, 6, 8, 10, 12]) {
        list.add(fixedMode('$n×$reps', n, reps));
      }
    }

    // ── Intervalli comuni ──────────────────────────────────────
    list.add(rangeMode('3×6-10', 3, 6, 10));
    list.add(rangeMode('3×8-12', 3, 8, 12));
    list.add(rangeMode('3×10-15', 3, 10, 15));
    list.add(rangeMode('4×6-10', 4, 6, 10));
    list.add(rangeMode('4×8-12', 4, 8, 12));
    list.add(rangeMode('5×8-12', 5, 8, 12));

    // ── Piramidali (reps fisse per gradino) ────────────────────
    list.add(pyramidMode('Piramidale crescente', [6, 8, 10, 12]));
    list.add(pyramidMode('Piramidale decrescente', [12, 10, 8, 6]));
    list.add(pyramidMode('Piramidale doppia', [12, 10, 8, 10, 12]));

    // ── Piramidale con range ────────────────────────────────────
    list.add(TrainingMode(
      name: 'Piramidale crescente (range)',
      category: 'pyramid',
      createdAt: now,
      origin: 'predefined',
      sets: [
        TrainingModeSet(order: 1, minReps: 6, maxReps: 8),
        TrainingModeSet(order: 2, minReps: 8, maxReps: 10),
        TrainingModeSet(order: 3, minReps: 10, maxReps: 12),
        TrainingModeSet(order: 4, minReps: 12, maxReps: 15),
      ],
    ));
    list.add(TrainingMode(
      name: 'Piramidale decrescente (range)',
      category: 'pyramid',
      createdAt: now,
      origin: 'predefined',
      sets: [
        TrainingModeSet(order: 1, minReps: 12, maxReps: 15),
        TrainingModeSet(order: 2, minReps: 10, maxReps: 12),
        TrainingModeSet(order: 3, minReps: 8, maxReps: 10),
        TrainingModeSet(order: 4, minReps: 6, maxReps: 8),
      ],
    ));

    return list;
  }
}