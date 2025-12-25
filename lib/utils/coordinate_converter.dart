import 'dart:math' as math;

/// 坐标转换工具类
/// 用于在不同坐标系之间转换坐标
class CoordinateConverter {
  /// 将WGS84坐标转换为GCJ-02坐标（火星坐标系）
  /// 
  /// WGS84: GPS原始坐标系
  /// GCJ-02: 中国国家测绘局制定的坐标系，高德地图、腾讯地图等使用
  /// 
  /// 参数:
  ///   - latitude: WGS84纬度
  ///   - longitude: WGS84经度
  /// 
  /// 返回:
  ///   Map包含转换后的纬度和经度 {'latitude': double, 'longitude': double}
  static Map<String, double> wgs84ToGcj02(double latitude, double longitude) {
    // 判断是否在中国境内（粗略判断）
    if (latitude < 0.8293 || latitude > 55.8271 || 
        longitude < 72.004 || longitude > 137.8347) {
      // 不在中国境内，不需要转换
      return {'latitude': latitude, 'longitude': longitude};
    }

    const double a = 6378245.0; // 长半轴
    const double ee = 0.00669342162296594323; // 偏心率平方
    const double pi = 3.1415926535897932384626;

    double dLat = _transformLat(longitude - 105.0, latitude - 35.0);
    double dLon = _transformLon(longitude - 105.0, latitude - 35.0);
    double radLat = latitude / 180.0 * math.pi;
    double magic = 1 - ee * (math.sin(radLat) * math.sin(radLat));
    double sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLon = (dLon * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
    double mgLat = latitude + dLat;
    double mgLon = longitude + dLon;
    
    return {'latitude': mgLat, 'longitude': mgLon};
  }

  /// 纬度转换辅助函数
  static double _transformLat(double lon, double lat) {
    double ret = -100.0 + 2.0 * lon + 3.0 * lat + 0.2 * lat * lat +
        0.1 * lon * lat + 0.2 * math.sqrt(lon.abs());
    ret += (20.0 * math.sin(6.0 * lon * math.pi) + 20.0 * math.sin(2.0 * lon * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(lat * math.pi) + 40.0 * math.sin(lat / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(lat / 12.0 * math.pi) + 320 * math.sin(lat * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  /// 经度转换辅助函数
  static double _transformLon(double lon, double lat) {
    double ret = 300.0 + lon + 2.0 * lat + 0.1 * lon * lon +
        0.1 * lon * lat + 0.1 * math.sqrt(lon.abs());
    ret += (20.0 * math.sin(6.0 * lon * math.pi) + 20.0 * math.sin(2.0 * lon * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(lon * math.pi) + 40.0 * math.sin(lon / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (150.0 * math.sin(lon / 12.0 * math.pi) + 300.0 * math.sin(lon / 30.0 * math.pi)) * 2.0 / 3.0;
    return ret;
  }
}

