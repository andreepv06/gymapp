import 'package:hive/hive.dart';

/// Sport supportati. Architettura pensata per essere estesa con
/// nuovi sport in futuro senza toccare il sistema Fitness "gym"
/// esistente (HiveWorkout/HiveSession restano dedicati alla palestra).
enum SportType { running, cycling, swimming }

extension SportTypeX on SportType {
  String get id => toString().split('.').last;

  static SportType fromId(String id) =>
      SportType.values.firstWhere((s) => s.id == id);

  String get label {
    switch (this) {
      case SportType.running:
        return 'Corsa';
      case SportType.cycling:
        return 'Ciclismo';
      case SportType.swimming:
        return 'Nuoto';
    }
  }
}

/// Sessione generica per sport non-palestra. Volutamente semplice:
/// ogni sport futuro può riusare questa stessa struttura o, se
/// necessario, esserne esteso senza impattare il sistema Fitness.
class HiveSportSession extends HiveObject {
  String sportType; // SportType.id
  String date; // ISO8601
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