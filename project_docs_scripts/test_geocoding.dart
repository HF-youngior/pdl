import 'dart:io';
import 'package:testflutterproject/services/geocoding_service.dart';

Future<void> main() async {
  print('测试逆地理编码服务...');
  
  // 测试天安门坐标
  final address = await GeocodingService.reverseGeocode(39.9042, 116.4074);
  print('地址: $address');
  
  exit(0);
}