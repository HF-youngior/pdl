import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/important_item.dart';
import '../models/task.dart';
import '../models/personal_info.dart';
import '../models/log.dart';
import '../models/personal_log.dart';
import 'task_service.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080/api';
  static String? _authToken;
  
  // 设置认证token
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  // 清除认证token
  static void clearAuthToken() {
    _authToken = null;
  }
  
  // 获取认证头
  static Map<String, String> _getAuthHeaders() {
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

  // 获取公司重要事项
  static Future<List<ImportantItem>> getImportantItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/important-items'),
        headers: _getAuthHeaders(),
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

  // 获取任务派发
  static Future<List<Task>> getTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: _getAuthHeaders(),
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
        headers: _getAuthHeaders(),
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
        headers: _getAuthHeaders(),
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
        headers: _getAuthHeaders(),
        body: jsonEncode(log.toJson()),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('创建日志错误: $e');
      return false;
    }
  }

  // 新增：创建个人日志（新结构，包含多任务关联）
  static Future<bool> createPersonalLog(PersonalLog log) async {
    try {
      final payload = {
        'log': log.toJson()
          ..remove('created_at')
          ..remove('updated_at'),
        'linkages': log.linkages.map((e) => e.toJson()).toList(),
      };
      final response = await http.post(
        Uri.parse('$baseUrl/personal-logs'),
        headers: _getAuthHeaders(),
        body: jsonEncode(payload),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('创建个人日志错误: $e');
      return false;
    }
  }

  // 新增：获取个人日志（包含关联）
  static Future<List<PersonalLog>> getPersonalLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/personal-logs'),
        headers: _getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => PersonalLog.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('获取个人日志错误: $e');
      return [];
    }
  }
}
