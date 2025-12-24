// lib/models/personal_log.dart
import 'dart:convert';
import 'package:testflutterproject/models/log_task_update.dart';

class PersonalLog {
  final String id;
  final String userId;
  final String? title;
  final String? content;
  final String? category;
  final bool isCompleted;
  final String? createdAt; // 时间戳(字符串)
  final DateTime? logDate;
  final List<String> images;
  final String? locationName;
  final String? locationAddress; // 后端转换的地址
  final double? latitude;
  final double? longitude;
  // 兼容增强视图所需的可选字段
  final String? weather; // 天气（可能来自新版接口或留空）
  final List<String> keywords; // 关键词列表（若无则为空）
  final List<LogTaskUpdate> taskUpdates;

  // 兼容增强视图：logTitle 映射到 title
  String get logTitle => title ?? '';
  // 兼容增强视图：将 createdAt 转为 DateTime
  DateTime? get createdAtDate => _tryParseDateTime(createdAt);
  // 兼容增强视图：将 taskUpdates 适配为 linkages 列表
  List<LogTaskLinkage> get linkages => taskUpdates
      .map((u) => LogTaskLinkage(
            taskId: u.taskId,
            progressPercentage: u.progress_percentage ?? 0,
            taskStatus: u.task_status,
            taskName: u.taskName,
          ))
      .toList();

  PersonalLog({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    required this.category,
    required this.isCompleted,
    required this.createdAt,
    this.weather,
    List<String>? keywords,
    required this.taskUpdates,
    this.logDate,
    List<String>? images,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
  })  : keywords = keywords ?? const [],
        images = images ?? const [];

  factory PersonalLog.fromJson(Map<String, dynamic> json) {
    final dynamic kw = json['keywords'];
    final List<String> parsedKeywords =
      kw is List ? kw.map((e) => e.toString()).toList()
      : (kw is String && kw.trim().isNotEmpty)
        ? kw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return PersonalLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? json['log_title'] ?? '个人日志',
      content: json['content'] ?? json['log_content'],
      category: json['category']?.toString(),
      isCompleted: (json['is_completed'] == 1 || json['is_completed'] == true),
      createdAt: json['created_at']?.toString() ?? json['log_date']?.toString(),
      weather: json['weather']?.toString(),
      keywords: parsedKeywords, // 只取数据库/接口返回，不从 content 拆分
      taskUpdates: (json['taskUpdates'] as List<dynamic>? ?? [])
          .map((item) => LogTaskUpdate.fromJson(item as Map<String, dynamic>))
          .toList(),
      logDate: _tryParseDateTime(json['log_date']?.toString()),
      images: _parseStringList(json['images']),
      // 优先使用后端转换好的地址，如果没有则使用原始的location_name
      locationName: _sanitizeLocationString(json['location_name'] ?? json['locationName']),
      locationAddress: _sanitizeLocationString(json['location_address']),
      latitude: _toDouble(json['location_latitude'] ?? json['locationLatitude']),
      longitude: _toDouble(json['location_longitude'] ?? json['locationLongitude']),
    );
  }

  // 将当前模型序列化为 API 需要的 JSON 结构
  // 符合后端 /api/personal-logs 接口期望的 { log: {...}, linkages: [...] }
  Map<String, dynamic> toJson() {
    return {
      'log': {
        'log_date': createdAt,
        'title': title,
        'content': content,
        'category': category,
        'is_completed': isCompleted,
        if (weather != null) 'weather': weather,
        if (keywords.isNotEmpty) 'keywords': keywords.join(','),
        if (images.isNotEmpty) 'images': images,
        if (locationName != null)
          'location': {
            'name': locationName,
            'latitude': latitude,
            'longitude': longitude,
          },
      },
      'linkages': taskUpdates.map((e) => e.toJson()).toList(),
    };
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
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

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String && value.isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

String? _sanitizeLocationString(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    final joined = value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).join('');
    if (joined.isEmpty) return null;
    return joined;
  }
  final s = value.toString().trim();
  if (s.isEmpty || s == '[]') return null;
  return s;
}

// 兼容增强视图使用的旧结构（linkages）
class LogTaskLinkage {
  final String taskId;
  final int progressPercentage;
  final String? taskStatus;
  final String? taskName;

  LogTaskLinkage({
    required this.taskId,
    required this.progressPercentage,
    this.taskStatus,
    this.taskName,
  });
}


