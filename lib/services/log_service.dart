import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/log.dart';
import '../models/task.dart';
import '../utils/config.dart';

class LogService {
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

  // 获取日志列表（支持关键词搜索和状态筛选）
  static Future<List<Log>> fetchLogs({
    String? searchKeyword,
    String? category,
    String? status, // 状态筛选：all, pending, completed (基于isCompleted字段)
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      // 添加搜索关键词参数
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        queryParams['search_keyword'] = searchKeyword;
      }

      // 添加分类筛选参数
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }

      // 添加状态筛选参数（基于isCompleted字段）
      if (status != null && status.isNotEmpty && status != 'all') {
        // 将前端的状态筛选转换为后端的isCompleted参数
        if (status == 'completed') {
          queryParams['is_completed'] = '1'; // 已完成
        } else if (status == 'pending') {
          queryParams['is_completed'] = '0'; // 待处理
        }
      }

      final uri = Uri.parse('${Config.baseUrl}${Config.logsEndpoint}')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getAuthHeaders(),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Log.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('认证失败，请重新登录');
      } else {
        throw Exception('获取日志失败: ${response.statusCode}');
      }
    } catch (e) {
      print('LogService.fetchLogs错误: $e');
      rethrow;
    }
  }

  // TODO: 后端API实现后，取消注释并实现以下方法
  
  /*
  ========================================
  后端API实现说明：
  ========================================
  
  1. GET /api/logs - 获取日志列表
     支持查询参数：
     - search_keyword: 搜索关键词（字符串）
     - category: 分类筛选（字符串）
     - is_completed: 完成状态筛选（0=待处理, 1=已完成）
     - page: 页码（数字）
     - pageSize: 每页数量（数字）
     
     返回格式：
     [
       {
         "id": "日志ID",
         "user_id": "用户ID", 
         "user_name": "用户名",
         "action": "日志标题",
         "description": "日志描述",
         "category": "分类",
         "quadrant": "四象限",
         "is_completed": 0, // 0=未完成, 1=已完成
         "created_at": "2024-01-01T00:00:00Z",
         "metadata": {
           "weather": "sunny", // 天气选择
           "keywords": ["关键词1", "关键词2"]
         },
         "related_task_id": "关联任务ID"
       }
     ]
  
  2. POST /api/logs - 创建日志
     请求体：上述JSON格式的日志对象
     返回：201状态码表示成功
     
  3. PUT /api/logs/:id - 更新日志
     请求体：上述JSON格式的日志对象
     返回：200状态码表示成功
     
  4. DELETE /api/logs/:id - 删除日志
     返回：200状态码表示成功
  ========================================
  
  // 获取个人日志（支持状态筛选，基于isCompleted字段）
  static Future<List<Log>> fetchPersonalLogs({
    String? searchKeyword,
    String? category,
    String? status, // 状态筛选：all, pending, completed (基于isCompleted字段)
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        queryParams['search_keyword'] = searchKeyword;
      }

      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }

      // 添加状态筛选参数（基于isCompleted字段）
      if (status != null && status.isNotEmpty && status != 'all') {
        // 将前端的状态筛选转换为后端的isCompleted参数
        if (status == 'completed') {
          queryParams['is_completed'] = '1'; // 已完成
        } else if (status == 'pending') {
          queryParams['is_completed'] = '0'; // 待处理
        }
      }

      final uri = Uri.parse('${Config.baseUrl}/api/personal-logs')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getAuthHeaders(),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Log.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('认证失败，请重新登录');
      } else {
        throw Exception('获取个人日志失败: ${response.statusCode}');
      }
    } catch (e) {
      print('LogService.fetchPersonalLogs错误: $e');
      rethrow;
    }
  }
  */

  // 创建日志
  static Future<bool> createLog(Log log) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}${Config.logsEndpoint}'),
        headers: _getAuthHeaders(),
        body: json.encode(log.toJson()),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      return response.statusCode == 201;
    } catch (e) {
      print('LogService.createLog错误: $e');
      return false;
    }
  }

  // 更新日志
  static Future<bool> updateLog(String logId, Log log) async {
    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}${Config.logsEndpoint}/$logId'),
        headers: _getAuthHeaders(),
        body: json.encode(log.toJson()),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('LogService.updateLog错误: $e');
      return false;
    }
  }

  // 删除日志
  static Future<bool> deleteLog(String logId) async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}${Config.logsEndpoint}/$logId'),
        headers: _getAuthHeaders(),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      return response.statusCode == 200;
    } catch (e) {
      print('LogService.deleteLog错误: $e');
      return false;
    }
  }

  // 获取日志统计信息
  static Future<Map<String, int>> getLogStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}${Config.logsEndpoint}/statistics'),
        headers: _getAuthHeaders(),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Map<String, int>.from(data);
      } else {
        throw Exception('获取日志统计失败: ${response.statusCode}');
      }
    } catch (e) {
      print('LogService.getLogStatistics错误: $e');
      return {};
    }
  }

  // 获取关联任务列表（用于日志关联显示）
  static Future<List<Task>> fetchRelatedTasks(String logId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}${Config.logsEndpoint}/$logId/tasks'),
        headers: _getAuthHeaders(),
      ).timeout(const Duration(milliseconds: Config.requestTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('LogService.fetchRelatedTasks错误: $e');
      return [];
    }
  }
}
