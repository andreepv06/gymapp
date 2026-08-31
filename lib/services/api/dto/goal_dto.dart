class RemoteGoal {
  final String id;
  final String title;
  final String category;

  const RemoteGoal({
    required this.id,
    required this.title,
    required this.category,
  });

  factory RemoteGoal.fromJson(Map<String, dynamic> json) => RemoteGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? '',
      );
}