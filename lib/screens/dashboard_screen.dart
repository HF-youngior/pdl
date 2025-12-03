import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../widgets/quadrant_widget.dart';
import 'company_important_screen.dart';
import 'company_tasks_enhanced_screen.dart';
import 'personal_resume_screen.dart';
import 'log_enhanced_screen.dart';
import 'task_edit_screen.dart';
import '../services/app_settings.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';
import '../services/mbti_test_service.dart';
import '../models/task.dart';
import '../models/important_item.dart';
import '../models/personal_info.dart';
import '../models/personal_log.dart';
import '../models/mbti_test_result.dart';
import 'pomodoro_focus_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AppSettings _settings = AppSettings.instance;
  int _highPriorityPendingCount = 0;

  // 预览数据
  List<String> _companyImportantItems = [];
  List<String> _companyTasks = [];
  List<String> _personalImportantItems = [];
  List<String> _personalLogs = [];
  List<String> _personalPreviewItems = [];
  MbtiTestResult? _latestMbti;
  bool _isLoadingPreview = true;
  List<Task> _myAssignedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadBadgeCount();
    _loadPreviewData();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _openNotificationsPanel,
                ),
                if (_settings.notificationsEnabled && _highPriorityPendingCount > 0)
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
                        _highPriorityPendingCount > 99 ? '99+' : _highPriorityPendingCount.toString(),
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
                    // 用户信息卡片
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
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

  Future<void> _openNotificationsPanel() async {
    if (_myAssignedTasks.isEmpty) {
      await _loadBadgeCount();
    }
    if (!mounted) return;

    final pendingTasks = _myAssignedTasks
        .where((task) => task.status != 'completed')
        .toList()
      ..sort((a, b) {
        DateTime? aDeadline = a.deadline ?? a.endTime ?? a.startTime;
        DateTime? bDeadline = b.deadline ?? b.endTime ?? b.startTime;
        if (aDeadline != null && bDeadline != null) {
          return aDeadline.compareTo(bDeadline);
        }
        if (aDeadline != null) return -1;
        if (bDeadline != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
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
                        '任务提醒（${pendingTasks.length}）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          await _loadBadgeCount();
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          _openNotificationsPanel();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (pendingTasks.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          '当前没有需要处理的任务',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: pendingTasks.length,
                        itemBuilder: (context, index) {
                          final task = pendingTasks[index];
                          final deadline = task.deadline ?? task.endTime ?? task.startTime;
                          final deadlineText = deadline != null
                              ? DateFormat('MM-dd HH:mm').format(deadline.toLocal())
                              : '未设置';
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
