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
          ? DateTime.parse(json['created_at'].toString())
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
}

