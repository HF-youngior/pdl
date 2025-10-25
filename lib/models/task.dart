import 'package:flutter/material.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String assigneeId;
  final String assigneeName;
  final String department;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime? deadline;
  final String createdBy;
  // 新增字段支持日历视图
  final DateTime startTime;
  final DateTime endTime;
  final String color;
  final String? location;
  final bool isAllDay;
  final int progressPercentage;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.assigneeName,
    required this.department,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.deadline,
    required this.createdBy,
    required this.startTime,
    required this.endTime,
    this.color = '#4CAF50',
    this.location,
    this.isAllDay = false,
    this.progressPercentage = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assigneeId: json['assignee_id'] ?? json['assigneeId'] ?? '',
      assigneeName: json['assignee_name'] ?? json['assigneeName'] ?? '',
      department: json['department'] ?? '',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      createdBy: json['created_by'] ?? json['createdBy'] ?? '',
      startTime: json['start_time'] != null 
          ? DateTime.parse(json['start_time'])
          : (json['startTime'] != null ? DateTime.parse(json['startTime']) : DateTime.now()),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'])
          : (json['endTime'] != null ? DateTime.parse(json['endTime']) : DateTime.now()),
      color: json['color'] ?? '#4CAF50',
      location: json['location']?.toString(),
      isAllDay: (json['is_all_day'] ?? json['isAllDay'] ?? 0) == 1,
      progressPercentage: json['progress_percentage'] ?? json['progressPercentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'department': department,
      'priority': priority,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'createdBy': createdBy,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'color': color,
      'location': location,
      'isAllDay': isAllDay,
      'is_all_day': isAllDay, // 后端期望的字段名
      'progressPercentage': progressPercentage,
      'progress_percentage': progressPercentage, // 后端期望的字段名
      // 添加更多后端可能期望的字段
      'assignee_id': assigneeId,
      'assignee_name': assigneeName,
      'created_at': createdAt.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // 获取优先级颜色
  Color getPriorityColor() {
    switch (priority) {
      case 'p0':
        return Colors.red; // P0 - 最高优先级 (红色)
      case 'p1':
        return Colors.amber.shade700; // P1 - 高优先级 (橙黄色)
      case 'p2':
        return Colors.blue.shade700; // P2 - 中优先级 (蓝色)
      case 'p3':
        return Colors.green.shade700; // P3 - 低优先级 (绿色)
      default:
        return Colors.grey;
    }
  }

  // 获取优先级标签
  String getPriorityLabel() {
    return priority.toUpperCase();
  }

  // 获取状态颜色
  Color getStatusColor() {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 获取状态文本
  String getStatusText() {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  // 检查任务是否过期
  bool get isOverdue {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!) && status != 'completed';
  }

  // 检查任务是否今天到期
  bool get isDueToday {
    if (deadline == null) return false;
    final now = DateTime.now();
    final deadlineDate = deadline!;
    return now.year == deadlineDate.year &&
           now.month == deadlineDate.month &&
           now.day == deadlineDate.day;
  }
}
