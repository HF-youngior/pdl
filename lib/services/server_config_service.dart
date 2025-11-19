import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// 服务器配置服务
/// 支持模拟器和真机连接
/// 
/// ============================================
/// 真机连接配置指南
/// ============================================
/// 
/// 【方法一：通过应用设置界面配置（推荐）】
/// 1. 打开应用，进入"设置"页面
/// 2. 找到"服务器配置"选项
/// 3. 点击进入配置界面
/// 4. 输入电脑的IP地址（如：192.168.1.100）
/// 5. 输入端口（默认：8080）
/// 6. 点击"保存"
/// 7. 重启应用使配置生效
/// 
/// 【方法二：通过代码配置】
/// 在应用启动前调用：
///   await ServerConfigService.setServerHost('192.168.1.100');
///   await ServerConfigService.setServerPort('8080');
/// 
/// 【获取电脑IP地址的方法】
/// Windows:
///   1. 打开命令提示符（cmd）
///   2. 输入: ipconfig
///   3. 查找"IPv4 地址"，通常是 192.168.x.x 或 10.x.x.x
/// 
/// Mac/Linux:
///   1. 打开终端
///   2. 输入: ifconfig 或 ip addr
///   3. 查找局域网IP地址
/// 
/// 【注意事项】
/// 1. 确保手机和电脑连接在同一个WiFi网络
/// 2. 确保电脑防火墙允许8080端口的连接
/// 3. 确保后端服务器正在运行
/// 4. 模拟器默认使用 10.0.2.2:8080，无需配置
/// 5. 真机必须配置电脑的实际IP地址
/// 
/// 【测试连接】
/// 配置完成后，尝试登录应用，如果能够成功登录说明配置正确
class ServerConfigService {
  static const String _keyServerHost = 'server_host';
  static const String _keyServerPort = 'server_port';
  
  // 默认配置
  static const String _defaultPort = '8080';
  
  /// 获取默认主机地址
  /// - Web平台: 127.0.0.1
  /// - Android模拟器: 10.0.2.2
  /// - 其他平台: 127.0.0.1
  static String _getDefaultHost() {
    if (kIsWeb) return '127.0.0.1';
    try {
      if (Platform.isAndroid) return '10.0.2.2'; // Android模拟器专用地址
    } catch (_) {
      // Platform not available
    }
    return '127.0.0.1';
  }
  
  /// 获取服务器主机地址
  /// 优先使用用户配置，否则使用默认值
  static Future<String> getServerHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(_keyServerHost);
      if (host != null && host.isNotEmpty) {
        return host;
      }
    } catch (e) {
      print('获取服务器主机配置失败: $e');
    }
    return _getDefaultHost();
  }
  
  /// 设置服务器主机地址
  /// 用于真机连接时配置电脑的IP地址
  /// 例如: await ServerConfigService.setServerHost('192.168.1.100');
  static Future<bool> setServerHost(String host) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyServerHost, host.trim());
    } catch (e) {
      print('设置服务器主机配置失败: $e');
      return false;
    }
  }
  
  /// 获取服务器端口
  static Future<String> getServerPort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final port = prefs.getString(_keyServerPort);
      if (port != null && port.isNotEmpty) {
        return port;
      }
    } catch (e) {
      print('获取服务器端口配置失败: $e');
    }
    return _defaultPort;
  }
  
  /// 设置服务器端口
  static Future<bool> setServerPort(String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyServerPort, port.trim());
    } catch (e) {
      print('设置服务器端口配置失败: $e');
      return false;
    }
  }
  
  /// 获取完整的baseUrl
  /// 格式: http://host:port/api
  static Future<String> getBaseUrl() async {
    final host = await getServerHost();
    final port = await getServerPort();
    return 'http://$host:$port/api';
  }
  
  /// 重置为默认配置
  static Future<bool> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyServerHost);
      await prefs.remove(_keyServerPort);
      return true;
    } catch (e) {
      print('重置服务器配置失败: $e');
      return false;
    }
  }
  
  /// 获取当前配置信息（用于显示）
  static Future<Map<String, String>> getConfigInfo() async {
    final host = await getServerHost();
    final port = await getServerPort();
    final isDefault = host == _getDefaultHost() && port == _defaultPort;
    
    return {
      'host': host,
      'port': port,
      'baseUrl': await getBaseUrl(),
      'isDefault': isDefault.toString(),
      'platform': kIsWeb ? 'Web' : (Platform.isAndroid ? 'Android' : 'Other'),
    };
  }
}

