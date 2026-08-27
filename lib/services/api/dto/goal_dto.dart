class RemoteGoal {
  final String id;
  const RemoteGoal({required this.id});
  factory RemoteGoal.fromJson(Map<String, dynamic> json) =>
      RemoteGoal(id: json['id'] as String);
}