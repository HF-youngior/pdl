import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart' show TaskNotification;
import '../models/user.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../utils/time_utils.dart';
import 'task_detail_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  final User user;

  const NotificationCenterScreen({super.key, required this.user});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<TaskNotification> _notifications = [];
  List<TaskNotification> _filteredNotifications = [];
  bool _isLoading = true;
  String _error = '';
  
  // 筛选条件
  String? _selectedType; // null表示全部类型
  bool? _selectedReadStatus; // null表示全部，true表示已读，false表示未读
  DateTime? _selectedDate; // 选择的日期（只查看某一天的通知）
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final notifications = await NotificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<TaskNotification> filtered = List.from(_notifications);

    // 按类型筛选
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered.where((n) => n.notificationType == _selectedType).toList();
    }

    // 按已读状态筛选
    if (_selectedReadStatus != null) {
      filtered = filtered.where((n) => n.isRead == _selectedReadStatus).toList();
    }

    // 按日期筛选（只查看某一天的通知，使用北京时间）
    if (_selectedDate != null) {
      filtered = filtered.where((n) {
        // createdAt已经是北京时间（在fromJson中已处理），直接提取日期部分
        final notificationDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
        final selectedDateOnly = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        return notificationDate.isAtSameMomentAs(selectedDateOnly);
      }).toList();
    }

    // 按关键词搜索
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((n) {
        return (n.message.toLowerCase().contains(keyword) ||
                (n.taskTitle != null && n.taskTitle!.toLowerCase().contains(keyword)) ||
                (n.fromUserName != null && n.fromUserName!.toLowerCase().contains(keyword)));
      }).toList();
    }

    setState(() {
      _filteredNotifications = filtered;
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    final success = await NotificationService.markAsRead(notificationId);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = TaskNotification(
            id: _notifications[index].id,
            taskId: _notifications[index].taskId,
            fromUserId: _notifications[index].fromUserId,
            toUserId: _notifications[index].toUserId,
            notificationType: _notifications[index].notificationType,
            message: _notifications[index].message,
            isRead: true,
            createdAt: _notifications[index].createdAt,
            taskTitle: _notifications[index].taskTitle,
            fromUserName: _notifications[index].fromUserName,
          );
        }
      });
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final success = await NotificationService.deleteNotification(notificationId);
    if (success) {
      setState(() {
        _notifications.removeWhere((n) => n.id == notificationId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知已删除')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除通知失败')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    for (final notification in _notifications.where((n) => !n.isRead)) {
      await NotificationService.markAsRead(notification.id);
    }
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全部已读')),
      );
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除所有通知吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int successCount = 0;
      int failCount = 0;
      for (final notification in _notifications) {
        final success = await NotificationService.deleteNotification(notification.id);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? '已删除 $successCount 条通知，$failCount 条删除失败'
                  : '已删除 $successCount 条通知',
            ),
          ),
        );
      }
    }
  }

  Future<void> _viewNotificationDetail(TaskNotification notification) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_getNotificationTitle(notification.notificationType)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 8),
                Text(
                  '时间：${TimeUtils.formatDateTimeWithZone(notification.createdAt, includeSeconds: true)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (notification.fromUserName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '来自：${notification.fromUserName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                if (_notifications.any((n) => !n.isRead))
                  PopupMenuItem(
                    child: const Text('全部已读'),
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        _markAllAsRead();
                      });
                    },
                  ),
                PopupMenuItem(
                  child: const Text('删除全部', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      _deleteAllNotifications();
                    });
                  },
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('加载失败: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 筛选栏
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: Column(
                        children: [
                          // 搜索框
                          TextField(
                            decoration: InputDecoration(
                              hintText: '搜索通知内容、任务标题、发送人',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchKeyword.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchKeyword = '';
                                          _applyFilters();
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchKeyword = value;
                                _applyFilters();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          // 筛选按钮行
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: '通知类型',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('全部类型')),
                                    const DropdownMenuItem(value: 'task_assigned', child: Text('新任务')),
                                    const DropdownMenuItem(value: 'deadline_warning', child: Text('截止时间提醒')),
                                    const DropdownMenuItem(value: 'task_progress_update', child: Text('任务进度更新')),
                                    const DropdownMenuItem(value: 'task_completed', child: Text('任务完成')),
                                    const DropdownMenuItem(value: 'task_cancelled', child: Text('任务取消')),
                                    const DropdownMenuItem(value: 'special_notes', child: Text('特殊备注')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<bool?>(
                                  value: _selectedReadStatus,
                                  decoration: InputDecoration(
                                    labelText: '已读状态',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('全部')),
                                    DropdownMenuItem(value: false, child: Text('未读')),
                                    DropdownMenuItem(value: true, child: Text('已读')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedReadStatus = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 日期筛选（只查看某一天的通知）
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _selectedDate = date;
                                        _applyFilters();
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedDate != null
                                              ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                                              : '选择日期',
                                          style: TextStyle(
                                            color: _selectedDate != null ? Colors.black : Colors.grey,
                                          ),
                                        ),
                                        if (_selectedDate != null)
                                          IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              setState(() {
                                                _selectedDate = null;
                                                _applyFilters();
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.filter_alt_off),
                                tooltip: '清除筛选',
                                onPressed: () {
                                  setState(() {
                                    _selectedType = null;
                                    _selectedReadStatus = null;
                                    _selectedDate = null;
                                    _searchKeyword = '';
                                    _applyFilters();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 通知列表
                    Expanded(
                      child: _filteredNotifications.isEmpty
                          ? const Center(child: Text('暂无通知'))
                          : RefreshIndicator(
                              onRefresh: _loadNotifications,
                              child: ListView.builder(
                                itemCount: _filteredNotifications.length,
                                itemBuilder: (context, index) {
                                  final notification = _filteredNotifications[index];
                                  return Dismissible(
                                    key: Key(notification.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.red,
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    onDismissed: (direction) {
                                      _deleteNotification(notification.id);
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: notification.isRead ? null : Colors.blue.shade50,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: notification.isRead
                                              ? Colors.grey
                                              : Colors.blue,
                                          child: Icon(
                                            _getNotificationIcon(notification.notificationType),
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          notification.taskTitle ?? _getNotificationTitle(notification.notificationType),
                                          style: TextStyle(
                                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              notification.message,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              TimeUtils.formatDateTimeWithZone(notification.createdAt),
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              color: Colors.red,
                                              tooltip: '删除',
                                              onPressed: () {
                                                _deleteNotification(notification.id);
                                              },
                                            ),
                                            PopupMenuButton(
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  child: const Text('查看详情'),
                                                  onTap: () {
                                                    Future.delayed(Duration.zero, () {
                                                      _viewNotificationDetail(notification);
                                                    });
                                                  },
                                                ),
                                                if (!notification.isRead)
                                                  PopupMenuItem(
                                                    child: const Text('标记为已读'),
                                                    onTap: () {
                                                      _markAsRead(notification.id);
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          _viewNotificationDetail(notification);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  IconData _getNotificationIcon(String notificationType) {
    switch (notificationType) {
      case 'task_assigned':
        return Icons.assignment;
      case 'deadline_warning':
        return Icons.warning;
      case 'task_progress_update':
        return Icons.trending_up;
      case 'task_completed':
        return Icons.check_circle;
      case 'task_cancelled':
        return Icons.cancel;
      case 'special_notes':
        return Icons.note;
      default:
        return Icons.notifications;
    }
  }
}

