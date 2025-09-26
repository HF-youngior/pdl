class Log {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String description;
  final String category;
  final String quadrant;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final String? relatedTaskId;

  Log({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.description,
    required this.category,
    required this.quadrant,
    required this.createdAt,
    this.metadata,
    this.relatedTaskId,
  });

  factory Log.fromJson(Map<String, dynamic> json) {
    return Log(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: json['user_name'] ?? json['userName'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      quadrant: json['quadrant'] ?? 'important_not_urgent',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      metadata: json['metadata'],
      relatedTaskId: json['related_task_id'] ?? json['relatedTaskId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'description': description,
      'category': category,
      'quadrant': quadrant,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
      'relatedTaskId': relatedTaskId,
      // 后端期望的字段名
      'user_id': userId,
      'user_name': userName,
      'related_task_id': relatedTaskId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
