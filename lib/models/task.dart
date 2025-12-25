import 'dart:convert';
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
  final DateTime? completedAt; // 完成时间
  final String createdBy;
  // 新增字段支持日历视图
  final DateTime startTime;
  final DateTime endTime;
  final String color;
  final String? location;
  final bool isAllDay;
  final int progressPercentage;
  final String? parentTaskId; // 父任务ID，支持分级派发
  final List<Task>? subtasks; // 子任务列表
  final bool isRequest; // 是否为邀约任务
  final List<String> attachments;
  final String? requestType; // 请求类型
  final String? requestResponse; // 处理结果：'approve' 或 'reject'
  final String? specialNotes; // 备注信息
  final DateTime? requestStartTime; // 邀约开始时间
  final DateTime? requestEndTime; // 邀约结束时间

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
    this.completedAt,
    required this.createdBy,
    required this.startTime,
    required this.endTime,
    this.color = '#4CAF50',
    this.location,
    this.isAllDay = false,
    this.progressPercentage = 0,
    this.parentTaskId,
    this.subtasks,
    this.isRequest = false,
    this.requestType,
    this.requestResponse,
    this.specialNotes,
    this.requestStartTime,
    this.requestEndTime,
    this.attachments = const [],
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
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
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
      parentTaskId: json['parent_task_id'],
      subtasks: json['subtasks'] != null 
          ? (json['subtasks'] as List).map((e) => Task.fromJson(e)).toList()
          : null,
      isRequest: json['is_request'] == true || json['is_request'] == 1 || json['isRequest'] == true,
      requestType: json['request_type'] ?? json['requestType'],
      requestResponse: json['request_response'] ?? json['requestResponse'],
      specialNotes: json['special_notes'] ?? json['specialNotes'],
      requestStartTime: json['request_start_time'] != null ? DateTime.parse(json['request_start_time']) : null,
      requestEndTime: json['request_end_time'] != null ? DateTime.parse(json['request_end_time']) : null,
      attachments: _parseStringList(json['attachments']),
    );
  }

  Map<String, dynamic> toJson() {
    // 格式化时间，转换为后端期望的格式 YYYY-MM-DD HH:MM:SS
    final formatDateTime = (DateTime dt) {
      final year = dt.year.toString().padLeft(4, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute:$second';
    };

    return {
      // 后端期望的字段格式（下划线命名）
      'title': title,
      'description': description.isEmpty ? null : description,
      'assignee_id': assigneeId,
      'department_id': department, // 注意：这里应该是 department_id，但为了兼容性先传递 department
      'priority': priority,
      'status': status,
      'deadline': deadline != null ? formatDateTime(deadline!) : null,
      'start_time': formatDateTime(startTime),
      'end_time': formatDateTime(endTime),
      'location': location,
      'is_all_day': isAllDay,
      'parent_task_id': parentTaskId, // 支持创建子任务
      'progress_percentage': progressPercentage, // 添加进度字段
      'attachments': attachments,
      'request_start_time': requestStartTime != null ? formatDateTime(requestStartTime!) : null,
      'request_end_time': requestEndTime != null ? formatDateTime(requestEndTime!) : null,
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
        return Colors.green;
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
        return '已完成';
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

List<String> _parseStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
      }
    } catch (_) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
  }
  return const [];
}
