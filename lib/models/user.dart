class User {
  final String id;
  final String username;
  final String password;
  final String name;
  final String position;
  final String department;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.position,
    required this.department,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      department: json['department'] ?? json['department_name'] ?? '',
      role: json['role'] ?? 'employee',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      lastLoginAt: json['last_login_at'] != null 
          ? DateTime.parse(json['last_login_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'position': position,
      'department': department,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }
}
