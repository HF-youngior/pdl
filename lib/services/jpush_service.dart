import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../services/task_service.dart';
import '../screens/notification_center_screen.dart';
import '../screens/task_detail_screen.dart';
import '../models/user.dart';
import '../models/task.dart';

class JPushService {
  static final JPushFlutterInterface jpush = JPush.newJPush();
  static String? registrationId;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _initialized = false;
  static User? currentUser;
  static const MethodChannel _pushUtilsChannel = MethodChannel('com.example.testflutterproject/push_utils');

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 移除启动时的即时权限申请，移至 throttled 的 suggestSystemOptimizations 中
      // 移除 600ms 的人工延迟，让启动更丝滑
      
      currentUser ??= ApiService.getCurrentUser();
      
      jpush.addEventHandler(
        onReceiveNotification: (Map<String, dynamic> message) async {
          print("Flutter 接收到推送: $message");
        },
        onOpenNotification: (Map<String, dynamic> message) async {
          print("Flutter 点击了推送: $message");
          try {
            final extras = _parseExtras(message);
            final taskId = extras['taskId'] ?? '';
            final user = currentUser ?? ApiService.getCurrentUser();
            if (user == null) return;
            final state = navigatorKey.currentState;
            if (state == null) return;
            if (kIsWeb) return;
            
            if (taskId is String && taskId.isNotEmpty) {
              try {
                final task = await TaskService.getTaskById(taskId);
                state.push(MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task, currentUser: user),
                ));
              } catch (_) {
                state.push(MaterialPageRoute(
                  builder: (context) => NotificationCenterScreen(user: user),
                ));
              }
            } else {
              state.push(MaterialPageRoute(
                builder: (context) => NotificationCenterScreen(user: user),
              ));
            }
          } catch (e) {
            print('推送点击跳转失败: $e');
          }
        },
        onReceiveMessage: (Map<String, dynamic> message) async {
          print("Flutter 接收到自定义消息: $message");
        },
      );

      jpush.setup(
        appKey: "a7474254450572b4411beacc",
        channel: "developer-default",
        production: false,
        debug: false, // 生产环境下建议关闭 debug 日志以提升性能
      );

      // 异步获取 ID，不阻塞初始化完成
      jpush.getRegistrationID().then((rid) {
        if (rid.isNotEmpty) {
          registrationId = rid;
          final user = ApiService.getCurrentUser();
          final token = ApiService.getToken();
          if (user != null && token != null) {
            ApiService.registerPushDevice(rid, platform: Platform.isAndroid ? 'android' : 'ios')
                .catchError((e) => print('后台注册推送设备失败: $e'));
          }
        }
      });
      
      _initialized = true;
      
      // 启动后异步触发系统优化建议（内部有延迟和频率限制）
      if (Platform.isAndroid) {
        suggestSystemOptimizations();
      }
    } catch (e) {
      print('极光推送初始化失败: $e');
    }
  }

  static Map<String, dynamic> _parseExtras(Map<String, dynamic> message) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(message);
    if (m.containsKey('extras') && m['extras'] is Map) {
      return Map<String, dynamic>.from(m['extras'] as Map);
    }
    return m;
  }

  static DateTime? _lastRefreshTime;

  static Future<void> refreshRegistration() async {
    // 增加频率限制，30分钟内只允许自动刷新一次
    if (_lastRefreshTime != null && 
        DateTime.now().difference(_lastRefreshTime!).inMinutes < 30) {
      return;
    }
    
    try {
      final rid = await jpush.getRegistrationID();
      if (rid.isNotEmpty) {
        _lastRefreshTime = DateTime.now();
        if (rid != registrationId) {
          registrationId = rid;
          final user = ApiService.getCurrentUser();
          final token = ApiService.getToken();
          if (user != null && token != null) {
            await ApiService.registerPushDevice(rid, platform: Platform.isAndroid ? 'android' : 'ios');
            currentUser ??= user;
          }
        }
      }
    } catch (e) {
      print('刷新推送注册失败: $e');
    }
  }

  static Future<void> suggestSystemOptimizations() async {
    if (!Platform.isAndroid) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_system_opt_check') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 7 天频率限制，避免频繁干扰
      if (now - lastCheck < 7 * 24 * 60 * 60 * 1000) return;

      // 启动 5 秒后执行，避开首屏加载高峰
      await Future.delayed(const Duration(seconds: 5));
      
      // 1. 检查并请求忽略电池优化
      try {
        await _pushUtilsChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (_) {}
      
      // 2. 处理通知权限
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        // 先尝试系统原生弹窗申请
        final result = await Permission.notification.request();
        // 如果原生申请没通过，延迟 2 秒引导去设置页面（可选）
        if (!result.isGranted) {
          await Future.delayed(const Duration(seconds: 2));
          try {
            await _pushUtilsChannel.invokeMethod('openNotificationSettings');
          } catch (_) {}
        }
      }

      // 记录本次执行时间
      await prefs.setInt('last_system_opt_check', now);
      
    } catch (e) {
      print('系统优化静默执行失败: $e');
    }
  }
}
