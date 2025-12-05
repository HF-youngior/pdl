import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/task_service.dart';

enum _PomodoroState { idle, running, paused }

class PomodoroFocusScreen extends StatefulWidget {
  final User user;

  const PomodoroFocusScreen({super.key, required this.user});

  @override
  State<PomodoroFocusScreen> createState() => _PomodoroFocusScreenState();
}

class _PomodoroFocusScreenState extends State<PomodoroFocusScreen> {
  /// 安卓原生强制锁机通道（屏幕固定 / App Pinning）
  static const MethodChannel platform =
      MethodChannel('com.example.testflutterproject/lock_task');

  static const String _customFocusPrefix = 'custom::';
  static const Map<String, String> _immersionBackgrounds = {
    '等我下班': 'assets/images/focus/linyi.jpg',
    '陪我上班': 'assets/images/focus/txt.jpg',
    '度假欧洲': 'assets/images/focus/grass.jpg',
    '飞离工位': 'assets/images/focus/paraglider.jpg',
  };
  final List<Task> _tasks = [];
  String? _selectedTaskId;
  String _focusTitle = '选择专注计划';
  Duration _initialDuration = const Duration(minutes: 55);
  Duration _remaining = const Duration(minutes: 55);
  Timer? _timer;
  _PomodoroState _state = _PomodoroState.idle;
  bool _isLoadingTasks = true;
  bool _isSyncingFocusDuration = false;
  bool _hasActiveSession = false;
  final List<String> _customFocusOptions = [];
  final List<String> _immersionOptions = _immersionBackgrounds.keys.toList();
  bool _isFunImmersionActive = false;
  double _funExitProgress = 0;
  Timer? _funExitTimer;
  String? _selectedImmersionOption;
  bool _isForcedLockActive = false; // 当前是否处于强制锁机模式
  // 协同专注相关
  List<User> _availableUsers = []; // 可邀请的用户列表（同级和下级）
  bool _isLoadingUsers = false; // 是否正在加载用户列表
  Set<String> _selectedUserIds = {}; // 选中的用户ID集合

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _validateImagePaths();
  }

  /// 验证图片路径配置
  void _validateImagePaths() {
    debugPrint("🔍 验证沉浸模式图片路径配置:");
    _immersionBackgrounds.forEach((key, path) {
      debugPrint("   $key -> $path");
    });
    debugPrint("✅ 路径验证完成");
  }

  @override
  void dispose() {
    _timer?.cancel();
    _funExitTimer?.cancel();
    // 兜底解锁，防止异常情况下仍处于锁机模式
    _unlockScreen();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
    });
    try {
      final allTasks = await TaskService.getTasks();
      final myTasks = allTasks
          .where((task) =>
      task.assigneeId == widget.user.id ||
          task.assigneeName == widget.user.name)
          .toList();
      setState(() {
        _tasks
          ..clear()
          ..addAll(myTasks);
        _isLoadingTasks = false;
      });
    } catch (_) {
      setState(() {
        _tasks.clear();
        _isLoadingTasks = false;
      });
    }
  }

  void _startTimer() {
    if (_remaining.inSeconds == 0) return;
    _timer?.cancel();
    setState(() {
      _state = _PomodoroState.running;
    });
    _hasActiveSession = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
          _state = _PomodoroState.idle;
        });
        await _recordFocusDuration();
        if (!mounted) return;
        _showCompletionDialog();
      } else {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _state = _PomodoroState.paused);
  }

  void _resumeTimer() {
    if (_remaining.inSeconds == 0) {
      setState(() => _state = _PomodoroState.idle);
      return;
    }
    _startTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _initialDuration;
      _state = _PomodoroState.idle;
    });
    _hasActiveSession = false;
  }

  Future<void> _pickDuration() async {
    Duration tempDuration = _initialDuration;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '设置专注时长',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: _initialDuration,
                    minuteInterval: 5,
                    onTimerDurationChanged: (duration) {
                      tempDuration = duration;
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('确认'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (tempDuration.inSeconds > 0) {
      setState(() {
        _initialDuration = tempDuration;
        _remaining = tempDuration;
        _state = _PomodoroState.idle;
      });
      _hasActiveSession = false;
    }
  }

  Future<void> _editFocusTitle() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('自定义专注计划'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入专注任务名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    final trimmed = result?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      setState(() {
        if (!_customFocusOptions.contains(trimmed)) {
          _customFocusOptions.insert(0, trimmed);
        }
        _focusTitle = trimmed;
        _selectedTaskId = _customOptionValue(trimmed);
      });
    }
  }

  Future<bool> _confirmQuit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('结束专注'),
          content: const Text('确定要结束专注并返回主页吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('结束'),
            ),
          ],
        );
      },
    ) ??
        false;
    return shouldExit;
  }

  Future<void> _showCompletionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('太棒了！'),
        content: Text('你完成了 $_focusTitle 专注。要继续下一轮吗？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetTimer();
              _unlockScreen(); // 完成本轮后解除强制锁机（如果正在锁机）
            },
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 一轮已经自然结束，这里也先解除强制锁机，再按正常模式开启新一轮
              _unlockScreen();
              _resetTimer();
              _startTimer();
            },
            child: const Text('再来一轮'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 当处于锁机状态时，禁止页面被系统 Pop（物理返回键 / 手势返回）
      canPop: !_isForcedLockActive,
      onPopInvoked: (didPop) {
        if (_isForcedLockActive) {
          // 已经被我们拦截，不允许退出，只给一个提示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前为强制锁机专注中，无法返回')),
          );
          return;
        }
      },
      child: WillPopScope(
        onWillPop: () async {
          // 非锁机状态下，保持原有“是否结束专注”的确认弹窗逻辑
          if (_state == _PomodoroState.idle) return true;
          final exit = await _confirmQuit();
          if (exit) {
            await _recordFocusDuration();
            _resetTimer();
          }
          return exit;
        },
        child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF5F2), Color(0xFFE7F4FF)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                            _buildHeaderCard(context),
                            const SizedBox(height: 20),
                            _buildTopButtons(),
                            const SizedBox(height: 24),
                            _buildTaskSelectorCard(),
                            const SizedBox(height: 28),
                            _buildTimerSection(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _buildControlButtons(),
                    ),
                  ],
                ),
              ),
            ),
            if (_isFunImmersionActive) _buildFunImmersionLayer(),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9A8B), Color(0xFFFFC3A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9A8B).withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
                  children: [
                    Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                        '番茄专注',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 6),
                Text(
                  '你好，${widget.user.name}，今天也要好好专注哦～',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _state == _PomodoroState.running
                            ? '正在专注 $_focusTitle'
                            : '准备开始新一轮',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: _handleClose,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButtons() {
    final items = [
      {
        'label': '协同专注',
        'icon': Icons.groups_2_rounded,
        'color': const Color(0xFFFFB347),
      },
      {
        'label': '强制锁机',
        'icon': Icons.lock_clock_rounded,
        'color': const Color(0xFF7A7CFF),
      },
      {
        'label': '趣味沉浸',
        'icon': Icons.videogame_asset,
        'color': const Color(0xFF48C9B0),
      },
    ];
    return Row(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final Color itemColor = (item['color'] is Color)
            ? item['color'] as Color
            : Colors.orange;
        final IconData itemIcon = (item['icon'] is IconData)
            ? item['icon'] as IconData
            : Icons.circle;
        final String label = item['label']?.toString() ?? '';
        final String desc = item['desc']?.toString() ?? '';
        return Expanded(
          child: InkWell(
            onTap: label == '趣味沉浸'
                ? () {
                    // 强制锁机状态下禁止进入趣味沉浸
                    if (_isForcedLockActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('当前为强制锁机模式，无法进入趣味沉浸')),
                      );
                      return;
                    }
                    _showImmersionPicker();
                  }
                : label == '协同专注'
                    ? _handleCollaborativeFocusTap
                    : label == '强制锁机'
                        ? _handleForceLockTap
                        : null,
            borderRadius: BorderRadius.circular(22),
          child: Container(
              height: 110,
            margin: EdgeInsets.only(right: index == items.length - 1 ? 0 : 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      itemIcon,
                      color: itemColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTaskSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
              const Text(
                '选择专注任务',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (_selectedTaskId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _focusTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEC5B72),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingTasks
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                : DropdownButtonFormField<String>(
                  value: _isSelectionAvailable(_selectedTaskId) ? _selectedTaskId : null,
              isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    ..._tasks.map(
                    (task) => DropdownMenuItem<String>(
                  value: task.id,
                  child: Text(
                    task.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                    ),
                    ..._customFocusOptions.map(
                      (label) => DropdownMenuItem<String>(
                        value: _customOptionValue(label),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFA07A), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
              onChanged: (value) {
                setState(() {
                  _selectedTaskId = value;
                      if (value == null) return;
                      if (_isCustomValue(value)) {
                        _focusTitle = _labelFromCustomValue(value);
                      } else {
                        final task = _findTaskById(value);
                        if (task != null) {
                          _focusTitle = task.title;
                        }
                  }
                });
              },
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _editFocusTitle,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('自定义专注标题'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.6;
    final indicatorLevel = () {
      switch (_state) {
        case _PomodoroState.idle:
          return 1;
        case _PomodoroState.running:
          return 3;
        case _PomodoroState.paused:
          return 2;
      }
    }();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.85),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
          onTap: () {
            // 在强制锁机或趣味沉浸中，禁止修改已经开始的倒计时时间
            if (_isForcedLockActive || _isFunImmersionActive) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前模式下无法修改倒计时时长')),
              );
              return;
            }
            _pickDuration();
          },
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFF4F4), Color(0xFFFFD6D6)],
                  center: Alignment(0, -0.15),
                  radius: 0.95,
                ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFF8A94).withOpacity(0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFF9A8B).withOpacity(0.5), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                  _focusTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444444),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 18),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                      fontSize: 52,
                    fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    letterSpacing: 2,
                  ),
                ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < indicatorLevel
                              ? const Color(0xFFFF6A88)
                              : const Color(0xFFFFC1C9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                Text(
                  _state == _PomodoroState.running
                      ? '正在专注...'
                      : _state == _PomodoroState.paused
                            ? '短暂休息，继续加油'
                      : '轻触设置时长',
                    style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, size: 18, color: Color(0xFFFF6A88)),
              const SizedBox(width: 6),
              Text(
                '默认 ${_initialDuration.inMinutes} 分钟，可点击上方调整',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    switch (_state) {
      case _PomodoroState.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPrimaryButton('开始专注', const Color(0xFFFF6A88), _startTimer),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _showInviteDialog,
              child: const Text(
                '邀请伙伴陪我专注',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A7CFF),
                ),
              ),
            ),
          ],
        );
      case _PomodoroState.running:
        return _buildPrimaryButton('暂停一下', const Color(0xFFFFA07A), _pauseTimer);
      case _PomodoroState.paused:
        // 如果处于强制锁机模式：只能“继续专注”，不允许结束本轮
        if (_isForcedLockActive) {
          return _buildPrimaryButton('继续专注（锁机中）', const Color(0xFFFF6A88), _resumeTimer);
        }
        // 普通暂停状态：可以结束本轮或继续
        return Row(
          children: [
            Expanded(
              child: _buildPrimaryButton('结束本轮', Colors.grey.shade400, () async {
                final confirm = await _confirmStopDialog();
                if (confirm) {
                  _resetTimer();
                  await _unlockScreen(); // 结束本轮时如果在锁机，则一并解除
                  if (mounted) Navigator.of(context).pop();
                }
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrimaryButton('继续专注', const Color(0xFFFF6A88), _resumeTimer),
            ),
          ],
        );
    }
  }

  Future<bool> _confirmStopDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束专注'),
        content: const Text('确定要结束当前专注吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    ) ??
        false;
    return result;
  }

  Widget _buildPrimaryButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: color,
          shadowColor: color.withOpacity(0.35),
          elevation: 8,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _handleClose() async {
    // 在强制锁机模式下，关闭按钮无效，避免用户借此退出界面
    if (_isForcedLockActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前为强制锁机专注中，无法退出')),
        );
      }
      return;
    }
    final exit = await _confirmQuit();
    if (exit && mounted) {
      await _recordFocusDuration();
      _resetTimer();
      Navigator.of(context).pop();
    }
  }

  Future<void> _recordFocusDuration() async {
    if (!_hasActiveSession || _isSyncingFocusDuration) return;
    final seconds = _currentSessionSeconds();
    if (seconds <= 0) {
      _hasActiveSession = false;
      return;
    }
    _isSyncingFocusDuration = true;
    try {
      await ApiService.addFocusDuration(seconds);
    } catch (e) {
      debugPrint('记录专注时长失败: $e');
    } finally {
      _isSyncingFocusDuration = false;
      _hasActiveSession = false;
    }
  }

  int _currentSessionSeconds() {
    final spent = _initialDuration.inSeconds - _remaining.inSeconds;
    if (spent <= 0) return 0;
    if (spent > _initialDuration.inSeconds) {
      return _initialDuration.inSeconds;
    }
    return spent;
  }

  String _customOptionValue(String label) => '$_customFocusPrefix$label';

  bool _isCustomValue(String? value) => value != null && value.startsWith(_customFocusPrefix);

  String _labelFromCustomValue(String value) => value.replaceFirst(_customFocusPrefix, '');

  bool _isSelectionAvailable(String? value) {
    if (value == null) return true;
    if (_isCustomValue(value)) {
      return _customFocusOptions.contains(_labelFromCustomValue(value));
    }
    return _tasks.any((task) => task.id == value);
  }

  Task? _findTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (_) {
      return null;
    }
  }

  /// ================== 强制锁机相关 ==================

  /// 开启屏幕固定（App Pinning）
  Future<void> _lockScreen() async {
    try {
      await platform.invokeMethod('startLockTask');
      setState(() {
        _isForcedLockActive = true;
      });
      debugPrint('✅ 已进入强制锁机模式');
    } catch (e) {
      debugPrint('❌ 启动强制锁机失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法启用强制锁机：$e')),
        );
      }
    }
  }

  /// 关闭屏幕固定（App Pinning）
  Future<void> _unlockScreen() async {
    if (!_isForcedLockActive) return;
    try {
      await platform.invokeMethod('stopLockTask');
    } catch (e) {
      debugPrint('❌ 关闭强制锁机失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isForcedLockActive = false;
        });
      } else {
        _isForcedLockActive = false;
      }
      debugPrint('✅ 已退出强制锁机模式');
    }
  }

  /// 点击“强制锁机”入口
  Future<void> _handleForceLockTap() async {
    if (_isForcedLockActive) {
      // 已在锁机模式下，避免重复调用
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已在强制锁机专注中')),
        );
      }
      return;
    }

    // 如果当前没有在计时，则按当前设定时间开始一轮专注
    if (_state != _PomodoroState.running) {
      if (!_hasActiveSession) {
        _remaining = _initialDuration;
      }
      _startTimer();
    }

    await _lockScreen();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已开启强制锁机专注，期间无法返回其他界面')),
      );
    }
  }

  void _showImmersionPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '选择趣味沉浸主题',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ..._immersionOptions.map(
                (option) => ListTile(
                  title: Text(option),
                  trailing: option == _selectedImmersionOption
                      ? const Icon(Icons.check, color: Colors.teal)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleImmersionSelection(option);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _handleImmersionSelection(String option) {
    debugPrint("🎯 选择沉浸模式: $option");
    debugPrint("📋 可用选项: ${_immersionBackgrounds.keys.toList()}");
    
    if (_immersionBackgrounds.containsKey(option)) {
      final path = _immersionBackgrounds[option];
      debugPrint("✅ 找到对应路径: $path");
      
      setState(() {
        _selectedImmersionOption = option;
        _isFunImmersionActive = true;
        _funExitProgress = 0;

        if (_state != _PomodoroState.running) {
          if (!_hasActiveSession) {
            _remaining = _initialDuration;
          }
          _startTimer();
        }
      });
    } else {
      debugPrint("❌ 未找到选项: $option");
      setState(() {
        _selectedImmersionOption = option;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$option" 主题即将上线，敬请期待～')),
        );
      }
    }
  }

  Widget _buildFunImmersionLayer() {
    final option = _selectedImmersionOption ?? '等我下班';
    // 安全获取路径，确保不会为 null
    String? backgroundPath = _immersionBackgrounds[option];
    if (backgroundPath == null) {
      backgroundPath = _immersionBackgrounds['等我下班'];
    }
    // 如果还是没有，使用默认值
    backgroundPath ??= 'assets/images/focus/linyi.jpg';
    
    // 打印调试信息
    debugPrint("🎨 沉浸模式 - 选项: $option, 路径: $backgroundPath");
    debugPrint("📋 可用选项: ${_immersionBackgrounds.keys.toList()}");
    debugPrint("📋 可用路径: ${_immersionBackgrounds.values.toList()}");

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: _handleFunImmersionLongPressStart,
          onLongPressEnd: (_) => _cancelFunImmersionExitCountdown(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                backgroundPath, // 与 pubspec.yaml 中的英文名称保持一致
                fit: BoxFit.cover,
                // 添加 package 参数（如果需要，但通常主包不需要）
                // package: null, // 主包不需要 package 参数
                errorBuilder: (context, error, stackTrace) {
                  // 详细的错误信息
                  debugPrint("❌ 图片加载失败!");
                  debugPrint("   路径: $backgroundPath");
                  debugPrint("   选项: $option");
                  debugPrint("   错误: $error");
                  debugPrint("   堆栈: $stackTrace");
                  debugPrint("   可用路径列表:");
                  _immersionBackgrounds.forEach((key, value) {
                    debugPrint("     - $key: $value");
                  });
                  
                  return Container(
                    color: Colors.red,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "图片加载失败",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "路径: $backgroundPath",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "错误: ${error.toString()}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                color: Colors.black.withOpacity(0.1),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '沉浸专注中 · $option',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _formatDuration(_remaining),
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 80,
                      fontWeight: FontWeight.w100,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, 4))
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _funExitProgress > 0 ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        const Text(
                          '长按屏幕 5 秒退出',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        if (_funExitProgress > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 120,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: _funExitProgress.clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFunImmersionLongPressStart(LongPressStartDetails details) {
    _funExitTimer?.cancel();
    setState(() {
      _funExitProgress = 0;
    });
    const totalMillis = 5000;
    const tick = Duration(milliseconds: 100);
    int elapsed = 0;
    _funExitTimer = Timer.periodic(tick, (timer) {
      elapsed += tick.inMilliseconds;
      setState(() {
        _funExitProgress = elapsed / totalMillis;
      });
      if (elapsed >= totalMillis) {
        timer.cancel();
        _exitFunImmersionMode();
      }
    });
  }

  void _cancelFunImmersionExitCountdown() {
    if (!_isFunImmersionActive) return;
    _funExitTimer?.cancel();
    setState(() {
      _funExitProgress = 0;
    });
  }

  void _exitFunImmersionMode() {
    _funExitTimer?.cancel();
    _timer?.cancel();
    setState(() {
      _funExitProgress = 0;
      _isFunImmersionActive = false;
      _selectedImmersionOption = null;
      _state = _PomodoroState.paused;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已退出趣味沉浸模式')),
      );
    }
  }

  /// ================== 协同专注相关 ==================

  /// 角色等级函数（用于判断用户层级关系）
  int _roleRank(String role) {
    switch (role) {
      case 'founder':
      case 'admin':
        return 5;
      case 'department_head':
        return 4;
      case 'team_leader':
        return 3;
      case 'employee':
      default:
        return 1;
    }
  }

  /// 加载可邀请的用户列表（同级和下级）
  Future<void> _loadAvailableUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await ApiService.getUsers();
      final currentUser = widget.user;
      final currentUserRank = _roleRank(currentUser.role);

      // 筛选同级或下级用户
      final filteredUsers = users.where((user) {
        // 排除自己
        if (user.id == currentUser.id) {
          return false;
        }
        
        // 同级：parent_id 相同且不为 null
        final isPeer = currentUser.parentId != null && 
                       user.parentId == currentUser.parentId;
        
        // 下级：parent_id 指向当前用户
        final isDirectSubordinate = user.parentId == currentUser.id;
        
        // 间接下级：同部门且角色等级更低
        final userRank = _roleRank(user.role);
        final isIndirectSubordinate = userRank < currentUserRank && 
                                      user.departmentId != null &&
                                      currentUser.departmentId != null &&
                                      user.departmentId == currentUser.departmentId;

        return isPeer || isDirectSubordinate || isIndirectSubordinate;
      }).toList();

      setState(() {
        _availableUsers = filteredUsers;
        _isLoadingUsers = false;
      });
    } catch (e) {
      debugPrint('加载用户列表失败: $e');
      setState(() {
        _isLoadingUsers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户列表失败: $e')),
        );
      }
    }
  }

  /// 显示“陪我专注”弹窗（多选用户邀请）
  void _showInviteDialog() {
    // 强制锁机状态下禁止协同专注
    if (_isForcedLockActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前为强制锁机模式，无法使用协同专注')),
      );
      return;
    }

    _loadAvailableUsers().then((_) {
      if (!mounted) return;

      // 打开弹窗时清空上次的选择
      _selectedUserIds.clear();

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '邀请伙伴陪你专注',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '发送通知：xxx要开始专注了，你还在摸鱼吗？',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        if (_isLoadingUsers)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_availableUsers.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                '暂无可邀请的用户',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: _availableUsers.length,
                              itemBuilder: (context, index) {
                                final user = _availableUsers[index];
                                final isSelected = _selectedUserIds.contains(user.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(user.name),
                                  subtitle: Text('${user.position} · ${user.department}'),
                                  activeColor: const Color(0xFF7A7CFF),
                                  onChanged: (checked) {
                                    setModalState(() {
                                      if (checked == true) {
                                        _selectedUserIds.add(user.id);
                                      } else {
                                        _selectedUserIds.remove(user.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _selectedUserIds.isEmpty
                                ? null
                                : () {
                                    Navigator.of(ctx).pop();
                                    _sendInviteNotifications();
                                  },
                            child: Text(
                              _selectedUserIds.isEmpty
                                  ? '请选择要邀请的伙伴'
                                  : '发送通知 (${_selectedUserIds.length})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  /// 发送“陪我专注”通知
  Future<void> _sendInviteNotifications() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一位用户')),
      );
      return;
    }

    final currentUser = widget.user;
    final success = await ApiService.inviteFocus(
      senderId: currentUser.id,
      senderName: currentUser.name,
      targetUserIds: _selectedUserIds.toList(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已向 ${_selectedUserIds.length} 位用户发送“陪我专注”通知'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedUserIds.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('通知发送失败，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 处理"协同专注"按钮点击
  void _handleCollaborativeFocusTap() {
    // 强制锁机状态下禁止协同专注
    if (_isForcedLockActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前为强制锁机模式，无法使用协同专注')),
      );
      return;
    }
    _showInviteDialog();
  }
}

