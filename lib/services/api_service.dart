import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
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

  // 修改密码
  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? '密码修改成功'};
      } else {
        return {'success': false, 'message': data['error'] ?? '密码修改失败'};
      }
    } catch (e) {
      print('修改密码错误: $e');
      return {'success': false, 'message': '网络错误，请稍后重试'};
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
    String? requestStartTime,
    String? requestEndTime,
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
          'request_start_time': requestStartTime,
          'request_end_time': requestEndTime,
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
    String? requestStartTime,
    String? requestEndTime,
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
          'request_start_time': requestStartTime,
          'request_end_time': requestEndTime,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('更新邀约请求错误: $e');
      rethrow;
    }
  }

  // ==================== 管理员总览 API ====================
  
  // 搜索员工（支持按名字、部门、职位搜索）
  static Future<List<User>> searchUsers(String keyword) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/admin/search-users?keyword=${Uri.encodeComponent(keyword)}'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('搜索员工错误: $e');
      return [];
    }
  }
  
  // 获取员工统计数据
  static Future<Map<String, dynamic>?> getUserStatistics(String userId, String period) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/admin/user-statistics?userId=$userId&period=$period'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('获取员工统计数据错误: $e');
      return null;
    }
  }
  
  // 获取员工日志
  static Future<List<PersonalLog>> getUserLogs(String userId, {String? date}) async {
    try {
      String url = '$baseUrl/admin/user-logs?userId=$userId';
      if (date != null) {
        url += '&date=$date';
      }
      final response = await httpClient.get(
        Uri.parse(url),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PersonalLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('获取员工日志错误: $e');
      return [];
    }
  }
  
  // 获取员工MBTI测试历史
  static Future<List<Map<String, dynamic>>> getUserMbtiHistory(String userId) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/admin/user-mbti-history?userId=$userId'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('获取员工MBTI历史错误: $e');
      return [];
    }
  }
  
  // 获取公司所有任务
  static Future<List<Task>> getAllCompanyTasks({String? date}) async {
    try {
      String url = '$baseUrl/admin/all-tasks';
      if (date != null) {
        url += '?date=$date';
      }
      final response = await httpClient.get(
        Uri.parse(url),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('获取公司所有任务错误: $e');
      return [];
    }
  }
  
  // 获取任务树
  static Future<Map<String, dynamic>?> getTaskTree(String taskId) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/admin/task-tree?taskId=$taskId'),
        headers: getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('获取任务树错误: $e');
      return null;
    }
  }
  
  // 数据埋点
  static Future<bool> trackAction(String action, {String? category, Map<String, dynamic>? metadata}) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/admin/tracking'),
        headers: getAuthHeaders(),
        body: jsonEncode({
          'action': action,
          'category': category ?? 'admin_action',
          'metadata': metadata,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('数据埋点错误: $e');
      return false;
    }
  }

  // 上传单张图片
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/upload-image');
      final request = http.MultipartRequest('POST', uri);
      
      // 添加认证头
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      
      // 添加图片文件
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final filename = path.basename(imageFile.path);
      final mimeType = lookupMimeType(filename) ?? 'image/jpeg';
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);
      
      // 发送请求
      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 返回完整URL（包含服务器地址）
        final imageUrl = data['url'] as String;
        // 构建完整URL：baseUrl格式是 http://host:port/api，需要去掉/api
        final baseUrlWithoutApi = baseUrl.replaceAll('/api', '');
        final fullUrl = baseUrlWithoutApi + imageUrl;
        print('图片上传成功，URL: $fullUrl');
        return fullUrl;
      } else {
        print('图片上传失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('图片上传错误: $e');
      return null;
    }
  }

  // 批量上传图片
  static Future<List<String>> uploadImages(List<File> imageFiles) async {
    try {
      if (imageFiles.isEmpty) {
        return [];
      }

      final uri = Uri.parse('$baseUrl/upload-images');
      final request = http.MultipartRequest('POST', uri);
      
      // 添加认证头
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      
      // 添加所有图片文件
      for (var imageFile in imageFiles) {
        // 检查文件是否存在
        if (!await imageFile.exists()) {
          throw Exception('图片文件不存在: ${imageFile.path}');
        }

        final fileStream = http.ByteStream(imageFile.openRead());
        final fileLength = await imageFile.length();
        
        // 使用跨平台的路径处理来提取文件名
        final filename = path.basename(imageFile.path);
        
        // 根据文件扩展名确定MIME类型
        final mimeType = lookupMimeType(filename) ?? 'image/jpeg';
        
        final multipartFile = http.MultipartFile(
          'images',
          fileStream,
          fileLength,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        );
        request.files.add(multipartFile);
      }
      
      // 发送请求
      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['images'] != null) {
          final images = data['images'] as List;
          // 构建完整URL：baseUrl格式是 http://host:port/api，需要去掉/api
          final baseUrlWithoutApi = baseUrl.replaceAll('/api', '');
          final urls = images.map((img) {
            final url = baseUrlWithoutApi + (img['url'] as String);
            print('图片上传成功，URL: $url');
            return url;
          }).toList().cast<String>();
          
          if (urls.length != imageFiles.length) {
            throw Exception('上传的图片数量不匹配：期望 ${imageFiles.length} 张，实际返回 ${urls.length} 张');
          }
          
          return urls;
        } else {
          throw Exception('服务器返回格式错误: ${response.body}');
        }
      } else {
        final errorBody = response.body;
        print('批量图片上传失败: ${response.statusCode} - $errorBody');
        throw Exception('图片上传失败 (${response.statusCode}): ${errorBody.length > 100 ? errorBody.substring(0, 100) : errorBody}');
      }
    } catch (e) {
      print('批量图片上传错误: $e');
      // 重新抛出异常，让调用者能够看到具体的错误信息
      if (e is Exception) {
        rethrow;
      }
      throw Exception('图片上传失败: $e');
    }
  }
}
