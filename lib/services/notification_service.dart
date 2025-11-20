import 'dart:convert';

import '../models/deadline_reminder.dart';
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
}

