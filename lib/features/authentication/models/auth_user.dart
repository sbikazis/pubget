final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.emailVerified = true,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool emailVerified;
}
