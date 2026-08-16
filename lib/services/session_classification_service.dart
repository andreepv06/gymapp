import '../models/training_mode.dart';

// ─────────────────────────────────────────────────────────────
// SessionClassificationService — FASE 2 (Sistema Modalità)
//
// Servizio puro che determina lo stato di esecuzione di un
// esercizio in una sessione rispetto alla modalità assegnata:
//
//   🟢 STANDARD — struttura prevista completata correttamente.
//   🟡 PARTIAL  — struttura invariata, ma una o più serie non
//                 sono state completate (Parte 19 caso A).
//   🔵 CUSTOM   — la struttura è stata effettivamente modificata
//                 (serie aggiunte/rimosse, reps fuori range,
//                 numero di serie diverso da quello previsto —
//                 Parte 19 caso B, Parte 21, Parte 48).
//
// Questo servizio NON tocca Hive e NON conosce la UI: riceve la
// struttura attesa (TrainingModeSet ordinati) e le serie
// effettivamente eseguite, e restituisce solo la classificazione.
// La persistenza del risultato (executionStatus) è responsabilità
// del chiamante (sessione attiva, Fase 4).
// ─────────────────────────────────────────────────────────────

enum SessionExecutionStatus { standard, partial, custom }

extension SessionExecutionStatusX on SessionExecutionStatus {
  /// Identificatore stabile persistito su HiveSessionSet.executionStatus.
  String get id {
    switch (this) {
      case SessionExecutionStatus.standard: return 'standard';
      case SessionExecutionStatus.partial:  return 'partial';
      case SessionExecutionStatus.custom:   return 'custom';
    }
  }

  static SessionExecutionStatus fromId(String? id) {
    switch (id) {
      case 'standard': return SessionExecutionStatus.standard;
      case 'partial':  return SessionExecutionStatus.partial;
      case 'custom':   return SessionExecutionStatus.custom;
      default:         return SessionExecutionStatus.custom;
    }
  }
}

/// Singola serie effettivamente eseguita, così come registrata
/// dalla sessione attiva. Struttura minima e indipendente dai
/// modelli Hive per mantenere questo servizio puro/testabile.
class ExecutedSetInput {
  /// Posizione della serie nella sessione (1-based, stesso ordine
  /// della struttura della modalità).
  final int order;
  final int? reps;
  final double? weight;
  final bool completed;

  const ExecutedSetInput({
    required this.order,
    this.reps,
    this.weight,
    required this.completed,
  });
}

class SessionClassificationService {
  SessionClassificationService._();

  /// Determina lo stato di esecuzione confrontando la struttura
  /// attesa [expectedSets] (ordinata) con le serie effettivamente
  /// eseguite [actualSets].
  ///
  /// REGOLE (verificate contro i test del piano architetturale):
  /// - Numero di serie diverso da quello previsto → CUSTOM (la
  ///   struttura è stata alterata: aggiunta o rimozione serie).
  /// - Una serie completata con reps fuori dal valore/range
  ///   previsto per quella posizione → CUSTOM (Parte 21), anche se
  ///   il numero di serie corrisponde.
  /// - Se la struttura corrisponde e tutte le reps eseguite sono
  ///   coerenti, ma almeno una serie non è stata completata →
  ///   PARTIAL (Parte 19 caso A).
  /// - Se tutto corrisponde e tutte le serie sono completate →
  ///   STANDARD.
  /// - Modalità senza serie definite (dato corrotto/mancante) →
  ///   CUSTOM per sicurezza, mai un'eccezione (Parte 63).
  static SessionExecutionStatus classify({
    required List<TrainingModeSet> expectedSets,
    required List<ExecutedSetInput> actualSets,
  }) {
    if (expectedSets.isEmpty) {
      return SessionExecutionStatus.custom;
    }

    final ordered = List<TrainingModeSet>.from(expectedSets)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (actualSets.length != ordered.length) {
      return SessionExecutionStatus.custom;
    }

    final actualOrdered = List<ExecutedSetInput>.from(actualSets)
      ..sort((a, b) => a.order.compareTo(b.order));

    bool anyIncomplete = false;

    for (var i = 0; i < ordered.length; i++) {
      final expected = ordered[i];
      final actual = actualOrdered[i];

      if (!actual.completed) {
        anyIncomplete = true;
        continue;
      }

      final reps = actual.reps;
      if (reps == null || reps <= 0) {
        // Marcata completata ma senza reps valide: trattata come
        // non completata ai fini della struttura, mai come errore.
        anyIncomplete = true;
        continue;
      }

      if (!expected.matchesReps(reps)) {
        return SessionExecutionStatus.custom;
      }
    }

    return anyIncomplete
        ? SessionExecutionStatus.partial
        : SessionExecutionStatus.standard;
  }
}