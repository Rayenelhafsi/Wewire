import 'dart:convert';

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
    role: UserRole.values.firstWhere(
      (e) => e.toString() == 'UserRole.${json['role']}',
      orElse: () => UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.operator,
      ),
    ),
    createdAt: DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
  };

  String toJsonString() {
    return '{"id":"$id","name":"$name","email":"$email","role":"${role.name}","createdAt":"${createdAt.toIso8601String()}"}';
  }

  factory User.fromJsonString(String jsonString) {
    final json = Map<String, dynamic>.from(jsonDecode(jsonString));
    return User.fromJson(json);
  }
}

enum UserRole {
  operator('operator'),
  qualityAgent('qualityAgent'),
  maintenanceService('maintenanceService'),
  admin('admin');

  final String name;
  const UserRole(this.name);
}
