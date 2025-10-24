import '../models/user.dart';

/// 模拟数据工具类
class MockData {
  /// 创建模拟用户数据
  static User createMockUser() {
    return User(
      id: 'employee-001',
      username: 'hr_emp1',
      password: 'hremp123',
      name: '陈人事专员',
      position: '人事专员',
      department: 'HR Department',
      role: 'employee',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  /// 创建管理员用户
  static User createMockAdmin() {
    return User(
      id: 'admin-001',
      username: 'admin',
      password: 'admin123',
      name: '系统管理员',
      position: '管理员',
      department: 'IT部门',
      role: 'admin',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  /// 创建创始人用户
  static User createMockFounder() {
    return User(
      id: 'founder-001',
      username: 'founder1',
      password: 'founder123',
      name: '张创始人',
      position: '创始人',
      department: 'HR Department',
      role: 'founder',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }
}
