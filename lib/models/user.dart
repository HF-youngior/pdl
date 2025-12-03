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
  final int points; // 积分
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int focusDuration; // 番茄钟累计专注秒数

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
    this.points = 0,
    required this.createdAt,
    this.lastLoginAt,
    this.focusDuration = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    int parseFocusDuration(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

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
      points: json['points'] != null ? (json['points'] is int ? json['points'] : int.tryParse(json['points'].toString()) ?? 0) : 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      focusDuration: parseFocusDuration(json['focus_duration']),
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
      'points': points,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'focus_duration': focusDuration,
    };
  }
}
