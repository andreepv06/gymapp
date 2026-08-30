/// DTO — rispecchia Workout/WorkoutExercise nello schema Prisma
/// (backend/src/workouts/*). Nessun campo inventato.
class RemoteWorkout {
  final String id;
  final String name;
  final String? iconId;
  final int? iconColorIndex;

  const RemoteWorkout({
    required this.id,
    required this.name,
    this.iconId,
    this.iconColorIndex,
  });

  factory RemoteWorkout.fromJson(Map<String, dynamic> json) => RemoteWorkout(
        id: json['id'] as String,
        name: json['name'] as String,
        iconId: json['iconId'] as String?,
        iconColorIndex: json['iconColorIndex'] as int?,
      );
}