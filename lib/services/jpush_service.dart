import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
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

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            await openAppSettings();
            return;
          }
        }
      }
      jpush.addEventHandler(
        onReceiveNotification: (Map<String, dynamic> message) async {
          print("Flutter 接收到推送: $message");
        },
        onOpenNotification: (Map<String, dynamic> message) async {
          print("Flutter 点击了推送: $message");
          try {
            final extras = _parseExtras(message);
            final type = extras['type'] ?? '';
            final taskId = extras['taskId'] ?? '';
            final user = currentUser;
            if (user == null) return;
            final state = navigatorKey.currentState;
            if (state == null) return;
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
        debug: true,
      );
      jpush.getRegistrationID().then((rid) {
        print("极光推送 Registration ID: $rid");
        registrationId = rid;
      });
      _initialized = true;
    } on PlatformException catch (e) {
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
}
