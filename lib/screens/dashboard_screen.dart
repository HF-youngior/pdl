import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../widgets/quadrant_widget.dart';
import 'company_important_screen.dart';
import 'company_tasks_enhanced_screen.dart';
import 'personal_resume_screen.dart';
import 'log_enhanced_screen.dart';
import 'task_edit_screen.dart';
import 'task_detail_screen.dart';
import '../services/app_settings.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';
import '../services/mbti_test_service.dart';
import '../services/notification_service.dart';
import '../models/task.dart';
import '../models/important_item.dart';
import '../models/personal_info.dart';
import '../models/personal_log.dart';
import '../models/mbti_test_result.dart';
import 'pomodoro_focus_screen.dart';
import '../models/deadline_reminder.dart';
import '../models/notification.dart' show TaskNotification;
import '../utils/time_utils.dart';
import 'notification_center_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AppSettings _settings = AppSettings.instance;
  int _highPriorityPendingCount = 0;
  int _unreadNotificationCount = 0;
  static const List<_ThemeColorOption> _themeColorOptions = [
    // 稍微加深的马卡龙蓝，保证文字对比度
    _ThemeColorOption(label: '马卡龙蓝', color: Color(0xFF4A90E2)),
    _ThemeColorOption(label: '马卡龙粉', color: Color(0xFFFFB3C1)),
    _ThemeColorOption(label: '清新桃', color: Color(0xFFFFD6A5)),
    // 将柠檬奶油改成更深的黄色系，避免过亮导致看不清
    _ThemeColorOption(label: '柠檬奶油', color: Color(0xFFF6C94C)),
    _ThemeColorOption(label: '薄荷绿', color: Color(0xFFA8E6CF)),
    _ThemeColorOption(label: '奶油紫', color: Color(0xFFCDB4DB)),
    _ThemeColorOption(label: '薰衣草', color: Color(0xFFD7C0FF)),
    _ThemeColorOption(label: '珊瑚橘', color: Color(0xFFFFC9B9)),
    // 天空蓝改成稍深的蓝绿色，保证和白色/黑色文字对比更好
    _ThemeColorOption(label: '天空蓝', color: Color(0xFF2196F3)),
  ];

  // 预览数据
  List<String> _companyImportantItems = [];
  List<String> _companyTasks = [];
  List<String> _personalImportantItems = [];
  List<String> _personalLogs = [];
  List<String> _personalPreviewItems = [];
  MbtiTestResult? _latestMbti;
  bool _isLoadingPreview = true;
  List<Task> _myAssignedTasks = [];
  Timer? _deadlineReminderTimer;
  bool _isCheckingDeadlineReminders = false;
  Timer? _notificationPollingTimer;
  Set<String> _displayedNotificationIds = {};
  bool _isCheckingNotifications = false;

  bool get _isGuestUser => widget.user.id == 'guest';

  @override
  void initState() {
    super.initState();
    _loadBadgeCount();
    _loadPreviewData();
    _settings.addListener(_onSettingsChanged);
    _startDeadlineReminderMonitor();
    _startNotificationPolling();
    // 初始化时加载未读通知数量
    _loadUnreadNotificationCount();
  }

  /// 加载未读通知数量
  Future<void> _loadUnreadNotificationCount() async {
    if (_isGuestUser || ApiService.getToken() == null) return;

    try {
      final notifications = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = notifications.where((n) => !n.isRead).length;
        });
      }
    } catch (e) {
      debugPrint('加载未读通知数量失败: $e');
    }
  }

  @override
  void dispose() {
    _deadlineReminderTimer?.cancel();
    _notificationPollingTimer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _startDeadlineReminderMonitor() {
    _deadlineReminderTimer?.cancel();
    if (_isGuestUser) return;
    _runDeadlineReminderCheck();
    _deadlineReminderTimer = Timer(const Duration(minutes: 1), _scheduleNextDeadlineReminder);
  }

  void _scheduleNextDeadlineReminder() {
    if (!mounted || _isGuestUser) return;
    _runDeadlineReminderCheck();
    _deadlineReminderTimer = Timer(const Duration(minutes: 1), _scheduleNextDeadlineReminder);
  }

  Future<void> _runDeadlineReminderCheck() async {
    if (!mounted ||
        _isGuestUser ||
        !_settings.notificationsEnabled ||
        _isCheckingDeadlineReminders ||
        ApiService.getToken() == null) {
      return;
    }

    _isCheckingDeadlineReminders = true;
    try {
      final reminders = await NotificationService.triggerDeadlineReminders(hoursBefore: 24);
      if (!mounted || reminders.isEmpty) return;
      // 将所有提醒合并到一个对话框中显示
      await _showDeadlineReminderDialog(reminders);
    } catch (e) {
      debugPrint('Deadline reminder check failed: $e');
    } finally {
      _isCheckingDeadlineReminders = false;
    }
  }

  void _startNotificationPolling() {
    _notificationPollingTimer?.cancel();
    if (_isGuestUser) return;
    _checkNotifications();
    // 每5秒检查一次新通知（与Web端保持一致）
    _notificationPollingTimer = Timer(const Duration(seconds: 5), _scheduleNextNotificationCheck);
  }

  void _scheduleNextNotificationCheck() {
    if (!mounted || _isGuestUser) return;
    _checkNotifications();
    _notificationPollingTimer = Timer(const Duration(seconds: 5), _scheduleNextNotificationCheck);
  }

  Future<void> _checkNotifications() async {
    if (!mounted ||
        _isGuestUser ||
        !_settings.notificationsEnabled ||
        _isCheckingNotifications ||
        ApiService.getToken() == null) {
      return;
    }

    _isCheckingNotifications = true;
    try {
      final notifications = await NotificationService.getNotifications();
      if (!mounted) return;

      // 更新未读通知数量（必须在筛选之前更新，确保数量准确）
      final unreadCount = notifications.where((n) => !n.isRead).length;
      if (mounted) {
        setState(() {
          _unreadNotificationCount = unreadCount;
        });
      }

      // 筛选出未读且未显示过的通知（只显示一次弹窗，但通知会保存在通知栏中）
      final newNotifications = notifications
          .where((n) => !n.isRead && !_displayedNotificationIds.contains(n.id))
          .toList();

      if (newNotifications.isNotEmpty) {
        // 记录已显示的通知ID（只记录一次，避免重复弹窗）
        for (final notification in newNotifications) {
          _displayedNotificationIds.add(notification.id);
        }

        // 显示通知弹窗（可以关闭，关闭后通知仍在通知栏中）
        if (mounted) {
          await _showNotificationDialog(newNotifications);
        }
      }
    } catch (e) {
      debugPrint('检查通知失败: $e');
    } finally {
      _isCheckingNotifications = false;
    }
  }

  Future<void> _showNotificationDialog(List<TaskNotification> notifications) async {
    if (!mounted || notifications.isEmpty) return;

    // 如果只有一个通知，显示简化版本
    if (notifications.length == 1) {
      final notification = notifications.first;
      bool isRead = notification.isRead;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(_getNotificationTitle(notification.notificationType)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 对于 deadline_warning 类型，消息中已包含任务标题，不重复显示
                    if (notification.taskTitle != null && notification.notificationType != 'deadline_warning') ...[
                      Text(
                        notification.taskTitle!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      notification.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (notification.fromUserName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '来自：${notification.fromUserName}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isRead,
                          onChanged: (value) {
                            setState(() {
                              isRead = value ?? false;
                            });
                            if (isRead) {
                              NotificationService.markAsRead(notification.id);
                            }
                          },
                        ),
                        const Text('标记为已读'),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // 打开通知中心查看详情
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationCenterScreen(user: widget.user),
                        ),
                      );
                    },
                    child: const Text('查看详情'),
                  ),
                  if (notification.taskId.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        try {
                          final task = await TaskService.getTaskById(notification.taskId);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailScreen(
                                  task: task,
                                  currentUser: widget.user,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('获取任务失败: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('查看任务'),
                    ),
                ],
              );
            },
          );
        },
      );
    } else {
      // 多个通知，显示列表
      final Map<String, bool> readStatus = {};
      for (final notification in notifications) {
        readStatus[notification.id] = notification.isRead;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          bool toggledAllRead = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('新通知'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = readStatus[notification.id] ?? false;

                      return ListTile(
                        title: Text(
                          notification.taskTitle ?? _getNotificationTitle(notification.notificationType),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isRead ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            if (notification.fromUserName != null)
                              Text(
                                '来自：${notification.fromUserName}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        leading: Checkbox(
                          value: isRead,
                          onChanged: (value) {
                            setDialogState(() {
                              readStatus[notification.id] = value ?? false;
                            });
                            if (readStatus[notification.id] == true) {
                              NotificationService.markAsRead(notification.id);
                            }
                          },
                        ),
                        onTap: () async {
                          if (notification.taskId.isNotEmpty) {
                            Navigator.of(context).pop();
                            try {
                              final task = await TaskService.getTaskById(notification.taskId);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailScreen(
                                      task: task,
                                      currentUser: widget.user,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('获取任务失败: $e')),
                                );
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // 打开通知中心查看详情
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationCenterScreen(user: widget.user),
                        ),
                      );
                    },
                    child: const Text('查看详情'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (!toggledAllRead) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('确认全部已读'),
                            content: const Text('确定将列表中所有未读通知标记为已读吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确认'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final ids = notifications.map((n) => n.id).toList();
                          final ok = await NotificationService.markAllRead(ids: ids);
                          if (ok) {
                            for (final id in ids) {
                              readStatus[id] = true;
                            }
                            setDialogState(() {
                              toggledAllRead = true;
                            });
                          }
                        }
                      } else {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('确认全部取消已读'),
                            content: const Text('确定将列表中所有通知恢复为未读吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确认'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final ids = notifications.map((n) => n.id).toList();
                          final ok = await NotificationService.markAllUnread(ids: ids);
                          if (ok) {
                            for (final id in ids) {
                              readStatus[id] = false;
                            }
                            setDialogState(() {
                              toggledAllRead = false;
                            });
                          }
                        }
                      }
                    },
                    child: Text(toggledAllRead ? '全部取消' : '全部已读'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  String _getNotificationTitle(String notificationType) {
    switch (notificationType) {
      case 'task_assigned':
        return '新任务';
      case 'deadline_warning':
        return '截止时间提醒';
      case 'task_progress_update':
        return '任务进度更新';
      case 'task_completed':
        return '任务完成';
      case 'task_cancelled':
        return '任务取消';
      case 'special_notes':
        return '特殊备注';
      default:
        return '通知';
    }
  }

  Future<void> _showDeadlineReminderDialog(List<DeadlineReminder> reminders) async {
    if (!mounted || reminders.isEmpty) return;

    // 如果只有一个提醒，显示简化版本
    if (reminders.length == 1) {
      final reminder = reminders.first;
      final deadlineText = reminder.deadline != null
          ? TimeUtils.formatDateTimeWithZone(reminder.deadline!)
          : '未设置';

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: const Text('任务即将到期'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('截止时间：$deadlineText'),
                Text('优先级：${_priorityLabel(reminder.priority)}'),
                Text('当前状态：${_statusLabel(reminder.status)}'),
                const SizedBox(height: 12),
                Text(
                  reminder.message,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('稍后处理'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openTasksPanel();
                },
                child: const Text('查看任务'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 多个提醒，合并显示
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${reminders.length} 个任务即将到期'),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '您有 ${reminders.length} 个任务即将在24小时内到期，请及时处理。',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '任务列表：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...reminders.map((reminder) {
                    final deadlineText = reminder.deadline != null
                        ? TimeUtils.formatDateTimeWithZone(reminder.deadline!)
                        : '未设置';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '截止时间：$deadlineText',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                            Text(
                              '优先级：${_priorityLabel(reminder.priority)} | 状态：${_statusLabel(reminder.status)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后处理'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openNotificationsPanel();
              },
              child: const Text('查看所有任务'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadBadgeCount() async {
    try {
      final List<Task> tasks = await TaskService.getTasks();
      final myTasks = tasks.where((t) => t.assigneeId == widget.user.id || t.assigneeName == widget.user.name).toList();
      final count = myTasks.where((t) => (t.priority.toLowerCase() == 'p0' || t.priority.toLowerCase() == 'p1') && t.status != 'completed').length;
      if (mounted) {
        setState(() {
          _highPriorityPendingCount = count;
          _myAssignedTasks = myTasks;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _highPriorityPendingCount = 0;
          _myAssignedTasks = [];
        });
      }
    }
  }

  Future<void> _loadPreviewData() async {
    setState(() {
      _isLoadingPreview = true;
    });

    try {
      final results = await Future.wait([
        ApiService.getImportantItems(),
        TaskService.getTasks(),
        ApiService.getPersonalInfo(widget.user.id),
        ApiService.getPersonalLogs(widget.user.id),
        MbtiTestService.getUserLatestMbti(),
      ]);

      final importantItems = results[0] as List<ImportantItem>;
      final tasks = results[1] as List<Task>;
      final personalInfos = results[2] as List<PersonalInfo>;
      final personalLogs = results[3] as List<PersonalLog>;
      final latestMbti = results[4] as MbtiTestResult?;

      if (!mounted) return;
      setState(() {
        _companyImportantItems = importantItems
            .map((item) => item.title ?? '无标题')
            .take(3)
            .toList();

        _companyTasks = tasks
            .map((task) => task.title ?? '任务')
            .take(3)
            .toList();

        _personalImportantItems = personalInfos
            .map((info) => info.title ?? '无标题')
            .take(3)
            .toList();

        _personalLogs = personalLogs
            .map((log) {
              final title = log.title;
              final content = log.content;

              if (title != null && title.isNotEmpty) {
                return title;
              } else if (content != null) {
                return content;
              } else {
                return '个人日志';
              }
            })
            .take(3)
            .toList();


        _latestMbti = latestMbti;
        _personalPreviewItems = _buildPersonalPreview();
        _isLoadingPreview = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('加载预览数据出错: $e');
      // ignore: avoid_print
      print('加载预览数据出错: $e');
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎, ${widget.user.name}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '改变主题颜色',
            icon: const Icon(Icons.checkroom_outlined),
            onPressed: _openThemeColorPicker,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _openNotificationsPanel,
                ),
                if (_settings.notificationsEnabled && _unreadNotificationCount > 0)
                  Positioned(
                    right: 10,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 用户信息卡片 + Loopy 装扮展示
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                widget.user.name.isNotEmpty ? widget.user.name[0] : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.user.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.user.position,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    widget.user.department,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_settings.equippedLoopyAssetPath != null)
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.pinkAccent.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  _settings.equippedLoopyAssetPath!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 四个象限布局
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          // 左上：公司重要展示
                          QuadrantWidget(
                            title: '公司重要展示',
                            subtitle: '10大重要事项',
                            icon: Icons.business_center,
                            color: Colors.blue,
                            previewItems: _isLoadingPreview ? null : _companyImportantItems,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CompanyImportantScreen(user: widget.user),
                                ),
                              ).then((_) => _loadPreviewData()); // 返回时刷新数据
                            },
                          ),
                          // 右上：公司派发任务
                          QuadrantWidget(
                            title: '公司派发任务',
                            subtitle: '10大任务',
                            icon: Icons.assignment,
                            color: Colors.green,
                            previewItems: _isLoadingPreview ? null : _companyTasks,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CompanyTasksEnhancedScreen(user: widget.user),
                                ),
                              ).then((_) => _loadPreviewData()); // 返回时刷新数据
                            },
                          ),
                          // 左下：个人重要展示
                          QuadrantWidget(
                            title: '个人重要展示',
                            subtitle: '10大重要事项',
                            icon: Icons.person_pin,
                            color: Colors.orange,
                            previewItems: _isLoadingPreview
                                ? null
                                : (_personalPreviewItems.isNotEmpty
                                    ? _personalPreviewItems
                                    : _personalImportantItems),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PersonalResumeScreen(user: widget.user),
                                ),
                              ).then((_) => _loadPreviewData()); // 返回时刷新数据
                            },
                          ),
                          // 右下：个人日志
                          QuadrantWidget(
                            title: '个人日志',
                            icon: Icons.description,
                            color: Colors.purple,
                            previewItems: _isLoadingPreview ? null : _personalLogs,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LogEnhancedScreen(user: widget.user),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),




          Positioned(
            right: 24,
            bottom: 32,
            child: GestureDetector(
              onTap: _openPomodoroScreen,
              child: Container(
                width: 116,
                height: 132,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFF7A7A), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFEBEC),
                              border: Border.all(color: const Color(0xFFFFA8B4), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.alarm_rounded,
                            size: 32,
                            color: Color(0xFFFF6A88),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '番茄专注',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3C3C3C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildPersonalPreview() {
    final List<String> items = [];
    final profile = _latestMbti?.personalInfo ?? {};

    if (_latestMbti != null && _latestMbti!.mbtiType.isNotEmpty) {
      items.add('MBTI: ${_latestMbti!.mbtiType}');
    }

    final birthday = profile['birthday'];
    if (birthday != null && birthday.toString().isNotEmpty) {
      items.add('生日: $birthday');
    }

    final address = profile['address'];
    if (address != null && address.toString().isNotEmpty) {
      items.add('住址: $address');
    }

    if (!items.any((item) => item.startsWith('姓名'))) {
      items.add('姓名: ${widget.user.name}');
    }

    return items.take(3).toList();
  }

  void _openThemeColorPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final currentColor = _settings.themeColor;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择主题颜色',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _themeColorOptions.map((option) {
                  final bool isSelected = currentColor == option.color;
                  return GestureDetector(
                    onTap: () {
                      _settings.setThemeColor(option.color);
                      Navigator.of(context).pop();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.black54 : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: option.color.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '提示：选择后将同步刷新页眉、底部导航和关键标识颜色。',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNotificationsPanel() async {
    // 打开通知中心页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationCenterScreen(user: widget.user),
      ),
    ).then((_) {
      // 返回时刷新未读通知数量
      _loadUnreadNotificationCount();
    });
  }

  Future<void> _openTasksPanel() async {
    if (_myAssignedTasks.isEmpty) {
      await _loadBadgeCount();
    }
    if (!mounted) return;

    final pendingTasks = _myAssignedTasks
        .where((task) => task.status != 'completed')
        .toList();
    String keyword = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredTasks = pendingTasks
                .where((task) {
                  if (keyword.isEmpty) return true;
                  final haystack = [
                    task.title,
                    task.description,
                    task.assigneeName,
                    task.status,
                    task.department,
                  ].join(' ').toLowerCase();
                  return haystack.contains(keyword);
                })
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, controller) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            '任务提醒（${filteredTasks.length}/${pendingTasks.length}）',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              await _loadBadgeCount();
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              _openTasksPanel();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜索标题 / 描述 / 状态',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            keyword = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (filteredTasks.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              '当前没有满足条件的通知',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              final deadline = task.deadline ?? task.endTime ?? task.startTime;
                              final deadlineText = deadline != null
                                  ? DateFormat('MM-dd HH:mm').format(deadline.toLocal())
                                  : '未设置';
                              final createdLabel =
                                  DateFormat('MM-dd HH:mm').format(task.createdAt.toLocal());
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _priorityColor(task.priority).withOpacity(0.15),
                                    child: Icon(
                                      Icons.assignment,
                                      color: _priorityColor(task.priority),
                                    ),
                                  ),
                                  title: Text(task.title),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('通知时间：$createdLabel'),
                                      Text('截止：$deadlineText'),
                                      Text('状态：${_statusLabel(task.status)}'),
                                    ],
                                  ),
                                  trailing: Text(
                                    _priorityLabel(task.priority),
                                    style: TextStyle(
                                      color: _priorityColor(task.priority),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => TaskDetailScreen(
                                          task: task,
                                          currentUser: widget.user,
                                        ),
                                      ),
                                    );
                                    if (mounted) {
                                      await _loadBadgeCount();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openPomodoroScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PomodoroFocusScreen(user: widget.user),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'p0':
        return Colors.red;
      case 'p1':
        return Colors.orange;
      case 'p2':
        return Colors.blue;
      case 'p3':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'p0':
        return '重要且紧急';
      case 'p1':
        return '重要不紧急';
      case 'p2':
        return '紧急不重要';
      case 'p3':
        return '不重要不紧急';
      default:
        return priority.toUpperCase();
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }
}

class _ThemeColorOption {
  final String label;
  final Color color;
  const _ThemeColorOption({required this.label, required this.color});
}
