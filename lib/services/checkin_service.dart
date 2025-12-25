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
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['points'] ?? 0;
      } else if (response.statusCode == 404) {
        // 如果404，返回0而不是抛出异常（可能是用户没有积分记录）
        return 0;
      } else {
        return 0; // 失败时返回0，不抛出异常
      }
    } catch (e) {
      // 任何错误都返回0，避免阻塞页面
      return 0;
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
      final response = await http.get(
        url,
        headers: ApiService.getAuthHeaders(),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List? ?? [];
        final Map<String, bool> result = {};
        for (var record in records) {
          final date = record['checkin_date'] as String;
          result[date] = true;
        }
        return result;
      } else {
        // 任何错误都返回空记录，避免页面崩溃
        return {};
      }
    } catch (e) {
      // 任何错误都返回空记录，避免页面崩溃
      return {};
    }
  }

  // 每日签到
  static Future<Map<String, dynamic>> checkin(String userId) async {
    try {
      final baseUrlValue = baseUrl;
      if (baseUrlValue.isEmpty || !baseUrlValue.contains('http')) {
        throw Exception('服务器地址未配置，请在设置中配置服务器地址');
      }
      
      final url = Uri.parse('$baseUrlValue/checkin');
      final response = await http.post(
        url,
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'userId': userId}),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('请求超时，请检查网络连接');
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('认证失败，请重新登录');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        return result;
      } else {
        // 尝试解析错误消息
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error'] ?? '签到失败: ${response.statusCode}';
          throw Exception(errorMsg);
        } catch (e) {
          throw Exception('签到失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Connection refused')) {
        throw Exception('网络连接失败，请检查网络连接');
      }
      
      if (errorStr.contains('TimeoutException') || errorStr.contains('请求超时')) {
        throw Exception('请求超时，请检查网络连接');
      }
      
      if (e is Exception) {
        rethrow;
      }
      
      throw Exception('签到失败: $errorStr');
    }
  }

  // 获取连续签到天数
  static Future<int> getConsecutiveDays(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checkin/consecutive?userId=$userId'),
        headers: ApiService.getAuthHeaders(),
      ).timeout(const Duration(seconds: 3));

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

  // 获取服务器当前日期（北京时间）
  static Future<Map<String, dynamic>> getServerToday() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checkin/today'),
        headers: ApiService.getAuthHeaders(),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'today': data['today'] as String,
          'year': data['year'] as int,
          'month': data['month'] as int,
          'day': data['day'] as int,
        };
      } else {
        // 失败时返回本地日期作为fallback
        final now = DateTime.now();
        return {
          'today': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'year': now.year,
          'month': now.month,
          'day': now.day,
        };
      }
    } catch (e) {
      // 失败时返回本地日期作为fallback
      final now = DateTime.now();
      return {
        'today': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'year': now.year,
        'month': now.month,
        'day': now.day,
      };
    }
  }
}

