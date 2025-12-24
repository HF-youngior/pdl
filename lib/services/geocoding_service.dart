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
      // 检查是否在中国境内大致范围内（高德地图主要支持中国境内）
      if (latitude < 3.86 || latitude > 53.55 || longitude < 73.66 || longitude > 135.05) {
        print('坐标在中国境外，高德地图API可能无法提供准确地址: 纬度=$latitude, 经度=$longitude');
        return '海外地区 ($latitude, $longitude)';
      }
      
      final url = Uri.parse('$_baseUrl/geocode/regeo').replace(queryParameters: {
        'key': _webApiKey,
        'location': '$longitude,$latitude', // 高德地图API使用经度,纬度的顺序
        'poitype': '',
        'radius': '1000',
        'extensions': 'all',
        'batch': 'false',
        'roadlevel': '0',
      });

      print('逆地理编码请求URL: $url');
      final response = await http.get(url);
      print('逆地理编码响应状态码: ${response.statusCode}');
      print('逆地理编码响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('解析后的JSON数据: $data');
        
        if (data['status'] == '1' && data['regeocode'] != null) {
          final regeocode = data['regeocode'];
          final address = regeocode['formatted_address'] as String?;
          print('获取到的地址: $address');
          return address;
        } else {
          print('API返回状态异常: status=${data['status']}, info=${data['info']}');
          // 如果API返回错误，尝试返回坐标信息
          return '位置信息获取失败 ($latitude, $longitude)';
        }
      } else {
        print('HTTP请求失败，状态码: ${response.statusCode}');
        return '网络请求失败 ($latitude, $longitude)';
      }
    } catch (e) {
      print('逆地理编码错误: $e');
      return '地址解析异常 ($latitude, $longitude)';
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

