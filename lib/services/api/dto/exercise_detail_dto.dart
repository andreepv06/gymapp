/// Dettaglio completo di un esercizio remoto — usato solo in import
/// (fetchAll di ExercisesApiService resta minimale per la sync).
class RemoteExerciseDetail {
  final String id;
  final String name;
  final String muscleGroup;
  final String? notes;

  const RemoteExerciseDetail({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.notes,
  });

  factory RemoteExerciseDetail.fromJson(Map<String, dynamic> json) =>
      RemoteExerciseDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        notes: json['notes'] as String?,
      );
}