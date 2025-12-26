import 'dart:convert';
import 'package:http/http.dart' as http;

/// 逆地理编码服务
/// 使用高德地图API将GPS坐标转换为地址
class GeocodingService {
  static const String _baseUrl = 'https://restapi.amap.com/v3';
  static const String _webApiKey = 'b5372dbe5fedfd2481830b7b2dc7a7fa'; // Web服务API Key

  /// 将经纬度转换为地址
  /// 返回格式化的地址字符串，如果失败则返回null
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_baseUrl/geocode/regeo').replace(queryParameters: {
        'key': _webApiKey,
        'location': '$longitude,$latitude', // 高德地图API使用经度,纬度的顺序
        'poitype': '',
        'radius': '1000',
        'extensions': 'all',
        'batch': 'false',
        'roadlevel': '0',
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == '1' && data['regeocode'] != null) {
          final regeocode = data['regeocode'];
          return regeocode['formatted_address'] as String?;
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

