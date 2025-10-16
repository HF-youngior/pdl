class LogTaskLinkage {
  final String taskId;
  final int progressPercentage;
  final String taskStatus;

  LogTaskLinkage({
    required this.taskId,
    required this.progressPercentage,
    required this.taskStatus,
  });

  factory LogTaskLinkage.fromJson(Map<String, dynamic> json) {
    return LogTaskLinkage(
      taskId: json['task_id'] ?? json['taskId'] ?? '',
      progressPercentage: json['progress_percentage'] ?? json['progressPercentage'] ?? 0,
      taskStatus: json['task_status'] ?? json['taskStatus'] ?? 'in_progress',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'progress_percentage': progressPercentage,
      'task_status': taskStatus,
    };
  }
}

class PersonalLog {
  final String logId;
  final String userId;
  final DateTime logDate;
  final String weather;
  final List<String> keywords;
  final String logTitle;
  final String? logContent;
  final String category;
  final String quadrant;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<LogTaskLinkage> linkages;

  PersonalLog({
    required this.logId,
    required this.userId,
    required this.logDate,
    required this.weather,
    required this.keywords,
    required this.logTitle,
    this.logContent,
    required this.category,
    required this.quadrant,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
    this.linkages = const [],
  });

  factory PersonalLog.fromJson(Map<String, dynamic> json) {
    final rawKeywords = (json['keywords'] ?? json['keywordsCsv'])?.toString() ?? '';
    return PersonalLog(
      logId: json['log_id'] ?? json['logId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      logDate: DateTime.parse(json['log_date'] ?? json['logDate'] ?? DateTime.now().toIso8601String()),
      weather: json['weather'] ?? 'sunny',
      keywords: rawKeywords.isEmpty ? [] : rawKeywords.split(',').map((e) => e.trim()).toList(),
      logTitle: json['log_title'] ?? json['logTitle'] ?? '个人日志',
      logContent: json['log_content'] ?? json['logContent'],
      category: json['category'] ?? 'work',
      quadrant: json['quadrant'] ?? 'important_not_urgent',
      isArchived: (json['is_archived'] ?? json['isArchived'] ?? false) == true || (json['is_archived'] == 1),
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      linkages: (json['linkages'] as List<dynamic>? ?? [])
          .map((e) => LogTaskLinkage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'user_id': userId,
      'log_date': '${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}',
      'weather': weather,
      'keywords': keywords.join(','),
      'log_title': logTitle,
      'log_content': logContent,
      'category': category,
      'quadrant': quadrant,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'linkages': linkages.map((e) => e.toJson()).toList(),
    };
  }
}


