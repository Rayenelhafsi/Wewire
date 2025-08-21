class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: UserRole.values.firstWhere((e) => e.toString() == 'UserRole.${json['role']}'),
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
      };
}

enum UserRole {
  operator,
  qualityAgent,
  maintenanceService,
  admin,
}
