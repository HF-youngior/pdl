class PersonalInfo {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final String quadrant;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? relatedTaskId;
  final bool isCompleted;

  PersonalInfo({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.quadrant,
    required this.createdAt,
    this.updatedAt,
    this.relatedTaskId,
    this.isCompleted = false,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['content'] ?? json['description'] ?? '',
      category: json['category'] ?? '',
      quadrant: json['quadrant'] ?? 'important_not_urgent',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
      relatedTaskId: json['related_task_id'] ?? json['relatedTaskId'],
      isCompleted: (json['is_completed'] ?? json['isCompleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'quadrant': quadrant,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'relatedTaskId': relatedTaskId,
      'isCompleted': isCompleted,
      // 后端期望的字段名
      'user_id': userId,
      'content': description,
      'related_task_id': relatedTaskId,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
