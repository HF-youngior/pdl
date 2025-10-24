import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'api_service.dart';

class TaskService {
  static String get baseUrl => ApiService.baseUrl;
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

  // 获取所有任务
  static Future<List<Task>> getTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('API响应数据: $data'); // 调试信息
        return data.map((json) {
          try {
            print('解析任务数据: $json'); // 调试信息
            return Task.fromJson(json);
          } catch (e) {
            print('解析单个任务失败: $e, 数据: $json'); // 调试信息
            rethrow;
          }
        }).toList();
      } else {
        throw Exception('获取任务失败: ${response.statusCode}');
      }
    } catch (e) {
      print('TaskService错误: $e'); // 调试信息
      throw Exception('获取任务失败: $e');
    }
  }

  // 根据日期范围获取任务
  static Future<List<Task>> getTasksByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks?startDate=${startDate.toIso8601String()}&endDate=${endDate.toIso8601String()}'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('获取任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取任务失败: $e');
    }
  }

  // 创建任务
  static Future<Task> createTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: _getAuthHeaders(),
        body: json.encode(task.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('创建任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('创建任务失败: $e');
    }
  }

  // 更新任务
  static Future<Task> updateTask(String id, Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: _getAuthHeaders(),
        body: json.encode(task.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('更新任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('更新任务失败: $e');
    }
  }

  // 删除任务
  static Future<void> deleteTask(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('删除任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('删除任务失败: $e');
    }
  }

  // 获取任务详情
  static Future<Task> getTaskById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('获取任务详情失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取任务详情失败: $e');
    }
  }

  // 获取指定日期的任务
  static Future<List<Task>> getTasksByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return getTasksByDateRange(startOfDay, endOfDay);
  }

  // 获取指定月份的任务
  static Future<List<Task>> getTasksByMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getTasksByDateRange(startOfMonth, endOfMonth);
  }

  // 获取指定周的任务
  static Future<List<Task>> getTasksByWeek(DateTime weekStart) async {
    final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return getTasksByDateRange(startOfWeek, endOfWeek);
  }
}
