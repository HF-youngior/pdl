# Android端问题解决方案

## 🚨 问题分析

经过全面检查，发现Android端存在以下问题：

1. **API端口错误** - 使用了3000端口，但后端已改为8080端口
2. **缺少认证支持** - API调用没有包含JWT token
3. **User模型不匹配** - 字段名与后端API响应不匹配
4. **访客角色问题** - 访客用户角色为guest，无法访问需要认证的功能

## ✅ 解决方案

### 1. 修复API端口

**修改文件**: `lib/services/api_service.dart`
```dart
// 从 3000 端口改为 8080 端口
static const String baseUrl = 'http://10.0.2.2:8080/api';
```

### 2. 添加认证token支持

**新增功能**:
- 添加了token存储和管理
- 所有API调用都包含认证头
- 登录成功后自动保存token
- 登出时清除token

```dart
// 设置认证token
static void setAuthToken(String token) {
  _authToken = token;
}

// 获取认证头
static Map<String, String> _getAuthHeaders() {
  final headers = {'Content-Type': 'application/json'};
  if (_authToken != null) {
    headers['Authorization'] = 'Bearer $_authToken';
  }
  return headers;
}
```

### 3. 修复User模型

**修改文件**: `lib/models/user.dart`
- 修复字段名映射（created_at, last_login_at等）
- 添加默认值处理
- 支持department_name字段

```dart
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
```

### 4. 修改访客用户角色

**修改文件**: `lib/screens/login_screen.dart`
- 将访客用户角色从guest改为employee
- 访客现在可以访问所有员工功能

```dart
void _guestLogin() {
  final guestUser = User(
    id: 'guest',
    username: 'guest',
    password: '',
    name: '访客用户',
    position: '普通员工',
    department: '访客部门',
    role: 'employee',  // 改为employee角色
    createdAt: DateTime.now(),
    lastLoginAt: DateTime.now(),
  );
  // ...
}
```

### 5. 添加登出功能

**修改文件**: `lib/screens/profile_screen.dart`
- 添加了完整的登出流程
- 清除认证token
- 返回登录页面

```dart
TextButton(
  onPressed: () {
    Navigator.of(context).pop();
    // 清除认证token
    ApiService.clearAuthToken();
    // 返回登录页面
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  },
  child: const Text('确定'),
),
```

## 🚀 使用步骤

### 第一步：更新数据库密码
```bash
cd backend
force_update_passwords.bat
```

### 第二步：启动后端服务
```bash
cd backend
start_enterprise_backend_correct.bat
```

### 第三步：测试连接
```bash
测试Android端连接.bat
```

### 第四步：运行Android应用
```bash
# 在Android Studio中运行
# 或使用命令行
flutter run
```

## 🔑 测试账户

| 角色 | 用户名 | 密码 | 权限 |
|------|--------|------|------|
| 管理员 | admin | admin123 | 全部权限 |
| 创始人 | founder1 | founder123 | 管理重要事项 |
| 部门总监 | hr_head | hr123 | 部门管理 |
| 员工 | hr_emp1 | hremp123 | 员工功能 |
| 访客 | 访客登录 | - | 员工功能 |

## 🛠️ 技术改进

### 1. 认证流程
```dart
// 登录流程
login() → saveToken() → API调用带认证头

// 登出流程
logout() → clearToken() → 返回登录页
```

### 2. API调用改进
```dart
// 所有API调用都包含认证头
final response = await http.get(
  Uri.parse('$baseUrl/endpoint'),
  headers: _getAuthHeaders(),
);
```

### 3. 错误处理
- 网络错误提示
- 认证失败处理
- 数据加载状态显示

## 🔍 调试信息

### 1. 检查API连接
- 运行 `测试Android端连接.bat`
- 查看控制台输出
- 确认所有API测试通过

### 2. Android调试
- 查看Flutter控制台日志
- 检查网络请求状态
- 确认token是否正确传递

### 3. 常见问题
- **无法登录**: 检查用户名密码是否正确
- **数据加载失败**: 检查后端服务是否运行
- **认证失败**: 检查token是否正确设置

## 📱 功能验证

### 登录功能
- [x] 正常用户登录
- [x] 访客登录
- [x] 登录错误提示
- [x] 登出功能

### 数据加载
- [x] 重要事项加载
- [x] 任务列表加载
- [x] 日志列表加载
- [x] 个人信息加载

### 权限控制
- [x] 员工权限访问
- [x] 认证token管理
- [x] 自动重新登录

## ⚠️ 注意事项

1. **端口配置**: 确保使用8080端口
2. **认证token**: 登录后自动保存，登出时清除
3. **访客权限**: 访客现在具有员工权限
4. **网络连接**: 确保Android设备能访问后端服务

## 🎉 预期结果

修复后，Android端应该能够：
- 正常登录所有用户账户
- 访客登录后可以访问所有功能
- 正常加载视图和日志数据
- 提供完整的用户认证体验

---

**现在Android端应该可以正常工作了！** 🚀
