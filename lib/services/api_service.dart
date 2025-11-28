import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/important_item.dart';
import '../models/task.dart';
import '../models/personal_info.dart';
import '../models/log.dart';
import '../models/personal_log.dart';
import 'task_service.dart';
import 'server_config_service.dart';

class ApiService {
  /// 可注入的 HTTP 客户端，默认使用真实客户端。
  /// 在单元测试中可替换为 MockClient 以控制响应结果。
  static http.Client httpClient = http.Client();

  // 缓存baseUrl，避免频繁读取SharedPreferences
  static String? _cachedBaseUrl;
  static bool _isInitialized = false;
  
  /// 初始化API服务（在应用启动时调用）
  /// 从配置中加载服务器地址
  static Future<void> initialize() async {
    if (!_isInitialized) {
      _cachedBaseUrl = await ServerConfigService.getBaseUrl();
      _isInitialized = true;
      print('API服务已初始化，baseUrl: $_cachedBaseUrl');
    }
  }
  
  /// 获取API基础URL
  /// 支持动态配置，优先使用用户配置的服务器地址
  /// 默认：模拟器使用 10.0.2.2:8080，真机需要配置电脑IP
  /// 注意：首次使用前需要调用 initialize() 方法
  static String get baseUrl {
    if (_cachedBaseUrl == null) {
      // 如果未初始化，使用默认值（向后兼容）
      // 但建议在应用启动时调用 initialize()
      return 'http://10.0.2.2:8080/api';
    }
    return _cachedBaseUrl!;
  }
  
  /// 刷新baseUrl（配置更改后调用）
  static Future<void> refreshBaseUrl() async {
    _cachedBaseUrl = await ServerConfigService.getBaseUrl();
    print('API服务配置已刷新，baseUrl: $_cachedBaseUrl');
  }
  
  /// 清除baseUrl缓存（配置更改后调用）
  static void clearBaseUrlCache() {
    _cachedBaseUrl = null;
    _isInitialized = false;
  }
  
  static String? _authToken;
  
  // 设置认证token
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  // 清除认证token
  static void clearAuthToken() {
    _authToken = null;
  }
  
  // 获取认证token
  static String? getToken() {
    return _authToken;
  }
  
