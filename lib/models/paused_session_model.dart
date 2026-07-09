import 'dart:convert';

/// Modello completo dello stato di una sessione messa in pausa.
/// Serializzabile in JSON per la persistenza su SharedPreferences.
/// Tutti i key Hive (dynamic → int) vengono serializzati come String.
class PausedSessionModel {
  final String sessionId;
  final String workoutId;
  final String workoutName;
  final String startTimeIso;
  final int elapsedSeconds;
  final String dbSessionKey;

  /// Ordine top-level: lista di {type: 'ex'|'circuit', key: '123'}
  final List<Map<String, String>> topOrder;

  /// Dati serie esercizi liberi: exKey → [{w, r, c, hint}]
  final Map<String, List<Map<String, dynamic>>> freeSetData;

  /// Ordine esercizi dentro ogni circuito: circuitKey → [exKey, ...]
  final Map<String, List<String>> circuitExOrder;

  /// Dati serie per round: circuitKey → [round0: {exKey → [{w,r,c,hint}]}, ...]
  final Map<String, List<Map<String, List<Map<String, dynamic>>>>> circuitRoundData;

  const PausedSessionModel({
    required this.sessionId,
    required this.workoutId,
    required this.workoutName,
    required this.startTimeIso,
    required this.elapsedSeconds,
    required this.dbSessionKey,
    required this.topOrder,
    required this.freeSetData,
    required this.circuitExOrder,
    required this.circuitRoundData,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'workoutId': workoutId,
        'workoutName': workoutName,
        'startTimeIso': startTimeIso,
        'elapsedSeconds': elapsedSeconds,
        'dbSessionKey': dbSessionKey,
        'topOrder': topOrder,
        'freeSetData': freeSetData,
        'circuitExOrder': circuitExOrder,
        'circuitRoundData': circuitRoundData.map(
          (ck, rounds) => MapEntry(
            ck,
            rounds
                .map((roundMap) => roundMap.map(
                      (ek, sets) => MapEntry(ek, sets),
                    ))
                .toList(),
          ),
        ),
      };

  static PausedSessionModel fromJson(Map<String, dynamic> json) {
    final rawCircuitRoundData =
        (json['circuitRoundData'] as Map<String, dynamic>? ?? {}).map(
      (ck, rounds) => MapEntry(
        ck,
        (rounds as List)
            .map(
              (roundMap) => (roundMap as Map<String, dynamic>).map(
                (ek, sets) => MapEntry(
                  ek,
                  (sets as List)
                      .map((s) => Map<String, dynamic>.from(s as Map))
                      .toList(),
                ),
              ),
            )
            .toList(),
      ),
    );

    return PausedSessionModel(
      sessionId: json['sessionId'] as String,
      workoutId: json['workoutId'] as String,
      workoutName: json['workoutName'] as String,
      startTimeIso: json['startTimeIso'] as String,
      elapsedSeconds: json['elapsedSeconds'] as int,
      dbSessionKey: json['dbSessionKey'] as String,
      topOrder: (json['topOrder'] as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      freeSetData: (json['freeSetData'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          k,
          (v as List)
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList(),
        ),
      ),
      circuitExOrder: (json['circuitExOrder'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).map((e) => e as String).toList()),
      ),
      circuitRoundData: rawCircuitRoundData,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  static PausedSessionModel fromJsonString(String s) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>);
}