/// DTO — rispecchiano esattamente le response reali del backend
/// (AuthService.issueTokens, UsersService.getProfile). Nessun campo
/// inventato: solo quanto il backend restituisce davvero.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class BackendUserProfile {
  final String id;
  final String identifier;
  final String role;
  final bool isActive;
  final bool emailVerified;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? bio;

  const BackendUserProfile({
    required this.id,
    required this.identifier,
    required this.role,
    required this.isActive,
    required this.emailVerified,
    this.displayName,
    this.firstName,
    this.lastName,
    this.bio,
  });

  factory BackendUserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return BackendUserProfile(
      id: json['id'] as String,
      identifier: json['identifier'] as String,
      role: json['role'] as String? ?? 'USER',
      isActive: json['isActive'] as bool? ?? true,
      emailVerified: json['emailVerified'] as bool? ?? false,
      displayName: profile?['displayName'] as String?,
      firstName: profile?['firstName'] as String?,
      lastName: profile?['lastName'] as String?,
      bio: profile?['bio'] as String?,
    );
  }
}