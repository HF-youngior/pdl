class ImportantItem {
  final String id;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String department;
  final DateTime createdAt;
  final DateTime? deadline;
  final String createdBy;

  ImportantItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.department,
    required this.createdAt,
    this.deadline,
    required this.createdBy,
  });

  factory ImportantItem.fromJson(Map<String, dynamic> json) {
    return ImportantItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'p1',
      status: json['status'] ?? 'pending',
      department: json['department'] ?? json['department_name'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      createdBy: json['created_by'] ?? json['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'department': department,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}
