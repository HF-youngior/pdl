import 'dart:convert';

class Log {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String description;
  final String category;
  final String quadrant;
  final int isCompleted; // 完成状态：1=已完成，0=未完成
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
    required this.isCompleted,
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
      isCompleted: json['is_completed'] ?? json['isCompleted'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      metadata: _parseMetadata(json['metadata']),
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
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
      'relatedTaskId': relatedTaskId,
      // 后端期望的字段名
      'user_id': userId,
      'user_name': userName,
      'is_completed': isCompleted,
      'related_task_id': relatedTaskId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // 天气emoji映射方法（与新建日志保持一致）
  String getWeatherEmoji() {
    final weather = metadata?['weather'] ?? 'sunny';
    switch (weather) {
      case 'sunny':
        return '☀️';
      case 'cloudy':
        return '⛅';
      case 'light_rain':
        return '🌧️';
      case 'heavy_rain':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'storm':
        return '⚡';
      case 'fog':
        return '🌫️';
      default:
        return '☀️';
    }
  }

  // 完成状态判断
  bool get isCompletedBool => isCompleted == 1;

  List<String> get images => _parseImages(metadata?['images']);

  String? get locationName {
    final location = _extractLocation(metadata);
    final name = location?['name'] ?? location?['location_name'];
    return name?.toString();
  }

  double? get latitude {
    final location = _extractLocation(metadata);
    return _toDouble(location?['latitude'] ?? location?['lat']);
  }

  double? get longitude {
    final location = _extractLocation(metadata);
    return _toDouble(location?['longitude'] ?? location?['lng']);
  }
}

Map<String, dynamic>? _parseMetadata(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
  }
  return null;
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

Map<String, dynamic>? _extractLocation(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  if (metadata['location'] is Map) {
    return Map<String, dynamic>.from(metadata['location']);
  }
  final name = metadata['location_name'];
  final lat = metadata['location_latitude'] ?? metadata['latitude'];
  final lng = metadata['location_longitude'] ?? metadata['longitude'];
  if (name == null && lat == null && lng == null) return null;
  return {
    'name': name,
    'latitude': lat,
    'longitude': lng,
  };
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
