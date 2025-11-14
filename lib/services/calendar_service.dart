import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class CalendarService {
  static String get baseUrl => ApiService.baseUrl;

  // 获取月视图数据
  static Future<MonthViewData> getMonthView(int year, int month) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/calendar/month-view?year=$year&month=$month'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return MonthViewData.fromJson(data);
      } else {
        throw Exception('获取月视图数据失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取月视图数据失败: $e');
    }
  }

  // 获取指定日期的详细信息
  static Future<DayDetailData> getDayDetail(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await http.get(
        Uri.parse('$baseUrl/calendar/day-detail?date=$dateStr'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return DayDetailData.fromJson(data);
      } else {
        throw Exception('获取日期详情失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取日期详情失败: $e');
    }
  }

  // 更新任务
  static Future<void> updateTask(
    String taskId, {
    String? title,
    String? description,
    String? priority,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (priority != null) body['priority'] = priority;
      if (status != null) body['status'] = status;

      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('更新任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('更新任务失败: $e');
    }
  }

  // 删除任务
  static Future<void> deleteTask(String taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('删除任务失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('删除任务失败: $e');
    }
  }

  // 更新日志
  static Future<void> updateLog(
    String logId, {
    required String category,
    required bool isCompleted,
    String? createdAt,
    String? logDate,
    String? title,
    String? content,
  }) async {
    try {
      final resolvedTitle = (title?.trim().isNotEmpty ?? false) ? title!.trim() : null;
      final resolvedContent = content?.trim();

      final logPayload = <String, dynamic>{
        'title': resolvedTitle,
        'content': resolvedContent,
        'category': category,
        'is_completed': isCompleted,
      };

      if (createdAt != null && createdAt.isNotEmpty) {
        logPayload['created_at'] = createdAt;
      }

      if (logDate != null && logDate.isNotEmpty) {
        logPayload['log_date'] = logDate;
      }

      // 移除空值，避免覆盖为 null
      logPayload.removeWhere((key, value) => value == null);

      final response = await http.put(
        Uri.parse('$baseUrl/personal-logs/$logId'),
        headers: {
          ...ApiService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'log': logPayload}),
      );

      if (response.statusCode != 200) {
        throw Exception('更新日志失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('更新日志失败: $e');
    }
  }

  // 删除日志
  static Future<void> deleteLog(String logId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/personal-logs/$logId'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode != 204) {
        throw Exception('删除日志失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('删除日志失败: $e');
    }
  }
}

// 月视图数据模型
class MonthViewData {
  final int year;
  final int month;
  final List<DayData> days;
  final MonthSummary summary;

  MonthViewData({
    required this.year,
    required this.month,
    required this.days,
    required this.summary,
  });

  factory MonthViewData.fromJson(Map<String, dynamic> json) {
    return MonthViewData(
      year: json['year'],
      month: json['month'],
      days: (json['days'] as List)
          .map((day) => DayData.fromJson(day))
          .toList(),
      summary: MonthSummary.fromJson(json['summary']),
    );
  }
}

// 单日数据模型
class DayData {
  final String date;
  final List<CalendarTask> tasks;
  final List<CalendarLog> logs;
  final bool hasData;

  DayData({
    required this.date,
    required this.tasks,
    required this.logs,
    required this.hasData,
  });

  factory DayData.fromJson(Map<String, dynamic> json) {
    return DayData(
      date: json['date'] ?? '',
      tasks: (json['tasks'] as List? ?? [])
          .map((task) => CalendarTask.fromJson(task))
          .toList(),
      logs: (json['logs'] as List? ?? [])
          .map((log) => CalendarLog.fromJson(log))
          .toList(),
      hasData: json['hasData'] == 1 || json['hasData'] == true || (json['hasData'] ?? false),
    );
  }
}

// 日历任务模型
class CalendarTask {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? color;
  final String? startTime;
  final String? endTime;
  final String? deadline;
  final bool? isAllDay;
  final String? assigneeName;

  CalendarTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.color,
    this.startTime,
    this.endTime,
    this.deadline,
    this.isAllDay,
    this.assigneeName,
  });

  factory CalendarTask.fromJson(Map<String, dynamic> json) {
    return CalendarTask(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'p2',
      color: json['color'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      deadline: json['deadline'],
      isAllDay: json['is_all_day'] == 1 || json['is_all_day'] == true,
      assigneeName: json['assignee_name'],
    );
  }
}

// 日历日志模型
class CalendarLog {
  final String id;
  final String title;
  final String content;
  final String category;
  final String quadrant;
  final bool isCompleted;
  final String createdAt;
  final List<String> images;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  CalendarLog({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.quadrant,
    required this.isCompleted,
    required this.createdAt,
    required this.images,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  factory CalendarLog.fromJson(Map<String, dynamic> json) {
    return CalendarLog(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      quadrant: json['quadrant'] ?? '',
      isCompleted: json['is_completed'] == 1 || json['is_completed'] == true,
      createdAt: json['created_at'] ?? '',
      images: _parseImages(json['images']),
      locationName: json['location_name'],
      latitude: _toDouble(json['location_latitude']),
      longitude: _toDouble(json['location_longitude']),
    );
  }
}

List<String> _parseImages(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String && value.isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

// 月视图摘要
class MonthSummary {
  final int totalTasks;
  final int totalLogs;
  final int daysWithData;

  MonthSummary({
    required this.totalTasks,
    required this.totalLogs,
    required this.daysWithData,
  });

  factory MonthSummary.fromJson(Map<String, dynamic> json) {
    return MonthSummary(
      totalTasks: json['totalTasks'],
      totalLogs: json['totalLogs'],
      daysWithData: json['daysWithData'],
    );
  }
}

// 日期详情数据模型
class DayDetailData {
  final String date;
  final List<CalendarTask> tasks;
  final List<CalendarLog> logs;

  DayDetailData({
    required this.date,
    required this.tasks,
    required this.logs,
  });

  factory DayDetailData.fromJson(Map<String, dynamic> json) {
    return DayDetailData(
      date: json['date'],
      tasks: (json['tasks'] as List)
          .map((task) => CalendarTask.fromJson(task))
          .toList(),
      logs: (json['logs'] as List)
          .map((log) => CalendarLog.fromJson(log))
          .toList(),
    );
  }
}
