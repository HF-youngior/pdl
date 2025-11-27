import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class CheckinService {
  static String get baseUrl => ApiService.baseUrl;

  // 获取用户积分
  static Future<int> getUserPoints(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checkin/points?userId=$userId'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['points'] ?? 0;
      } else if (response.statusCode == 404) {
        // 如果404，返回0而不是抛出异常（可能是用户没有积分记录）
        return 0;
      } else {
        throw Exception('获取积分失败: ${response.statusCode}');
      }
    } catch (e) {
      // 如果是404错误，返回0而不是抛出异常
      if (e.toString().contains('404')) {
        return 0;
      }
      throw Exception('获取积分失败: $e');
    }
  }

  // 获取签到记录（按月）
  static Future<Map<String, bool>> getCheckinRecords(String userId, int year, int month) async {
    try {
      final url = Uri.parse('$baseUrl/checkin/records?userId=$userId&year=$year&month=$month');
      print('获取签到记录: $url'); // 调试信息
      
      final response = await http.get(
        url,
        headers: ApiService.getAuthHeaders(),
      );

      print('签到记录响应状态: ${response.statusCode}'); // 调试信息
      
      // 先检查状态码
      if (response.statusCode == 404) {
        // 404时返回空记录，而不是抛出异常（可能是没有记录）
        print('获取签到记录: 404，返回空记录');
        return {};
      }

      // 检查响应是否为JSON格式
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // 如果返回的是HTML，可能是认证失败或路由错误
        print('获取签到记录: 非JSON响应，content-type: $contentType');
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return {}; // 客户端错误时返回空记录
        }
        throw Exception('服务器返回了非JSON格式的响应，可能是认证失败或路由错误');
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final records = data['records'] as List? ?? [];
          final Map<String, bool> result = {};
          for (var record in records) {
            final date = record['checkin_date'] as String;
            result[date] = true;
          }
          print('获取签到记录成功: ${result.length} 条记录');
          return result;
        } catch (e) {
          print('解析签到记录JSON失败: $e');
          return {}; // 解析失败时返回空记录
        }
      } else {
        // 其他错误状态码，尝试解析错误消息
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error'] ?? '获取签到记录失败: ${response.statusCode}';
          print('获取签到记录错误: $errorMsg');
          // 对于客户端错误（4xx），返回空记录而不是抛出异常
          if (response.statusCode >= 400 && response.statusCode < 500) {
            return {};
          }
          throw Exception(errorMsg);
        } catch (e) {
          print('解析错误消息失败: $e');
          // 对于客户端错误，返回空记录
          if (response.statusCode >= 400 && response.statusCode < 500) {
            return {};
          }
          throw Exception('获取签到记录失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('获取签到记录异常: $e');
      // 对于404或其他客户端错误，返回空记录
      if (e.toString().contains('404') || 
          e.toString().contains('403') ||
          e.toString().contains('401')) {
        return {};
      }
      // 网络错误或其他错误，也返回空记录以避免页面崩溃
      return {};
    }
  }

  // 每日签到
  static Future<Map<String, dynamic>> checkin(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/checkin');
      print('签到请求: $url, userId: $userId'); // 调试信息
      
      final response = await http.post(
        url,
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'userId': userId}),
      );

      print('签到响应状态: ${response.statusCode}'); // 调试信息

      // 先检查状态码
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('认证失败，请重新登录');
      }

      // 检查响应是否为JSON格式
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // 如果返回的是HTML，可能是认证失败或路由错误
        print('签到响应: 非JSON格式，content-type: $contentType');
        print('响应体前100字符: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}');
        
        if (response.statusCode == 404) {
          throw Exception('签到接口不存在，请联系管理员');
        } else if (response.body.trim().startsWith('<!DOCTYPE') || 
                   response.body.trim().startsWith('<html>')) {
          throw Exception('服务器返回了HTML页面，可能是认证失败或路由错误。请检查服务器配置和认证token');
        } else {
          throw Exception('服务器返回了非JSON格式的响应，可能是认证失败或路由错误');
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final result = json.decode(response.body);
          print('签到成功: $result');
          return result;
        } catch (e) {
          print('解析签到响应JSON失败: $e, 响应体: ${response.body}');
          throw Exception('解析服务器响应失败: $e');
        }
      } else {
        // 尝试解析错误消息
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error'] ?? '签到失败: ${response.statusCode}';
          print('签到错误: $errorMsg');
          throw Exception(errorMsg);
        } catch (e) {
          // 如果解析失败，检查是否是HTML响应
          if (response.body.trim().startsWith('<!DOCTYPE') || 
              response.body.trim().startsWith('<html>')) {
            throw Exception('服务器返回了HTML页面，可能是认证失败或路由错误。请检查服务器配置和认证token');
          }
          final errorPreview = response.body.length > 100 
              ? response.body.substring(0, 100) 
              : response.body;
          print('签到失败，无法解析错误消息: $errorPreview');
          throw Exception('签到失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('签到异常: $e');
      // 重新抛出异常，但提供更友好的错误信息
      if (e.toString().contains('FormatException')) {
        throw Exception('服务器响应格式错误，可能是认证失败或路由错误。请检查服务器配置和认证token');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('签到失败: $e');
    }
  }

  // 获取连续签到天数
  static Future<int> getConsecutiveDays(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checkin/consecutive?userId=$userId'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['consecutiveDays'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }
}

