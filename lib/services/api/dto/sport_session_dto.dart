class RemoteSportSession {
  final String id;
  const RemoteSportSession({required this.id});
  factory RemoteSportSession.fromJson(Map<String, dynamic> json) =>
      RemoteSportSession(id: json['id'] as String);
}