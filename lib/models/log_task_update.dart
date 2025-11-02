// lib/models/log_task_update.dart

class LogTaskUpdate {
  final String taskId; // 确认是 String
  final String? taskName; 
  // 匹配后端 `log_task_linkage` 表 和 API
  final int? progress_percentage;
  final String? task_status;

  LogTaskUpdate({
    required this.taskId,
    this.taskName,
    this.progress_percentage,
    this.task_status,
  });

  // 从 JSON 解析 (匹配后端 GET API 返回的 camelCase)
  factory LogTaskUpdate.fromJson(Map<String, dynamic> json) {
    return LogTaskUpdate(
      taskId: json['taskId'].toString(), // 确保是 String
      taskName: json['taskName'] as String?,
      progress_percentage: json['progress_percentage'] as int?,
      task_status: json['task_status'] as String?,
    );
  }

  // 序列化为 JSON (匹配后端 POST/PUT API 的 'linkages' 数组)
  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId, // 发送 snake_case
      'progress_percentage': progress_percentage,
      'task_status': task_status,
    };
  }

  // CopyWith
  LogTaskUpdate copyWith({
    String? taskId,
    String? taskName,
    int? progress_percentage,
    String? task_status,
    bool setProgressToNull = false,
    bool setStatusToNull = false,
  }) {
    return LogTaskUpdate(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      progress_percentage: setProgressToNull ? null : (progress_percentage ?? this.progress_percentage),
      task_status: setStatusToNull ? null : (task_status ?? this.task_status),
    );
  }
}
