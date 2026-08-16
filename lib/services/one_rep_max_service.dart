// ─────────────────────────────────────────────────────────────
// OneRepMaxService — FASE 2 (Sistema Modalità di Allenamento)
//
// Servizio puro, indipendente dalla UI, responsabile del calcolo
// del valore rappresentativo di una sessione a partire dalle
// serie zavorrate valide (Parte 28-30 del piano architetturale).
//
// FORMULA: Epley — 1RM = peso × (1 + reps / 30).
// Isolata in questo servizio per poter essere sostituita in
// futuro senza toccare storico/grafici (Parte 28/55).
//
// SERIE VALIDA (Parte 26): peso > 0 AND reps > 0.
// Il database NON deve mai essere modificato da questo servizio:
// riceve dati già letti e restituisce solo valori calcolati.
// ─────────────────────────────────────────────────────────────

/// Rappresenta una singola serie zavorrata da usare nel calcolo
/// del valore di sessione. Struttura minima e indipendente dai
/// modelli Hive, per non accoppiare questo servizio al database.
class WeightedSetInput {
  final double weight;
  final int reps;
  const WeightedSetInput({required this.weight, required this.reps});

  /// Serie valida per il calcolo del carico (Parte 26).
  bool get isValid => weight > 0 && reps > 0;
}

class OneRepMaxService {
  OneRepMaxService._();

  /// 1RM stimato con la formula di Epley. Ritorna null se i dati
  /// non sono sufficienti (peso o reps non validi) — Parte 26/30.
  static double? epley(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return null;
    return weight * (1 + reps / 30);
  }

  /// Valore rappresentativo di una sessione: MEDIA ARITMETICA degli
  /// 1RM stimati delle serie zavorrate valide (Parte 29). Le serie
  /// non valide (corpo libero, dati mancanti) vengono escluse dal
  /// calcolo ma non influenzano il risultato in altro modo.
  ///
  /// Ritorna null se non esiste nessuna serie zavorrata valida
  /// (es. sessione interamente a corpo libero — Parte 25/27): in
  /// quel caso la sessione resta comunque nello storico, ma non
  /// produce un punto nel grafico del carico.
  static double? representativeSessionValue(List<WeightedSetInput> sets) {
    final validOneRms = sets
        .where((s) => s.isValid)
        .map((s) => epley(s.weight, s.reps))
        .whereType<double>()
        .toList();
    if (validOneRms.isEmpty) return null;
    final sum = validOneRms.reduce((a, b) => a + b);
    return sum / validOneRms.length;
  }
}