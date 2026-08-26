/// DTO — rispecchia Circuit nello schema Prisma (backend/src/workouts/circuits.service.ts).
class RemoteCircuit {
  final String id;
  final String name;
  final int rounds;
  final int sortOrder;

  const RemoteCircuit({
    required this.id,
    required this.name,
    required this.rounds,
    required this.sortOrder,
  });

  factory RemoteCircuit.fromJson(Map<String, dynamic> json) => RemoteCircuit(
        id: json['id'] as String,
        name: json['name'] as String,
        rounds: json['rounds'] as int? ?? 3,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}