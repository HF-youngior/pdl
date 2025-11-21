class DeadlineReminder {
  final String notificationId;
  final String taskId;
  final String title;
  final DateTime? deadline;
  final String priority;
  final String status;
  final String message;

  DeadlineReminder({
    required this.notificationId,
    required this.taskId,
    required this.title,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.message,
  });

  factory DeadlineReminder.fromJson(Map<String, dynamic> json) {
    return DeadlineReminder(
      notificationId: json['notification_id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      deadline: json['deadline'] != null && json['deadline'].toString().isNotEmpty
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      priority: json['priority']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

