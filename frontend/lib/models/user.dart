class User {
  final String id;
  final String username;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'warden',
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isWarden => role == 'warden';
}
