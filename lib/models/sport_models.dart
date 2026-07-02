import 'package:hive/hive.dart';

/// Esteso con camminata, hiking e altro per coprire lo storico
/// multi-sport completo richiesto dalla blueprint.
enum SportType { running, cycling, swimming, walking, hiking, other }

extension SportTypeX on SportType {
  String get id => toString().split('.').last;

  static SportType fromId(String id) {
    switch (id) {
      case 'running':  return SportType.running;
      case 'cycling':  return SportType.cycling;
      case 'swimming': return SportType.swimming;
      case 'walking':  return SportType.walking;
      case 'hiking':   return SportType.hiking;
      default:         return SportType.other;
    }
  }

  String get label {
    switch (this) {
      case SportType.running:  return 'Corsa';
      case SportType.cycling:  return 'Ciclismo';
      case SportType.swimming: return 'Nuoto';
      case SportType.walking:  return 'Camminata';
      case SportType.hiking:   return 'Hiking';
      case SportType.other:    return 'Altro sport';
    }
  }
}

/// Sessione generica per sport non-palestra. Il campo sportType
/// è salvato come String (valore dell'enum) — nessuna migrazione
/// necessaria aggiungendo nuovi valori all'enum.
class HiveSportSession extends HiveObject {
  String sportType;
  String date;
  int durationSeconds;
  double? distanceKm;
  String? notes;

  HiveSportSession({
    required this.sportType,
    required this.date,
    required this.durationSeconds,
    this.distanceKm,
    this.notes,
  });
}