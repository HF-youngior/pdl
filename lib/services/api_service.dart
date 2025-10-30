import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/important_item.dart';
import '../models/task.dart';
import '../models/personal_info.dart';
import '../models/log.dart';
import '../models/personal_log.dart';
import 'task_service.dart';

class ApiService {
  // Dynamically resolve host/port for different platforms
  static String get _host {
    if (kIsWeb) return '127.0.0.1';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {
      // Platform not available (e.g., web); fall through
    }
    return '127.0.0.1';
  }

  static const int _port = 8080; // Align with backend currently running on 8080
  static String get baseUrl => 'http://'+_host+':'+_port.toString()+'/api';
  static String? _authToken;
  
  // 设置认证token
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  // 清除认证token
  static void clearAuthToken() {
    _authToken = null;
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
      final response = await http.post(
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
      final response = await http.get(
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
      final response = await http.get(
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
      final response = await http.put(
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
      final response = await http.post(
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
      final response = await http.put(
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
      final response = await http.delete(
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
      final response = await http.get(
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
      final response = await http.get(
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
      final response = await http.get(
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
      final response = await http.post(
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
      final response = await http.get(
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
      final response = await http.post(
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
      final response = await http.put(
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
    final response = await http.delete(
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
      final response = await http.get(
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
      final response = await http.get(
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
}
