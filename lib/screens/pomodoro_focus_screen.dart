import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';

enum _PomodoroState { idle, running, paused }

class PomodoroFocusScreen extends StatefulWidget {
  final User user;

  const PomodoroFocusScreen({super.key, required this.user});

  @override
  State<PomodoroFocusScreen> createState() => _PomodoroFocusScreenState();
}

class _PomodoroFocusScreenState extends State<PomodoroFocusScreen> {
  final List<Task> _tasks = [];
  String? _selectedTaskId;
  String _focusTitle = '选择专注计划';
  Duration _initialDuration = const Duration(minutes: 55);
  Duration _remaining = const Duration(minutes: 55);
  Timer? _timer;
  _PomodoroState _state = _PomodoroState.idle;
  bool _isLoadingTasks = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
          _state = _PomodoroState.idle;
        });
        _showCompletionDialog();
      } else {
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
    }
  }

  Future<void> _editFocusTitle() async {
    final controller = TextEditingController(text: _focusTitle);
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
    if (result != null && result.isNotEmpty) {
      setState(() {
        _focusTitle = result;
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
            },
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
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
    final backgroundColor = const Color(0xFFEAF6FF);
    return WillPopScope(
      onWillPop: () async {
        if (_state == _PomodoroState.idle) return true;
        final exit = await _confirmQuit();
        if (exit) {
          _resetTimer();
        }
        return exit;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '番茄专注',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '结束专注',
                      onPressed: () async {
                        final exit = await _confirmQuit();
                        if (exit) {
                          if (!mounted) return;
                          _resetTimer();
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.close_rounded, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTopButtons(),
                const SizedBox(height: 24),
                _buildTaskSelectorCard(),
                const SizedBox(height: 32),
                _buildTimerSection(),
                const Spacer(),
                _buildControlButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButtons() {
    final items = [
      {'label': '协同专注', 'icon': Icons.groups_2_rounded, 'color': Colors.orange},
      {'label': '强制锁机', 'icon': Icons.lock_clock_rounded, 'color': Colors.indigo},
      {'label': '趣味沉浸', 'icon': Icons.videogame_asset, 'color': Colors.green},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Expanded(
          child: Container(
            height: 70,
            margin: EdgeInsets.only(right: index == items.length - 1 ? 0 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color),
                const SizedBox(height: 6),
                Text(
                  item['label'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTaskSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _isLoadingTasks
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : DropdownButtonFormField<String>(
              value: _selectedTaskId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: '选择专注任务',
                labelStyle: TextStyle(fontSize: 14),
              ),
              items: _tasks
                  .map(
                    (task) => DropdownMenuItem<String>(
                  value: task.id,
                  child: Text(
                    task.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTaskId = value;
                  if (value != null) {
                    _focusTitle = _tasks.firstWhere((t) => t.id == value).title;
                  }
                });
              },
            ),
          ),
          IconButton(
            tooltip: '编辑专注名称',
            onPressed: _editFocusTitle,
            icon: const Icon(Icons.edit, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.6;
    return Column(
      children: [
        GestureDetector(
          onTap: _pickDuration,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(color: Colors.black.withOpacity(0.05), width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _focusTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _state == _PomodoroState.running
                      ? '正在专注...'
                      : _state == _PomodoroState.paused
                      ? '已暂停'
                      : '轻触设置时长',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildControlButtons() {
    switch (_state) {
      case _PomodoroState.idle:
        return _buildPrimaryButton('开始专注', Colors.redAccent, _startTimer);
      case _PomodoroState.running:
        return _buildPrimaryButton('暂停', Colors.deepOrange, _pauseTimer);
      case _PomodoroState.paused:
        return Row(
          children: [
            Expanded(
              child: _buildPrimaryButton('结束', Colors.grey, () async {
                final confirm = await _confirmStopDialog();
                if (confirm) {
                  _resetTimer();
                  if (mounted) Navigator.of(context).pop();
                }
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrimaryButton('继续', Colors.redAccent, _resumeTimer),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: color,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

