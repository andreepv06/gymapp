import 'package:hive/hive.dart';

// ─────────────────────────────────────────────────────────────
// Sistema Modalità di Allenamento — FASE 1 (fondamenta dati)
//
// Una modalità NON è più semplicemente "serie × reps": è una
// sequenza ordinata di serie (TrainingModeSet), ciascuna con
// ripetizioni fisse OPPURE un intervallo min/max. Questo copre
// sia gli schemi semplici (3×8) sia strutture più complesse
// (piramidali, range, schemi custom arbitrari).
//
// IDENTITÀ: l'identificatore di una TrainingMode è la sua chiave
// Hive (key), MAI il nome. L'eliminazione è sempre "soft"
// (isDeleted = true), non viene mai chiamato box.delete su una
// modalità: questo garantisce che la chiave resti stabile per
// sempre, anche dopo l'eliminazione, così le sessioni storiche
// che referenziano trainingModeKey continuano a risolvere
// correttamente la modalità originale (Parte 12/34/50/54/64).
//
// VERSIONAMENTO: se una modalità viene modificata strutturalmente
// (nome, serie, reps, range...), le fasi successive creeranno una
// NUOVA TrainingMode (nuova key) invece di alterare quella
// esistente, così lo storico che punta alla vecchia key non viene
// mai alterato retroattivamente. Il campo parentModeKey è
// predisposto per tracciare questa discendenza (usato dalle fasi
// successive, non ancora popolato in questa fase).
// ─────────────────────────────────────────────────────────────

@HiveType(typeId: 11)
class TrainingModeSet {
  /// Ordine/posizione della serie all'interno della modalità (1-based).
  @HiveField(0)
  late int order;

  /// Ripetizioni fisse. Mutuamente alternativo a min/maxReps.
  @HiveField(1)
  int? fixedReps;

  /// Ripetizioni minime (per serie a intervallo, es. 8–12).
  @HiveField(2)
  int? minReps;

  /// Ripetizioni massime (per serie a intervallo, es. 8–12).
  @HiveField(3)
  int? maxReps;

  TrainingModeSet({
    required this.order,
    this.fixedReps,
    this.minReps,
    this.maxReps,
  });

  bool get isRange => minReps != null && maxReps != null;

  /// Vero se [reps] rientra nella struttura prevista da questa serie
  /// (usato dalle fasi successive per la classificazione
  /// Standard/Parziale/Custom).
  bool matchesReps(int reps) {
    if (isRange) return reps >= minReps! && reps <= maxReps!;
    if (fixedReps != null) return reps == fixedReps;
    return false;
  }

  /// Etichetta leggibile della singola serie (es. "8" oppure "8-12").
  String get label => isRange ? '$minReps-$maxReps' : '${fixedReps ?? '-'}';

  TrainingModeSet copyWith({
    int? order,
    int? fixedReps,
    int? minReps,
    int? maxReps,
    bool clearFixed = false,
    bool clearRange = false,
  }) => TrainingModeSet(
    order: order ?? this.order,
    fixedReps: clearFixed ? null : (fixedReps ?? this.fixedReps),
    minReps: clearRange ? null : (minReps ?? this.minReps),
    maxReps: clearRange ? null : (maxReps ?? this.maxReps),
  );
}

@HiveType(typeId: 10)
class TrainingMode extends HiveObject {
  @HiveField(0)
  late String name;

  /// Categoria libera per classificazione/filtri/UX.
  /// Valori tipici: 'fixed' | 'range' | 'pyramid' | 'custom' | 'other'.
  /// NON vincola la struttura interna della modalità.
  @HiveField(1)
  late String category;

  @HiveField(2)
  late String createdAt; // ISO8601

  @HiveField(3)
  String? updatedAt; // ISO8601

  /// Soft-delete: la modalità non è più selezionabile per nuovi
  /// utilizzi, ma resta nel box e continua a essere risolvibile
  /// dallo storico che la referenzia.
  @HiveField(4)
  late bool isDeleted;

  /// Vero se questa è l'unica modalità predefinita globale attuale.
  @HiveField(5)
  late bool isDefault;

  /// 'predefined' | 'custom' | 'legacy'
  @HiveField(6)
  late String origin;

  /// Predisposizione per il versionamento: chiave della modalità da
  /// cui questa deriva strutturalmente (non ancora popolato in
  /// questa fase, verrà usato dalla UI di modifica modalità).
  @HiveField(7)
  int? parentModeKey;

  @HiveField(8)
  late List<TrainingModeSet> sets;

  TrainingMode({
    required this.name,
    required this.category,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.isDefault = false,
    this.origin = 'custom',
    this.parentModeKey,
    required this.sets,
  });

  dynamic get id => key;

  bool get isAvailable => !isDeleted;

  int get setCount => sets.length;

  List<TrainingModeSet> get orderedSets =>
      List<TrainingModeSet>.from(sets)
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Etichetta leggibile della struttura, es. "3×8", "3×8-12",
  /// oppure per strutture eterogenee "12/10/8/6".
  String get structureLabel {
    final ordered = orderedSets;
    if (ordered.isEmpty) return name;

    final allFixed = ordered.every((s) => s.fixedReps != null && !s.isRange);
    if (allFixed) {
      final distinctReps = ordered.map((s) => s.fixedReps).toSet();
      if (distinctReps.length == 1) {
        return '${ordered.length}×${ordered.first.fixedReps}';
      }
    }

    final allRange = ordered.every((s) => s.isRange);
    if (allRange) {
      final distinctRanges =
          ordered.map((s) => '${s.minReps}-${s.maxReps}').toSet();
      if (distinctRanges.length == 1) {
        return '${ordered.length}×${ordered.first.minReps}'
            '-${ordered.first.maxReps}';
      }
    }

    // Struttura eterogenea (piramidale, custom variabile...)
    return ordered.map((s) => s.label).join('/');
  }
}