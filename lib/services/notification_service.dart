import 'dart:convert';

import '../models/deadline_reminder.dart';
import '../models/notification.dart' show TaskNotification;
import 'api_service.dart';

class NotificationService {
  static Future<List<DeadlineReminder>> triggerDeadlineReminders({int hoursBefore = 24}) async {
    final client = ApiService.httpClient;
    final response = await client.post(
      Uri.parse('${ApiService.baseUrl}/notifications/deadline-reminders'),
      headers: ApiService.getAuthHeaders(),
      body: jsonEncode({'hoursBefore': hoursBefore}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> remindersJson = data['reminders'] as List<dynamic>? ?? const [];
      return remindersJson
          .map((item) => DeadlineReminder.fromJson(item as Map<String, dynamic>))
          .where((reminder) => reminder.notificationId.isNotEmpty && reminder.taskId.isNotEmpty)
          .toList();
    }

    throw Exception('触发截止时间提醒失败: ${response.statusCode} ${response.body}');
  }

  /// 获取所有通知
  static Future<List<TaskNotification>> getNotifications() async {
    try {
      final client = ApiService.httpClient;
      final response = await client.get(
        Uri.parse('${ApiService.baseUrl}/notifications'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => TaskNotification.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('获取通知失败: $e');
      return [];
    }
  }

  /// 标记通知为已读
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final client = ApiService.httpClient;
      final response = await client.put(
        Uri.parse('${ApiService.baseUrl}/notifications/$notificationId/read'),
        headers: ApiService.getAuthHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('标记通知为已读失败: $e');
      return false;
    }
  }

  /// 删除通知
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final client = ApiService.httpClient;
      final response = await client.delete(
        Uri.parse('${ApiService.baseUrl}/notifications/$notificationId'),
        headers: ApiService.getAuthHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('删除通知失败: $e');
      return false;
    }
  }
}

