class RemoteSession {
  final String id;
  final String workoutName;

  const RemoteSession({required this.id, required this.workoutName});

  factory RemoteSession.fromJson(Map<String, dynamic> json) => RemoteSession(
        id: json['id'] as String,
        workoutName: json['workoutName'] as String,
      );
}