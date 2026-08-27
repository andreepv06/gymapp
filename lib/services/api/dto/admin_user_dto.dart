class AdminUserSummary {
  final String id;
  final String identifier;
  final String role;
  final bool isActive;
  final bool emailVerified;
  final String? displayName;
  final DateTime createdAt;

  const AdminUserSummary({
    required this.id,
    required this.identifier,
    required this.role,
    required this.isActive,
    required this.emailVerified,
    this.displayName,
    required this.createdAt,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return AdminUserSummary(
      id: json['id'] as String,
      identifier: json['identifier'] as String,
      role: json['role'] as String,
      isActive: json['isActive'] as bool? ?? true,
      emailVerified: json['emailVerified'] as bool? ?? false,
      displayName: profile?['displayName'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}