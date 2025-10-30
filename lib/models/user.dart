class User {
  final String id;
  final String username;
  final String password;
  final String name;
  final String position;
  final String department;
  final String? departmentId; // 添加 department_id 字段
  final String role;
  final String? parentId; // 上级ID，用于判断层级关系
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.position,
    required this.department,
    this.departmentId,
    required this.role,
    this.parentId,
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
      departmentId: json['department_id'],
      role: json['role'] ?? 'employee',
      parentId: json['parent_id'],
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
