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

  /// 兑换积分商城中的奖励（例如 Loopy 装扮）
  /// 返回结果中包含最新积分等信息：
  /// {
  ///   "message": "兑换成功",
  ///   "points": 80
  /// }
  static Future<Map<String, dynamic>> redeemReward({
    required String userId,
    required int cost,
    String? itemName,
  }) async {
    final url = Uri.parse('$baseUrl/checkin/redeem');
    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'cost': cost,
          if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      // 优先尝试解析服务端错误信息
      try {
        final data = json.decode(response.body);
        final msg = data['error'] ?? '兑换失败: ${response.statusCode}';
        throw Exception(msg);
      } catch (_) {
        if (response.statusCode == 400) {
          throw Exception('兑换失败：请求参数错误或积分不足');
        } else if (response.statusCode == 403) {
          throw Exception('兑换失败：没有权限执行该操作');
        }
        throw Exception('兑换失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('兑换失败: $e');
    }
  }

  /// 获取积分记录（获取/消耗）
  /// type: 'earn' | 'spend'
  /// 返回 [{date, amount, description}]
  static Future<List<Map<String, dynamic>>> getPointsHistory({
    required String userId,
    required String type,
    int? year,
    int? month,
  }) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final uri = Uri.parse(
        '$baseUrl/checkin/points-history?userId=$userId&type=$type&year=$y&month=$m');

    final response = await http.get(
      uri,
      headers: ApiService.getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['records'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    }

    try {
      final err = json.decode(response.body);
      final msg = err['error'] ?? '获取积分记录失败: ${response.statusCode}';
      throw Exception(msg);
    } catch (_) {
      throw Exception('获取积分记录失败: ${response.statusCode}');
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
      // 确保 baseUrl 已初始化
      final baseUrlValue = baseUrl;
      if (baseUrlValue.isEmpty || !baseUrlValue.contains('http')) {
        throw Exception('服务器地址未配置，请在设置中配置服务器地址');
      }
      
      final url = Uri.parse('$baseUrlValue/checkin');
      print('签到请求: $url, userId: $userId'); // 调试信息
      print('认证头: ${ApiService.getAuthHeaders()}'); // 调试信息
      
      final response = await http.post(
        url,
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'userId': userId}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('请求超时，请检查网络连接');
        },
      );

      print('签到响应状态: ${response.statusCode}'); // 调试信息
      print('签到响应头: ${response.headers}'); // 调试信息

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
      final errorStr = e.toString();
      
      // 网络连接错误
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('Network is unreachable')) {
        throw Exception('网络连接失败，请检查网络连接和服务器地址配置');
      }
      
      // 超时错误
      if (errorStr.contains('TimeoutException') || errorStr.contains('请求超时')) {
        throw Exception('请求超时，请检查网络连接和服务器是否正常运行');
      }
      
      // 格式错误
      if (errorStr.contains('FormatException')) {
        throw Exception('服务器响应格式错误，可能是认证失败或路由错误。请检查服务器配置和认证token');
      }
      
      // 如果已经是友好的错误消息，直接抛出
      if (e is Exception && !errorStr.contains('Exception: Exception:')) {
        rethrow;
      }
      
      // 其他错误，提供通用错误信息
      throw Exception('签到失败: ${errorStr.replaceAll('Exception: ', '')}');
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

