class TaskNotification {
  final String id;
  final String taskId;
  final String fromUserId;
  final String toUserId;
  final String notificationType;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? taskTitle;
  final String? fromUserName;

  TaskNotification({
    required this.id,
    required this.taskId,
    required this.fromUserId,
    required this.toUserId,
    required this.notificationType,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.taskTitle,
    this.fromUserName,
  });

  factory TaskNotification.fromJson(Map<String, dynamic> json) {
    return TaskNotification(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? _parseBeijingTime(json['created_at'].toString())
          : DateTime.now(),
      taskTitle: json['task_title']?.toString(),
      fromUserName: json['from_user_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'notification_type': notificationType,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'task_title': taskTitle,
      'from_user_name': fromUserName,
    };
  }

  /// 解析北京时间字符串，确保日期正确
  /// 后端返回格式：YYYY-MM-DDTHH:mm:ss+08:00
  static DateTime _parseBeijingTime(String timeStr) {
    try {
      // 如果包含时区信息（+08:00 或 Z）
      if (timeStr.contains('+') || timeStr.endsWith('Z')) {
        // 解析为UTC时间
        final parsed = DateTime.parse(timeStr);
        // 如果是UTC时间（Z结尾），转换为北京时间（+8小时）
        if (timeStr.endsWith('Z')) {
          return parsed.add(const Duration(hours: 8));
        }
        // 如果包含+08:00，DateTime.parse已经正确处理，但需要确保日期正确
        // 提取日期部分，避免时区转换导致的日期偏移
        final dateMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(timeStr);
        if (dateMatch != null) {
          final year = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final day = int.parse(dateMatch.group(3)!);
          // 提取时间部分
          final timeMatch = RegExp(r'T(\d{2}):(\d{2}):(\d{2})').firstMatch(timeStr);
          if (timeMatch != null) {
            final hour = int.parse(timeMatch.group(1)!);
            final minute = int.parse(timeMatch.group(2)!);
            final second = int.parse(timeMatch.group(3)!);
            // 创建北京时间（本地时间，不包含时区信息）
            return DateTime(year, month, day, hour, minute, second);
          }
        }
        return parsed;
      } else {
        // 没有时区信息，直接解析
        return DateTime.parse(timeStr);
      }
    } catch (e) {
      // 解析失败，返回当前时间
      return DateTime.now();
    }
  }
}