  // 获取认证头（公开方法，供其他服务使用）
  static Map<String, String> getAuthHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }
  
  // 用户认证
  static Future<User?> login(String username, String password) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 保存认证token
        if (data['token'] != null) {
          setAuthToken(data['token']);
          // 同时设置TaskService的token
          TaskService.setAuthToken(data['token']);
        }
        return User.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      print('登录错误: $e');
      return null;
    }
  }

  // 获取公司重要事项（已选择的）
  static Future<List<ImportantItem>> getImportantItems() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/important-items'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ImportantItem.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取重要事项错误: $e');
      return [];
    }
  }

  // 获取所有重要事项（用于编辑）
  static Future<List<ImportantItem>> getAllImportantItems() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/company-important-items/all'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ImportantItem.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取所有重要事项错误: $e');
      return [];
    }
  }

  // 批量更新重要事项选择状态
  static Future<bool> batchUpdateImportantItemsSelection(List<String> selectedIds) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/company-important-items/batch-select'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'selectedIds': selectedIds,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('批量更新重要事项选择状态错误: $e');
      return false;
    }
  }

  // 创建重要事项
  static Future<bool> createImportantItem({
    required String title,
    required String description,
    required String priority,
    DateTime? deadline,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/company-important-items'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'priority': priority,
          'deadline': deadline?.toIso8601String(),
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('创建重要事项错误: $e');
      return false;
    }
  }

  // 更新重要事项
  static Future<bool> updateImportantItem({
    required String id,
    required String title,
    required String description,
    required String priority,
    required String status,
    DateTime? deadline,
  }) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/company-important-items/$id'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'priority': priority,
          'status': status,
          'deadline': deadline?.toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('更新重要事项错误: $e');
      return false;
    }
  }

  // 删除重要事项
  static Future<bool> deleteImportantItem(String id) async {
    try {
      final response = await httpClient.delete(
        Uri.parse('$baseUrl/company-important-items/$id'),
        headers: getAuthHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('删除重要事项错误: $e');
      return false;
    }
  }

  // 获取任务派发
  static Future<List<Task>> getTasks() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/tasks'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Task.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取任务错误: $e');
      return [];
    }
  }

  // 获取个人信息
  static Future<List<PersonalInfo>> getPersonalInfo(String userId) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/personal-info/$userId'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => PersonalInfo.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取个人信息错误: $e');
      return [];
    }
  }

  // 获取日志
  static Future<List<Log>> getLogs() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/logs'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Log.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取日志错误: $e');
      return [];
    }
  }

  // 创建日志
  static Future<bool> createLog(Log log) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/logs'),
        headers: getAuthHeaders(),
        body: jsonEncode(log.toJson()),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('创建日志错误: $e');
      return false;
    }
  }

  // 获取个人日志列表（使用 token 认证，不需要 userId 参数）
  static Future<List<PersonalLog>> getPersonalLogs(String userId) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/personal-logs'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((item) => PersonalLog.fromJson(item)).toList();
      }
      throw Exception('Failed to load personal logs: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  // 创建个人日志（logData 结构: { log: {...}, linkages: [...] }）
  static Future<PersonalLog> createPersonalLog(Map<String, dynamic> logData) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/personal-logs'),
        headers: getAuthHeaders(),
        body: jsonEncode(logData),
      );
      if (response.statusCode == 201) {
        return PersonalLog.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      throw Exception('Failed to create personal log: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  // 更新个人日志
  static Future<PersonalLog> updatePersonalLog(String logId, Map<String, dynamic> logData) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/personal-logs/$logId'),
        headers: getAuthHeaders(),
        body: jsonEncode(logData),
      );
      if (response.statusCode == 200) {
        return PersonalLog.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      throw Exception('Failed to update personal log: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  // 删除个人日志
  static Future<void> deletePersonalLog(String logId) async {
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/personal-logs/$logId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete personal log: ${response.body}');
    }
  }

  // 新增：获取月视图数据
  static Future<Map<String, dynamic>?> getMonthView(int year, int month) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/calendar/month-view?year=$year&month=$month'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('获取月视图数据错误: $e');
      return null;
    }
  }

  // 新增：获取日详情数据
  static Future<Map<String, dynamic>?> getDayDetail(String date) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/calendar/day-detail?date=$date'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('获取日详情数据错误: $e');
      return null;
    }
  }

  // 获取用户列表（根据权限）
  static Future<List<User>> getUsers() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/users'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('获取用户列表错误: $e');
      return [];
    }
  }

  // 累加专注时长
  static Future<int?> addFocusDuration(int durationSeconds) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/user/focus-duration'),
        headers: getAuthHeaders(),
        body: jsonEncode({'duration': durationSeconds}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['totalFocusDuration'] is int
            ? data['totalFocusDuration'] as int
            : int.tryParse(data['totalFocusDuration']?.toString() ?? '');
      }
    } catch (e) {
      print('同步专注时长错误: $e');
    }
    return null;
  }

  // 创建向上邀约请求
  static Future<bool> createRequest({
    required String requestType,
    required String assigneeId,
    required String description,
    String? deadline,
    String? relatedTaskId,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/tasks/request'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'request_type': requestType,
          'assignee_id': assigneeId,
          'description': description,
          'deadline': deadline,
          'related_task_id': relatedTaskId,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('创建邀约请求错误: $e');
      rethrow;
    }
  }

  // 处理邀约请求（批准/反驳）
  static Future<bool> handleRequestResponse({
    required String taskId,
    required String action, // 'approve' 或 'reject'
    String? notes,
  }) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/tasks/$taskId/request-response'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'action': action,
          'notes': notes,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('处理邀约请求错误: $e');
      rethrow;
    }
  }

  // 更新向上邀约请求
  static Future<bool> updateRequest({
    required String taskId,
    required String requestType,
    required String assigneeId,
    required String description,
    String? deadline,
    String? relatedTaskId,
  }) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/tasks/$taskId/request'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'request_type': requestType,
          'assignee_id': assigneeId,
          'description': description,
          'deadline': deadline,
          'related_task_id': relatedTaskId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('更新邀约请求错误: $e');
      rethrow;
    }
  }
}
