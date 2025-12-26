import 'dart:convert';
import 'package:http/http.dart' as http;

/// 逆地理编码服务
/// 使用OpenStreetMap的Nominatim API将GPS坐标转换为地址
class GeocodingService {
  /// 将经纬度转换为地址
  /// 返回格式化的地址字符串，如果失败则返回null
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      // 使用OpenStreetMap Nominatim API（免费，无需API key）
      // 注意：请遵守使用政策，不要过于频繁请求
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&'
        'lat=$latitude&'
        'lon=$longitude&'
        'zoom=18&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterApp/1.0', // Nominatim要求设置User-Agent
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        if (address != null) {
          // 构建地址字符串，优先使用详细地址
          final parts = <String>[];

          // 街道地址
          if (address['road'] != null) {
            parts.add(address['road']);
          }
          if (address['house_number'] != null) {
            parts.insert(0, address['house_number']);
          }

          // 区域信息
          if (address['neighbourhood'] != null || address['suburb'] != null) {
            parts.add(address['neighbourhood'] ?? address['suburb']);
          }

          // 城市/区县
          if (address['city'] != null) {
            parts.add(address['city']);
          } else if (address['town'] != null) {
            parts.add(address['town']);
          } else if (address['county'] != null) {
            parts.add(address['county']);
          }

          // 省份/州
          if (address['state'] != null) {
            parts.add(address['state']);
          }

          // 国家
          if (address['country'] != null) {
            parts.add(address['country']);
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }

          // 如果没有详细地址，使用显示名称
          if (data['display_name'] != null) {
            return data['display_name'] as String;
          }
        }
      }

      return null;
    } catch (e) {
      print('逆地理编码错误: $e');
      return null;
    }
  }

  /// 批量逆地理编码（带缓存，避免重复请求）
  static final Map<String, String?> _cache = {};

  /// 带缓存的逆地理编码
  /// 相同坐标的请求会使用缓存结果
  static Future<String?> reverseGeocodeCached(double latitude, double longitude) async {
    final key = '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    final address = await reverseGeocode(latitude, longitude);
    _cache[key] = address;
    return address;
  }

  /// 清除缓存
  static void clearCache() {
    _cache.clear();
  }
}

