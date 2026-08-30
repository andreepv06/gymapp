/// DTO — rispecchia esattamente Exercise nello schema Prisma
/// (backend/src/exercises/exercises.service.ts) e i campi realmente
/// restituiti da GET/POST /exercises. Nessun campo inventato.
class RemoteExercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String? notes;
  final bool isCustom;

  const RemoteExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.notes,
    required this.isCustom,
  });

  factory RemoteExercise.fromJson(Map<String, dynamic> json) => RemoteExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        notes: json['notes'] as String?,
        isCustom: json['isCustom'] as bool? ?? true,
      );
}