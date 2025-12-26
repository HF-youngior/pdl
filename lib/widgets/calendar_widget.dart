import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../models/log_task_update.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/calendar_service.dart';
import '../services/geocoding_service.dart';
import '../services/task_service.dart';
import '../utils/time_utils.dart';

enum CalendarView { month, week, day }

class CalendarWidget extends StatefulWidget {
  final List<Task> tasks;
  final DateTime currentDate;
  final Function(DateTime) onDateSelected;
  final Function(Task) onTaskSelected;
  final Function(DateTime) onTaskAdd;
  final Function(DateTime) onLogAdd;
  // 提供刷新回调给父组件（用于页眉右侧的刷新按钮）
  final void Function(VoidCallback refresh)? onProvideRefresh;
  // 提供日期选择回调给父组件（用于页眉右侧跳转按钮）
  final void Function(VoidCallback openDateSelector)? onProvideDateSelector;

  const CalendarWidget({
    super.key,
    required this.tasks,
    required this.currentDate,
    required this.onDateSelected,
    required this.onTaskSelected,
    required this.onTaskAdd,
    required this.onLogAdd,
    this.onProvideRefresh,
    this.onProvideDateSelector,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarView _currentView = CalendarView.month;
  DateTime _currentDate = TimeUtils.getSystemTime();
  MonthViewData? _monthViewData;
  Map<String, DayDetailData> _weekViewData = {}; // 周视图数据
  DayDetailData? _dayViewData; // 日视图数据
  bool _isLoading = false;
  String? _error;

  // 任务筛选状态
  String _taskFilter = 'all'; // 'all', 'completed', 'pending'

  @override
  void initState() {
    super.initState();
    _currentDate = widget.currentDate;
    _loadMonthViewData();
    // 将刷新方法暴露给父组件（用于页眉右侧刷新按钮）
    if (widget.onProvideRefresh != null) {
      widget.onProvideRefresh!.call(_refreshCurrentView);
    }
    // 将日期选择方法暴露给父组件（用于页眉右侧跳转按钮）
    if (widget.onProvideDateSelector != null) {
      widget.onProvideDateSelector!.call(_openCurrentDateSelector);
    }
  }

  @override
  void didUpdateWidget(CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDate != widget.currentDate) {
      _currentDate = widget.currentDate;
    }
  }

  void _changeView(CalendarView view) {
    setState(() {
      _currentView = view;
      // 切换视图时重置为“今天”，确保进入各视图时默认显示当前月/周/日
      _currentDate = TimeUtils.getSystemTime();
    });
    
    // 如果切换到月视图，加载数据
    if (view == CalendarView.month) {
      _loadMonthViewData();
    } else if (view == CalendarView.week) {
      _loadWeekViewData();
    } else if (view == CalendarView.day) {
      _loadDayViewData();
    }
  }

  void _navigateDate(int days) {
    setState(() {
      switch (_currentView) {
        case CalendarView.month:
          _currentDate = DateTime(_currentDate.year, _currentDate.month + days);
          break;
        case CalendarView.week:
          _currentDate = _currentDate.add(Duration(days: days * 7));
          break;
        case CalendarView.day:
          _currentDate = _currentDate.add(Duration(days: days));
          break;
      }
    });
    
    // 重新加载数据
    if (_currentView == CalendarView.day) {
      _loadDayViewData();
      // 日视图切换日期时不弹出浮窗，只重新加载数据
    } else if (_currentView == CalendarView.month) {
      _loadMonthViewData();
      // 月视图切换时不触发日期选择事件，避免弹出浮窗
    } else if (_currentView == CalendarView.week) {
      _loadWeekViewData();
    }
  }

  // 月视图选择具体年月（滚动选择）
  Future<void> _selectMonth() async {
    final now = TimeUtils.getSystemTime();
    final years = List.generate(11, (i) => now.year - 5 + i);
    int selectedYear = _currentDate.year;
    int selectedMonth = _currentDate.month;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('选择年份与月份', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, 1));
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: years.indexOf(selectedYear).clamp(0, years.length - 1),
                        ),
                        onSelectedItemChanged: (i) {
                          selectedYear = years[i];
                        },
                        children: years.map((y) => Center(child: Text('$y年'))).toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedMonth - 1,
                        ),
                        onSelectedItemChanged: (i) {
                          selectedMonth = i + 1;
                        },
                        children: List.generate(12, (i) => Center(child: Text('${i + 1}月'))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _currentDate = DateTime(picked.year, picked.month, 1);
      });
      _loadMonthViewData();
    }
  }

  // 根据当前视图打开对应选择器
  void _openCurrentDateSelector() {
    if (_currentView == CalendarView.month) {
      _selectMonth();
    } else if (_currentView == CalendarView.week) {
      _selectWeek();
    } else {
      _selectDay();
    }
  }

  // 通用滚动日期选择（周/日使用）
  Future<DateTime?> _showCupertinoDatePicker({
    required String title,
    required Color themeColor,
  }) {
    final now = TimeUtils.getSystemTime();
    final min = DateTime(now.year - 5, 1, 1);
    final max = DateTime(now.year + 5, 12, 31);
    DateTime temp = _currentDate;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 360,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      primaryColor: themeColor,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.black87,
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      minimumDate: min,
                      maximumDate: max,
                      initialDateTime: _currentDate,
                      onDateTimeChanged: (date) => temp = date,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 周视图选择具体周（按选中的日期所在周，滚动选择日期）
  Future<void> _selectWeek() async {
    final picked = await _showCupertinoDatePicker(
      title: '选择目标周的任意日期',
      themeColor: Colors.purple,
    );

    if (picked != null) {
      final weekStart = _getWeekStart(picked);
      setState(() {
        _currentDate = weekStart;
      });
      _loadWeekViewData();
    }
  }

  // 日视图选择具体年月日（滚动选择日期）
  Future<void> _selectDay() async {
    final picked = await _showCupertinoDatePicker(
      title: '选择目标日期',
      themeColor: Colors.teal,
    );

    if (picked != null) {
      setState(() {
        _currentDate = picked;
      });
      _loadDayViewData();
    }
  }

  Future<void> _loadMonthViewData() async {
    if (_currentView != CalendarView.month) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final monthData = await CalendarService.getMonthView(
        _currentDate.year,
        _currentDate.month,
      );

      setState(() {
        _monthViewData = monthData;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeekViewData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final weekStart = _getWeekStart(_currentDate);
      final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));
      
      // 并行加载一周的数据
      final futures = weekDays.map((day) => CalendarService.getDayDetail(day));
      final results = await Future.wait(futures);
      
      // 存储到map中
      final Map<String, DayDetailData> dataMap = {};
      for (int i = 0; i < weekDays.length; i++) {
        final dateKey = '${weekDays[i].year}-${weekDays[i].month.toString().padLeft(2, '0')}-${weekDays[i].day.toString().padLeft(2, '0')}';
        dataMap[dateKey] = results[i];
      }
      
      setState(() {
        _weekViewData = dataMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // 加载日视图数据
  Future<void> _loadDayViewData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dayData = await CalendarService.getDayDetail(_currentDate);
      
      setState(() {
        _dayViewData = dayData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildViewButton('月', CalendarView.month),
          _buildViewButton('周', CalendarView.week),
          _buildViewButton('日', CalendarView.day),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, CalendarView view) {
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () => _changeView(view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.blue.shade400, Colors.cyan.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSelected ? Colors.grey.shade100 : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              view == CalendarView.month
                  ? Icons.calendar_month
                  : view == CalendarView.week
                      ? Icons.view_week
                      : Icons.today,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    String title;
    switch (_currentView) {
      case CalendarView.month:
        title = '${_currentDate.year}年${_currentDate.month}月';
        break;
      case CalendarView.week:
        final weekStart = _getWeekStart(_currentDate);
        final weekEnd = weekStart.add(const Duration(days: 6));
        title = '${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}';
        break;
      case CalendarView.day:
        title = '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _navigateDate(-1),
          icon: Icon(
            Icons.chevron_left,
            color: Colors.blue.shade700,
          ),
          iconSize: 24,
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _navigateDate(1),
          icon: Icon(
            Icons.chevron_right,
            color: Colors.blue.shade700,
          ),
          iconSize: 24,
        ),
      ],
    );
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  // 刷新当前视图数据
  void _refreshCurrentView() {
    if (_currentView == CalendarView.month) {
      _loadMonthViewData();
    } else if (_currentView == CalendarView.week) {
      _loadWeekViewData();
    } else {
      _loadDayViewData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 视图选择器
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildViewSelector(),
        ),
        // 导航栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildNavigationBar(),
        ),
        // 日历内容
        Expanded(
          child: _buildCalendarContent(),
        ),
      ],
    );
  }

  Widget _buildCalendarContent() {
    switch (_currentView) {
      case CalendarView.month:
        return _buildMonthView();
      case CalendarView.week:
        return _buildWeekView();
      case CalendarView.day:
        return _buildDayView();
    }
  }

  Widget _buildMonthView() {
    // 显示加载状态
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 显示错误状态
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMonthViewData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final lastDayOfMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    final lastDayOfWeek = lastDayOfMonth.add(Duration(days: 7 - lastDayOfMonth.weekday));

    final days = <DateTime>[];
    for (var day = firstDayOfWeek; day.isBefore(lastDayOfWeek.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      days.add(day);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // 简约日历区域
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // 星期标题 - 简约版
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: ['一', '二', '三', '四', '五', '六', '日']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                // 日期网格 - 简约版
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rowCount = (days.length / 7).ceil();
                      final availableWidth = constraints.maxWidth;
                      const spacing = 2.0;
                      final cellWidth = (availableWidth - spacing * 6) / 7;
                      final calculatedCellHeight = cellWidth * 1.6;
                      final cellHeight = max(108.0, calculatedCellHeight);
                      final gridHeight = cellHeight * rowCount + (rowCount - 1) * spacing;

                      return SizedBox(
                        height: gridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisExtent: cellHeight,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                          ),
                          itemCount: days.length,
                          itemBuilder: (context, index) {
                            final day = days[index];
                            final isCurrentMonth = day.month == _currentDate.month;
                            final isToday = TimeUtils.isToday(day);

                            // 获取该日期的数据
                            final dayData = _getDayData(day);
                            final hasData = dayData != null && dayData.hasData;

                            return GestureDetector(
                              onTap: () => _onDateTapped(day),
                              onLongPress: () => widget.onTaskAdd(day),
                              child: Container(
                                margin: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Colors.blue.shade50
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isToday
                                      ? Border.all(
                                          color: Colors.blue.shade300,
                                          width: 1.5,
                                        )
                                      : Border.all(
                                          color: Colors.grey.shade200,
                                          width: 0.6,
                                        ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 日期显示
                                      Padding(
                                        padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: isCurrentMonth
                                              ? (isToday ? Colors.blue.shade700 : Colors.grey.shade800)
                                              : Colors.grey.shade300,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    // 浅色横线 - 使用更浅的颜色
                                    if (hasData && dayData != null && (dayData.tasks.isNotEmpty || dayData.logs.isNotEmpty)) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 5),
                                        height: 1,
                                        color: Colors.grey.shade100,
                                      ),
                                      const SizedBox(height: 3),
                                    ],
                                    // 任务和日志标题列表 - 限制数量避免溢出
                                    if (hasData && dayData != null && (dayData.tasks.isNotEmpty || dayData.logs.isNotEmpty)) ...[
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                          child: _buildTaskAndLogList(dayData),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 统计信息框
          _buildMonthStatisticsBox(),

          // 任务筛选和列表
          _buildTaskFilterAndList(),

          // 底部安全间距
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 构建任务和日志列表，使用不同颜色区分
  Widget _buildTaskAndLogList(DayData dayData) {
    // 合并任务和日志，并标记类型
    final List<Map<String, dynamic>> items = [];
    
    // 添加任务
    for (var task in dayData.tasks) {
      items.add({'type': 'task', 'data': task});
    }
    
    // 添加日志
    for (var log in dayData.logs) {
      items.add({'type': 'log', 'data': log});
    }
    
    // 限制显示数量，避免溢出
    final displayItems = items.take(4).toList();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final isTask = item['type'] == 'task';
        
        if (isTask) {
          final task = item['data'] as CalendarTask;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.red.shade50, // 浅红色背景
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                task.title ?? '无标题',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.red.shade700, // 深红色字体
                  decoration: (task.status == 'completed' || task.status == 'done')
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        } else {
          final log = item['data'] as CalendarLog;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, // 浅蓝色背景
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                log.title ?? '无标题',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.blue.shade700, // 深蓝色字体
                  decoration: log.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildWeekView() {
    final weekStart = _getWeekStart(_currentDate);
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));

    // 如果正在加载，显示加载指示器
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 收集所有任务和日志，用于甘特图渲染
    final allTasks = <CalendarTask>[];
    final allLogs = <CalendarLog>[];

    for (final day in weekDays) {
      final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final dayData = _weekViewData[dateKey];
      if (dayData != null) {
        allTasks.addAll(dayData.tasks);
        allLogs.addAll(dayData.logs);
      }
    }

    // 去重（同一个任务可能在多天出现）
    final uniqueTasks = <String, CalendarTask>{};
    for (final task in allTasks) {
      uniqueTasks[task.id] = task;
    }
    final taskList = uniqueTasks.values.toList();

    final uniqueLogs = <String, CalendarLog>{};
    for (final log in allLogs) {
      uniqueLogs[log.id] = log;
    }
    final logList = uniqueLogs.values.toList();

    return Column(
      children: [
        // 星期标题（添加浅紫色背景）
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              bottom: BorderSide(color: Colors.purple.shade100, width: 1),
            ),
          ),
          child: Row(
            children: weekDays.map((day) {
              final isToday = TimeUtils.isToday(day);
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '${day.month}/${day.day}',
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                        color: isToday ? Colors.purple.shade700 : Colors.purple.shade900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? Colors.purple.shade600 : Colors.purple.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // 周视图甘特图内容
        Expanded(
          child: _buildWeekGanttChart(weekDays, taskList, logList),
        ),
      ],
    );
  }

  // 构建周视图甘特图
  Widget _buildWeekGanttChart(List<DateTime> weekDays, List<CalendarTask> tasks, List<CalendarLog> logs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        // 渐变浅紫色背景
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.shade50.withOpacity(0.3),
            Colors.purple.shade50.withOpacity(0.15),
            Colors.white.withOpacity(0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Stack(
        children: [
          // 背景：7列日期网格
          Row(
            children: weekDays.map((day) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple.shade100.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }).toList(),
          ),
          // 前景：甘特图任务和日志条
          ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // 渲染所有任务
              ...tasks.map((task) => _buildGanttTaskBar(task, weekDays, onTap: () => _showTaskDetail(task, weekDays[0]))),
              // 渲染所有日志
              ...logs.map((log) => _buildGanttLogBar(log, weekDays, onTap: () => _showLogDetailDialog(log))),
            ],
          ),
        ],
      ),
    );
  }

  // 构建甘特图任务条
  Widget _buildGanttTaskBar(CalendarTask task, List<DateTime> weekDays, {VoidCallback? onTap}) {
    DateTime? taskStartDateOnly;
    DateTime? taskEndDateOnly;

    // 如果有开始和结束时间，使用它们
    if (task.startTime != null && task.endTime != null) {
      try {
  // 解析任务时间并转换为系统本地时间
        final taskStartDate = _parseTaskTime(task.startTime!);
        final taskEndDate = _parseTaskTime(task.endTime!);
        // 提取日期部分用于比较
        taskStartDateOnly = DateTime(taskStartDate.year, taskStartDate.month, taskStartDate.day);
        taskEndDateOnly = DateTime(taskEndDate.year, taskEndDate.month, taskEndDate.day);
      } catch (e) {
        print('Error parsing task start/end time: $e');
        return const SizedBox.shrink();
      }
    } 
    // 如果只有截止时间，使用截止时间作为单日任务
    else if (task.deadline != null) {
      try {
        final deadlineDate = _parseTaskTime(task.deadline!);
        taskStartDateOnly = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
        taskEndDateOnly = taskStartDateOnly;
      } catch (e) {
        print('Error parsing task deadline: $e');
        return const SizedBox.shrink();
      }
    } 
    // 如果都没有，不显示
    else {
      return const SizedBox.shrink();
    }

    try {
      // 找出任务在本周的起始和结束位置
      int? startIndex;
      int? endIndex;

      for (int i = 0; i < weekDays.length; i++) {
        final day = weekDays[i];
        final dayOnly = DateTime(day.year, day.month, day.day);

        // 检查任务是否覆盖这一天
        if (dayOnly.isAtSameMomentAs(taskStartDateOnly!) ||
            (taskEndDateOnly != null && dayOnly.isAtSameMomentAs(taskEndDateOnly)) ||
            (taskStartDateOnly != null && taskEndDateOnly != null &&
             dayOnly.isAfter(taskStartDateOnly) && dayOnly.isBefore(taskEndDateOnly))) {
          startIndex ??= i;
          endIndex = i;
        }
      }

      // 如果任务不在本周范围内，不显示
      if (startIndex == null || endIndex == null) {
        return const SizedBox.shrink();
      }

      return _buildGanttBar(
        title: task.title,
        startIndex: startIndex,
        endIndex: endIndex,
        color: task.status == 'completed' ? Colors.grey : _getTaskColor(task),
        isCompleted: task.status == 'completed',
        weekDays: weekDays,
        onTap: onTap,
      );
    } catch (e) {
      print('Error building gantt task bar: $e');
      return const SizedBox.shrink();
    }
  }

  // 构建甘特图日志条
  Widget _buildGanttLogBar(CalendarLog log, List<DateTime> weekDays, {VoidCallback? onTap}) {
    if (log.createdAt == null) {
      return const SizedBox.shrink();
    }

    try {
      // 直接从ISO字符串提取日期部分，不进行时区转换
      // 因为日志已经按日期分组返回，我们只需要比较日期部分
      final logDate = _extractDateFromISO(log.createdAt!);

      // 找出日志在本周的位置
      int? dayIndex;

      for (int i = 0; i < weekDays.length; i++) {
        final day = weekDays[i];
        final dayOnly = DateTime(day.year, day.month, day.day);

        if (dayOnly.isAtSameMomentAs(logDate)) {
          dayIndex = i;
          break;
        }
      }

      // 如果日志不在本周范围内，不显示
      if (dayIndex == null) {
        return const SizedBox.shrink();
      }

      return _buildGanttBar(
        title: log.title,
        startIndex: dayIndex,
        endIndex: dayIndex,
        color: _getLogColor(log),
        isCompleted: false,
        weekDays: weekDays,
        onTap: onTap,
      );
    } catch (e) {
      print('Error parsing log date: $e');
      return const SizedBox.shrink();
    }
  }

  // 从ISO字符串提取日期（不含时区转换）
  DateTime _extractDateFromISO(String isoString) {
    final datePart = isoString.split('T')[0];
    final parts = datePart.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // 解析任务时间并转换为系统本地时间
  // 统一规则：所有视图（月/周/日）都使用相同的时间计算逻辑，
  // 这样同一个任务在月视图、周视图、日视图中的时间显示完全一致。
  //
  // 注意：后端返回的时间字符串格式为 YYYY-MM-DD HH:MM:SS（没有时区信息），
  // 这代表的是创建任务时设定的本地时间，因此直接解析为本地时间，不做时区转换。
  DateTime _parseTaskTime(String timeStr) {
    // 如果字符串包含时区信息（Z或+/-），按标准方式解析
    if (timeStr.endsWith('Z') || (timeStr.contains('+') || timeStr.contains('-')) && timeStr.length > 19) {
      final dateTime = DateTime.parse(timeStr);
      // 如果解析后是UTC时间，转换为本地时间
      if (dateTime.isUtc) {
        return dateTime.toLocal();
      }
      return dateTime;
    } else {
      // 没有时区信息，假设是本地时间字符串（后端返回的格式）
      // 直接解析为本地时间，不做时区转换
      var normalized = timeStr.trim();
      if (!normalized.contains('T') && normalized.contains(' ')) {
        normalized = normalized.replaceFirst(' ', 'T');
      }
      final dateTime = DateTime.parse(normalized);
      // 如果解析后是UTC时间，转换为本地时间；否则直接返回
      return dateTime.isUtc ? dateTime.toLocal() : dateTime;
    }
  }

  // 解析日志时间并转换为系统本地时间
  DateTime _parseLogTime(String timeStr) {
    final dateTime = DateTime.parse(timeStr);
    return dateTime.toLocal();
  }

  // 构建甘特图横条
  Widget _buildGanttBar({
    required String title,
    required int startIndex,
    required int endIndex,
    required Color color,
    required bool isCompleted,
    required List<DateTime> weekDays,
    VoidCallback? onTap,
  }) {
    final span = endIndex - startIndex + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 64, // 增加高度从48到64，确保文字完整显示
      child: Row(
        children: [
          // 左侧空白（占据startIndex列之前的空间）
          ...List.generate(startIndex, (_) => const Expanded(child: SizedBox())),

          // 甘特图条（横跨span列）
          Expanded(
            flex: span,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 增加padding
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8), // 增加圆角
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // 增加字体大小从13到14
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      letterSpacing: 0.5, // 增加字间距
                      height: 1.4, // 增加行高，确保文字不被裁剪
                    ),
                    maxLines: 2, // 允许显示两行文字
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // 右侧空白（占据endIndex列之后的空间）
          ...List.generate(6 - endIndex, (_) => const Expanded(child: SizedBox())),
        ],
      ),
    );
  }

  Widget _buildDayView() {
    // 显示加载状态
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 显示错误状态
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDayViewData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 如果没有数据
    if (_dayViewData == null) {
      return const Center(
        child: Text('暂无数据'),
      );
    }

    final dayData = _dayViewData!;
    
    // 分离有时间段和无时间段的任务和日志
    final tasksWithTime = <CalendarTask>[];
    final tasksWithoutTime = <CalendarTask>[];
    final logsWithTime = <CalendarLog>[];
    final logsWithoutTime = <CalendarLog>[];
    
    for (final task in dayData.tasks) {
      // 全天任务显示在时间轴的24小时中（0:00-23:59）
      if (task.isAllDay == true) {
        tasksWithTime.add(task);
      } else if (task.startTime != null && task.endTime != null) {
        // 非全天任务且有具体开始和结束时间的显示在时间轴
        tasksWithTime.add(task);
      } else {
        // 没有时间的任务显示在"无具体时间段"区域
        tasksWithoutTime.add(task);
      }
    }
    
    // 注意：日志当前没有时间字段，所以都算作无时间段
    logsWithoutTime.addAll(dayData.logs);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 顶部信息框 - 显示所有任务和日志列表
          _buildDayInfoCard(dayData),
          const SizedBox(height: 16),
          
          // 2. 今日数据总结框
          _buildDaySummaryCard(dayData),
          const SizedBox(height: 16),
          
          // 3. 时间轴视图
          if (tasksWithTime.isNotEmpty || logsWithTime.isNotEmpty) ...[
            _buildSectionTitle('有具体时间段'),
            const SizedBox(height: 6),
            // 小提示：当任务较多时可以左右滑动查看全部任务
            if (tasksWithTime.length + logsWithTime.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '任务较多时，可以左右滑动时间轴查看全部任务',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _buildTimelineView(tasksWithTime, logsWithTime),
            const SizedBox(height: 24),
          ],
          
          // 4. 无时间段区域
          if (tasksWithoutTime.isNotEmpty || logsWithoutTime.isNotEmpty) ...[
            _buildSectionTitle('无具体时间段任务|日志'),
            const SizedBox(height: 12),
            _buildNoTimeSection(tasksWithoutTime, logsWithoutTime),
          ],
        ],
      ),
    );
  }

  // 顶部信息框 - 显示当天所有任务和日志
  Widget _buildDayInfoCard(DayDetailData dayData) {
    return GestureDetector(
      onTap: () {
        // 点击信息框弹出详细浮窗
        _showDayDetail(_currentDate);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (dayData.tasks.isNotEmpty || dayData.logs.isNotEmpty)
                  Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
              ],
            ),
            const Divider(height: 24),
            
            // 任务列表 - 显示所有任务
            if (dayData.tasks.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '任务',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dayData.tasks.length}个',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 显示所有任务，不省略
              ...dayData.tasks.map((task) => Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      task.status == 'completed' 
                          ? Icons.check_circle 
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: task.status == 'completed' 
                          ? Colors.green 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          decoration: task.status == 'completed' 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            
            // 日志列表 - 显示所有日志
            if (dayData.logs.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '日志',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dayData.logs.length}条',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 显示所有日志，不省略
              ...dayData.logs.map((log) => Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getLogColor(log),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        log.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            if (dayData.tasks.isEmpty && dayData.logs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '今日暂无任务和日志',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 今日数据总结框
  Widget _buildDaySummaryCard(DayDetailData dayData) {
    final completedTasks = dayData.tasks.where((t) => t.status == 'completed').length;
    final totalTasks = dayData.tasks.length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100).toStringAsFixed(0) : '0';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.assignment,
              label: '任务总数',
              value: totalTasks.toString(),
              color: Colors.red.shade300,
              onTap: () => _showDayTasksDialog(dayData),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.check_circle,
              label: '已完成',
              value: completedTasks.toString(),
              color: Colors.green,
              onTap: () => _showCompletedLogsDialog(dayData),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.description,
              label: '日志数',
              value: dayData.logs.length.toString(),
              color: Colors.blue,
              onTap: () => _showDayLogsDialog(dayData),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.trending_up,
              label: '完成率',
              value: '$completionRate%',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    Widget content = Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  // 区域标题
  Widget _buildSectionTitle(String title) {
    // "有具体时间段"和"无具体时间段"不显示箭头，并居中显示
    if (title == '无具体时间段' || title == '有具体时间段') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => _navigateDate(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // 时间轴视图
  Widget _buildTimelineView(List<CalendarTask> tasks, List<CalendarLog> logs) {
    final hours = List.generate(24, (index) => index);
    // 计算同一时间段内的最大并行任务数量，用于决定内容宽度，从而开启横向滚动
    final maxConcurrentTasks = _calculateMaxConcurrentTasks(tasks);

    return Container(
      height: 60.0 * 24, // 每小时60像素高度
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          // 时间轴
          Container(
            width: 65,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withOpacity(0.3),
                ],
              ),
              border: Border(
                right: BorderSide(color: Colors.blue.shade200, width: 1.5),
              ),
            ),
            child: Column(
              children: hours.map((hour) {
                final systemNow = TimeUtils.getSystemTime();
                final isCurrentHour = systemNow.hour == hour &&
                    TimeUtils.isSameDay(systemNow, _currentDate);
                
                return Container(
                  height: 60,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: isCurrentHour ? Colors.blue.shade100.withOpacity(0.3) : null,
                    border: Border(
                      bottom: BorderSide(
                        color: hour % 3 == 0 
                            ? Colors.blue.shade300 
                            : Colors.grey.shade200,
                        width: hour % 3 == 0 ? 1.5 : 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: isCurrentHour ? 12 : 11,
                      color: isCurrentHour ? Colors.blue.shade800 : Colors.grey[700],
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // 任务和日志区域：根据最大并行任务数决定内容宽度，必要时启用横向滚动
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const baseVisibleColumns = 2.5; // 正常情况下最多显示2.5列，给任务更多空间
                // 计算需要的列宽放大倍数，最多放大到 5 倍，给任务更多横向空间
                final widthFactor = max(1.0, min(maxConcurrentTasks / baseVisibleColumns, 5.0));
                // 增加基础宽度，让任务组件更宽，显示更多内容
                final baseWidth = constraints.maxWidth * 1.2; // 基础宽度增加20%
                final contentWidth = baseWidth * widthFactor;

                // 确保内容宽度至少比容器宽度大一点，才能触发滚动
                // 如果任务数量少，也至少保证可以轻微滚动（用于测试和用户体验）
                final finalContentWidth = max(contentWidth, constraints.maxWidth * 1.1);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(), // 强制启用滚动，确保真机上也能滚动
                  child: SizedBox(
                    width: finalContentWidth,
                    child: Stack(
                      children: [
                        // 时间网格背景
                        Column(
                          children: hours.map((hour) {
                            return Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: hour % 2 == 0
                                    ? Colors.grey.shade50
                                    : Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: hour % 3 == 0
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade100,
                                    width: hour % 3 == 0 ? 1.0 : 0.5,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // 当前时间线
                        if (TimeUtils.isToday(_currentDate))
                          _buildCurrentTimeLine(),
                        // 任务和日志（使用改进的布局算法）
                        ..._buildTasksWithLayout(tasks),
                        ...logs.map((log) => _buildLogInTimeline(log)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 计算同一时间段内的最大并行任务数量，用于确定日视图时间轴的横向宽度
  int _calculateMaxConcurrentTasks(List<CalendarTask> tasks) {
    if (tasks.isEmpty) return 1;

    final events = <Map<String, double>>[];

    for (final task in tasks) {
      if (task.startTime == null || task.endTime == null) continue;
      try {
        final start = _parseTaskTime(task.startTime!);
        final end = _parseTaskTime(task.endTime!);
        if (!start.isBefore(end)) continue;

        // 将时间转换成小时（带小数），用于比较
        final startHour = start.hour + start.minute / 60.0 + start.second / 3600.0;
        final endHour = end.hour + end.minute / 60.0 + end.second / 3600.0;

        events.add({'time': startHour, 'delta': 1});   // 开始 +1
        events.add({'time': endHour, 'delta': -1});    // 结束 -1
      } catch (_) {
        continue;
      }
    }

    if (events.isEmpty) return 1;

    // 按时间排序；同一时间点先处理结束(-1)，再处理开始(+1)，避免边界重叠被多算
    events.sort((a, b) {
      final t1 = a['time']!;
      final t2 = b['time']!;
      if (t1 != t2) return t1.compareTo(t2);
      return a['delta']!.compareTo(b['delta']!);
    });

    int current = 0;
    int maxValue = 1;
    for (final e in events) {
      current += e['delta']!.toInt();
      if (current > maxValue) {
        maxValue = current;
      }
    }
    return maxValue;
  }

  // 为任务计算布局（避免重叠）
  List<Widget> _buildTasksWithLayout(List<CalendarTask> tasks) {
    if (tasks.isEmpty) return [];
    
    // 为每个任务计算时间范围
    List<Map<String, dynamic>> taskInfos = [];
    for (var task in tasks) {
      if (task.startTime == null || task.endTime == null) continue;

      try {
        final taskStartTime = _parseTaskTime(task.startTime!);
        final taskEndTime = _parseTaskTime(task.endTime!);

        final currentViewDate = _currentDate;
        final dayStart = DateTime(currentViewDate.year, currentViewDate.month, currentViewDate.day, 0, 0, 0);
        final dayEnd = DateTime(currentViewDate.year, currentViewDate.month, currentViewDate.day, 23, 59, 59);
        
        DateTime displayStartTime;
        DateTime displayEndTime;
        double startHour;
        double endHour;
        
        // 全天任务显示在0:00-23:59
        if (task.isAllDay == true) {
          displayStartTime = dayStart;
          displayEndTime = dayEnd;
          startHour = 0.0;
          endHour = 23.99; // 接近24小时，但不等于24
        } else if (task.startTime != null && task.endTime != null) {
          final taskStartTime = _parseTaskTime(task.startTime!);
          final taskEndTime = _parseTaskTime(task.endTime!);
          
          if (taskStartTime.isBefore(dayStart)) {
            displayStartTime = dayStart;
          } else {
            displayStartTime = taskStartTime;
          }
          
          if (taskEndTime.isAfter(dayEnd)) {
            displayEndTime = dayEnd;
          } else {
            displayEndTime = taskEndTime;
          }
          
          if (displayStartTime.isAfter(dayEnd) || displayEndTime.isBefore(dayStart)) {
            continue;
          }
          
          // 精确计算时间段，包括秒数，确保严格对应时间轴
          startHour = displayStartTime.hour + displayStartTime.minute / 60.0 + displayStartTime.second / 3600.0;
          endHour = displayEndTime.hour + displayEndTime.minute / 60.0 + displayEndTime.second / 3600.0;
        } else {
          continue; // 没有时间信息的任务跳过
        }
        
        taskInfos.add({
          'task': task,
          'startHour': startHour,
          'endHour': endHour,
          'displayStartTime': displayStartTime,
          'displayEndTime': displayEndTime,
          'column': 0, // 将在下面分配
          'maxColumns': 1,
        });
      } catch (e) {
        continue;
      }
    }
    
    // 按开始时间排序
    taskInfos.sort((a, b) => a['startHour'].compareTo(b['startHour']));
    
    // 分配列（避免重叠，优化间距）
    for (int i = 0; i < taskInfos.length; i++) {
      final currentTask = taskInfos[i];
      int column = 0;
      
      // 检查与之前任务的重叠
      for (int j = 0; j < i; j++) {
        final previousTask = taskInfos[j];
        
        // 如果时间重叠（允许小的时间间隔，避免任务太挤）
        final timeGap = currentTask['startHour'] - previousTask['endHour'];
        if (currentTask['startHour'] < previousTask['endHour'] || timeGap < 0.1) {
          // 如果当前列已被占用，尝试下一列
          if (previousTask['column'] == column) {
            column++;
          }
        }
      }
      
      currentTask['column'] = column;
      
      // 更新所有重叠任务的最大列数
      int maxColumns = column + 1;
      for (int j = 0; j < taskInfos.length; j++) {
        final otherTask = taskInfos[j];
        if (i != j && 
            currentTask['startHour'] < otherTask['endHour'] && 
            currentTask['endHour'] > otherTask['startHour']) {
          final otherMaxColumns = otherTask['maxColumns'] as int;
          maxColumns = maxColumns > otherMaxColumns ? maxColumns : otherMaxColumns;
        }
      }
      // 更新所有相关任务的最大列数
      for (int j = 0; j < taskInfos.length; j++) {
        final otherTask = taskInfos[j];
        if (i != j &&
            currentTask['startHour'] < otherTask['endHour'] &&
            currentTask['endHour'] > otherTask['startHour']) {
          otherTask['maxColumns'] = maxColumns;
          currentTask['maxColumns'] = maxColumns;
        }
      }
      // 确保当前任务也有正确的maxColumns
      if (currentTask['maxColumns'] < maxColumns) {
        currentTask['maxColumns'] = maxColumns;
      }
    }
    
    // 生成 Widget
    return taskInfos.map((info) {
      return _buildTaskInTimelineWithPosition(
        info['task'],
        info['startHour'],
        info['endHour'],
        info['displayStartTime'],
        info['displayEndTime'],
        info['column'],
        info['maxColumns'],
      );
    }).toList();
  }

  // 在时间轴中显示任务（带位置信息）
  Widget _buildTaskInTimelineWithPosition(
    CalendarTask task,
    double startHour,
    double endHour,
    DateTime displayStartTime,
    DateTime displayEndTime,
    int column,
    int maxColumns,
  ) {
    try {
      final taskStartTime = _parseTaskTime(task.startTime!);
      final taskEndTime = _parseTaskTime(task.endTime!);
      
      final duration = endHour - startHour;
      if (duration <= 0) return const SizedBox.shrink();
      
      // 判断是否为跨天任务
      final isMultiDay = taskStartTime.day != taskEndTime.day || 
                         taskStartTime.month != taskEndTime.month || 
                         taskStartTime.year != taskEndTime.year;
      
      // 根据优先级和状态选择颜色
      Color cardColor;
      Color borderColor;
      List<Color> gradientColors;
      
      if (task.status == 'completed') {
        cardColor = Colors.green.shade400;
        borderColor = Colors.green.shade600;
        gradientColors = [Colors.green.shade300, Colors.green.shade500];
      } else {
        switch (task.priority) {
          case 'high':
            cardColor = Colors.red.shade400;
            borderColor = Colors.red.shade700;
            gradientColors = [Colors.red.shade300, Colors.red.shade600];
            break;
          case 'medium':
            cardColor = Colors.orange.shade400;
            borderColor = Colors.orange.shade700;
            gradientColors = [Colors.orange.shade300, Colors.orange.shade600];
            break;
          default:
            cardColor = Colors.blue.shade400;
            borderColor = Colors.blue.shade300;
            gradientColors = [Colors.blue.shade50, Colors.blue.shade100];
        }
      }
      
      // 计算精确的高度（像素），确保严格对应时间轴
      final heightInPixels = duration * 60.0;
      // 最小高度限制，避免过小
      final minHeight = 28.0;
      final actualHeight = heightInPixels < minHeight ? minHeight : heightInPixels;

      // 判断是否为超短任务（高度小于40像素）
      final isVeryShortTask = actualHeight < 40;
      // 判断是否为短任务（高度小于50像素）
      final isShortTask = actualHeight < 50;

      // 当任务时间段太短时，增加横向宽度以显示更多内容
      // 基础宽度因子，短任务时增加宽度
      final baseWidthFactor = isVeryShortTask ? 1.4 : (isShortTask ? 1.2 : 1.0);
      // 任务之间的间距（列间距），多列时增加间距让任务分散开
      final columnSpacing = maxColumns > 1 ? 0.12 : 0.0;
      // 计算每列的宽度因子，考虑间距和基础宽度
      // 基础宽度 = 1.0 / maxColumns，然后乘以基础宽度因子，再减去间距
      final columnWidthFactor = (1.0 / maxColumns) * baseWidthFactor;
      final widthFactor = (columnWidthFactor * 0.88) - (columnSpacing / maxColumns);
      // 确保宽度不会太小，也不会超过单列
      final finalWidthFactor = widthFactor.clamp(0.25, 0.95);

      // 根据高度动态调整padding和内容
      final horizontalPadding = isShortTask ? 8.0 : 10.0;
      final verticalPadding = isShortTask ? 4.0 : 6.0;
      final iconSize = isShortTask ? 13.0 : 15.0;
      final titleFontSize = isShortTask ? 13.0 : 15.0;
      final timeFontSize = isShortTask ? 11.0 : 12.0;

      // 使用 Align 和 FractionallySizedBox 来处理相对宽度和位置
      // 计算列的位置偏移，增加列之间的间距，让任务分散开
      final baseOffset = (column / maxColumns) * 2 - 1 + (1.0 / maxColumns);
      final spacingOffset = maxColumns > 1
          ? (column - (maxColumns - 1) / 2.0) * columnSpacing * 0.6
          : 0.0;
      final columnOffset = (baseOffset + spacingOffset).clamp(-1.0, 1.0);

      return Positioned(
        top: startHour * 60.0, // 精确到分钟和秒
        left: 0,
        right: 0,
        height: actualHeight, // 使用精确计算的高度
        child: Align(
          alignment: Alignment(columnOffset.clamp(-1.0, 1.0), 0),
          child: FractionallySizedBox(
            widthFactor: finalWidthFactor,
            child: GestureDetector(
              onTap: () {
                _showTaskDetail(task, _currentDate);
              },
              child: ClipRect(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: actualHeight, // 确保不会超出容器高度
                      minHeight: actualHeight, // 确保最小高度
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                      child: SizedBox(
                        height: actualHeight - (verticalPadding * 2), // 确保内容高度不超过容器
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(), // 禁用滚动，防止溢出
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 防止溢出
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                            // 标题行 - 使用Flexible确保不会溢出
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  task.status == 'completed'
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: iconSize,
                                  color: Colors.blue.shade900,
                                ),
                                SizedBox(width: isShortTask ? 5 : 7),
                                Flexible(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w600,
                                      decoration: task.status == 'completed'
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: isVeryShortTask ? 1 : (actualHeight > 40 ? 2 : 1),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              // 如果是跨天任务，显示标记（只在有足够空间时显示）
                              if (isMultiDay && actualHeight > 35)
                                Padding(
                                  padding: EdgeInsets.only(left: isShortTask ? 4 : 6),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: isShortTask ? 4 : 6, vertical: isShortTask ? 1 : 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blue.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '跨天',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: isShortTask ? 8 : 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // 时间范围（只在有足够空间时显示）
                          // 使用实际高度进行判断，避免在高度较小的情况下内容挤压导致溢出
                          if (actualHeight > 44)
                            Padding(
                              padding: EdgeInsets.only(top: isShortTask ? 2 : 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: isShortTask ? 10 : 12,
                                    color: Colors.blue.shade800,
                                  ),
                                  SizedBox(width: isShortTask ? 3 : 4),
                                  Flexible(
                                    child: Text(
                                      '${displayStartTime.hour.toString().padLeft(2, '0')}:${displayStartTime.minute.toString().padLeft(2, '0')} - ${displayEndTime.hour.toString().padLeft(2, '0')}:${displayEndTime.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: timeFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // 如果是跨天任务，显示总时间范围
                          if (isMultiDay && actualHeight > 60)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '总: ${DateFormat('M/d HH:mm').format(taskStartTime.toLocal())} - ${DateFormat('M/d HH:mm').format(taskEndTime.toLocal())}',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: isShortTask ? 9 : 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          // 描述（如果有足够高度）
                          if (actualHeight > 80 && task.description.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  task.description,
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                  maxLines: ((actualHeight - 80) / 15).floor().clamp(0, 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ), // Column
                      ), // SingleChildScrollView
                      ), // SizedBox
                    ), // Padding
                  ), // Container
                ), // ClipRRect
              ), // ClipRect
            ), // GestureDetector
          ), // FractionallySizedBox
        ), // Align
      ); // Positioned
    } catch (e) {
      print('显示任务时出错: $e');
      return const SizedBox.shrink();
    }
  }

  // 在时间轴中显示任务（支持跨天任务）
  Widget _buildTaskInTimeline(CalendarTask task) {
    if (task.startTime == null || task.endTime == null) {
      return const SizedBox.shrink();
    }
    
    try {
      final taskStartTime = _parseTaskTime(task.startTime!);
      final taskEndTime = _parseTaskTime(task.endTime!);
      
      // 当前查看的日期（日视图的日期）
      final currentViewDate = _currentDate;
      final dayStart = DateTime(currentViewDate.year, currentViewDate.month, currentViewDate.day, 0, 0, 0);
      final dayEnd = DateTime(currentViewDate.year, currentViewDate.month, currentViewDate.day, 23, 59, 59);
      
      // 计算任务在当天应该显示的时间段
      DateTime displayStartTime;
      DateTime displayEndTime;
      
      // 如果任务在当天开始之前就开始了，从00:00开始显示
      if (taskStartTime.isBefore(dayStart)) {
        displayStartTime = dayStart;
      } else {
        displayStartTime = taskStartTime;
      }
      
      // 如果任务在当天结束之后才结束，显示到23:59
      if (taskEndTime.isAfter(dayEnd)) {
        displayEndTime = dayEnd;
      } else {
        displayEndTime = taskEndTime;
      }
      
      // 如果任务不在当天的时间范围内，不显示
      if (displayStartTime.isAfter(dayEnd) || displayEndTime.isBefore(dayStart)) {
        return const SizedBox.shrink();
      }
      
      final startHour = displayStartTime.hour + displayStartTime.minute / 60.0;
      final endHour = displayEndTime.hour + displayEndTime.minute / 60.0;
      final duration = endHour - startHour;
      
      if (duration <= 0) return const SizedBox.shrink();

      // 判断是否为跨天任务
      final isMultiDay = taskStartTime.day != taskEndTime.day || 
                         taskStartTime.month != taskEndTime.month || 
                         taskStartTime.year != taskEndTime.year;
      
      final taskHeight = (duration * 60 - 4).clamp(20.0, double.infinity);
      final isShortTask = taskHeight < 50;

      return Positioned(
        top: startHour * 60,
        left: 4,
        right: 4,
        child: ClipRect(
          child: Container(
            height: taskHeight,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: task.status == 'completed'
                  ? Colors.grey.shade300
                  : Colors.red.shade300,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: task.status == 'completed'
                    ? Colors.grey.shade400
                    : Colors.red.shade400,
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isShortTask ? 4 : 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Icon(
                      task.status == 'completed' 
                          ? Icons.check_circle 
                          : Icons.assignment,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: task.status == 'completed' 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 如果是跨天任务，显示一个标记
                    if (isMultiDay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '跨天',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${displayStartTime.hour.toString().padLeft(2, '0')}:${displayStartTime.minute.toString().padLeft(2, '0')} - ${displayEndTime.hour.toString().padLeft(2, '0')}:${displayEndTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                // 如果是跨天任务，显示总时间范围
                if (isMultiDay && taskHeight > 30)
                  Flexible(
                    child: Text(
                      '总时间: ${DateFormat('M/d HH:mm').format(taskStartTime.toLocal())} - ${DateFormat('M/d HH:mm').format(taskEndTime.toLocal())}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (taskHeight > 50 && task.description.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        maxLines: ((taskHeight - 50) / 15).floor().clamp(0, 2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('显示任务时出错: $e');
      return const SizedBox.shrink();
    }
  }

  // 在时间轴中显示日志
  Widget _buildLogInTimeline(CalendarLog log) {
    // 日志当前没有时间字段，所以不在时间轴中显示
    return const SizedBox.shrink();
  }

  // 显示当前时间线
  Widget _buildCurrentTimeLine() {
    final now = TimeUtils.getSystemTime();
    // 使用系统当前时间，不做时区转换（与任务时间显示保持一致）
    final currentHour = TimeUtils.getHourWithMinutes(now);
    final topPosition = (currentHour * 60).clamp(0.0, 60.0 * 24 - 1.0);
    
    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }
          return Row(
            children: [
              // 时间标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 时间线
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.red,
                        Colors.red.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              // 圆点
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 无时间段区域
  Widget _buildNoTimeSection(List<CalendarTask> tasks, List<CalendarLog> logs) {
    return Column(
      children: [
        // 无时间段的任务
          if (tasks.isNotEmpty) ...[
            ...tasks.map((task) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showTaskDetail(task, _currentDate),
                  child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: task.status == 'completed' 
                    ? Colors.grey.shade300 
                    : Colors.red.shade200,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: task.status == 'completed' 
                        ? Colors.grey.shade300 
                        : Colors.red.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            task.status == 'completed' 
                                ? Icons.check_circle 
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: task.status == 'completed' 
                                ? Colors.green 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                decoration: task.status == 'completed' 
                                    ? TextDecoration.lineThrough 
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
                )),
        ],
        
        // 无时间段的日志
        if (logs.isNotEmpty) ...[
            ...logs.map((log) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showLogDetailDialog(log),
                  child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getLogColor(log).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getLogColor(log),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getLogColor(log).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getCategoryLabel(log.category),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getLogColor(log),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (log.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.content,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
                )),
        ],
      ],
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.blue; // 默认颜色
    }
  }

  // 获取指定日期的数据
  DayData? _getDayData(DateTime day) {
    if (_monthViewData == null) return null;
    
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    try {
      return _monthViewData!.days.firstWhere((d) => d.date == dateStr);
    } catch (e) {
      return null;
    }
  }

  // 构建数据指示器
  Widget _buildDataIndicators(DayData dayData) {
    final indicators = <Widget>[];
    
    // 任务指示器
    if (dayData.tasks.isNotEmpty) {
      indicators.add(
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      );
    }
    
    // 日志指示器
    if (dayData.logs.isNotEmpty) {
      indicators.add(
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      );
    }
    
    return Column(
      children: indicators,
    );
  }

  // 构建美化的数据指示器
  Widget _buildBeautifiedDataIndicators(DayData dayData) {
    final indicators = <Widget>[];

    // 任务指示器 - 美化版
    if (dayData.tasks.isNotEmpty) {
      final completedTasks = dayData.tasks.where((t) => t.status == 'completed').length;
      final totalTasks = dayData.tasks.length;

      indicators.add(
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: completedTasks == totalTasks
                  ? [Colors.green.shade300, Colors.green.shade500]
                  : [Colors.blue.shade300, Colors.blue.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: (completedTasks == totalTasks ? Colors.green : Colors.blue).withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    // 日志指示器 - 美化版
    if (dayData.logs.isNotEmpty) {
      indicators.add(
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade300, Colors.purple.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: indicators,
    );
  }

  // 构建月度统计信息框
  Widget _buildMonthStatisticsBox() {
    if (_monthViewData == null) {
      return const SizedBox.shrink();
    }

    final uniqueTasks = _collectUniqueMonthlyTasks();
    final totalTasks = uniqueTasks.length;
    final totalLogs = _monthViewData!.summary.totalLogs;
    final completedTasks = uniqueTasks.where((entry) => entry.task.status == 'completed').length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100).toStringAsFixed(1) : '0';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '本月统计',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 统计卡片
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment,
                  label: '任务总数',
                  value: totalTasks.toString(),
                  color: Colors.blue,
                  gradient: [Colors.blue.shade100, Colors.blue.shade200],
                  onTap: () => _showMonthlyTasksDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: '已完成',
                  value: completedTasks.toString(),
                  color: Colors.green,
                  gradient: [Colors.green.shade100, Colors.green.shade200],
                  onTap: () => _showCompletedTasksDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.description,
                  label: '日志数',
                  value: totalLogs.toString(),
                  color: Colors.purple,
                  gradient: [Colors.purple.shade100, Colors.purple.shade200],
                  onTap: () => _showMonthlyLogsDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  label: '完成率',
                  value: '$completionRate%',
                  color: Colors.orange,
                  gradient: [Colors.orange.shade100, Colors.orange.shade200],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required List<Color> gradient,
    VoidCallback? onTap,
  }) {
    Widget card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }

  // 构建任务筛选和列表
  Widget _buildTaskFilterAndList() {
    if (_monthViewData == null) {
      return const SizedBox.shrink();
    }

    final allTasks = _collectUniqueMonthlyTasks();

    // 根据筛选条件过滤任务
    final filteredTasks = allTasks.where((entry) {
      final task = entry.task;
      switch (_taskFilter) {
        case 'completed':
          return task.status == 'completed';
        case 'pending':
          return task.status == 'pending';
        case 'in_progress':
          return task.status == 'in_progress';
        default:
          return true;
      }
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 筛选器标题
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.cyan.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '任务筛选',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${filteredTasks.length} 个任务',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 筛选按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton('全部', 'all', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('已完成', 'completed', Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('待处理', 'pending', Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('进行中', 'in_progress', Colors.purple),
                ),
              ],
            ),
          ),

          // 任务列表
          Container(
            height: 350, // 增加高度到350px
            child: filteredTasks.isNotEmpty
                ? ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) => _buildTaskListItem(filteredTasks[index]),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _taskFilter == 'all'
                              ? '本月暂无任务'
                              : _taskFilter == 'completed'
                                  ? '暂无已完成任务'
                                  : _taskFilter == 'pending'
                                      ? '暂无待处理任务'
                                      : _taskFilter == 'in_progress'
                                          ? '暂无进行中任务'
                                          : '本月暂无任务',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }

  List<_MonthlyTaskEntry> _collectUniqueMonthlyTasks() {
    if (_monthViewData == null) {
      return <_MonthlyTaskEntry>[];
    }

    final Map<String, _MonthlyTaskEntry> taskMap = {};
    for (final day in _monthViewData!.days) {
      final dayDate = DateTime.tryParse(day.date);
      if (dayDate == null) continue;
      for (final task in day.tasks) {
        final existing = taskMap[task.id];
        if (existing == null || dayDate.isBefore(existing.anchorDay)) {
          taskMap[task.id] = _MonthlyTaskEntry(task: task, anchorDay: dayDate);
        }
      }
    }

    final tasks = taskMap.values.toList();
    tasks.sort((a, b) => a.anchorDay.compareTo(b.anchorDay));
    return tasks;
  }

  // 构建筛选按钮
  Widget _buildFilterButton(String label, String value, Color color) {
    final isSelected = _taskFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _taskFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.7), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSelected ? Colors.grey.shade100 : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // 构建任务列表项
  Widget _buildTaskListItem(_MonthlyTaskEntry entry) {
    final task = entry.task;
    final statusColor = _getStatusColor(task.status);
    final statusText = _getStatusText(task.status);
    final dateDisplay = _formatTaskDateRange(task, entry.anchorDay);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            task.status == 'completed' ? Icons.check_circle : Icons.assignment,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
            color: task.status == 'completed' ? Colors.grey.shade600 : Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => _showTaskDetail(task, entry.anchorDay),
      ),
    );
  }

  String _formatTaskDateRange(CalendarTask task, DateTime fallbackStart) {
    final start = _parseTaskDate(task.startTime) ?? fallbackStart;
    final DateTime? endRaw = _parseTaskDate(task.endTime) ?? _parseTaskDate(task.deadline);
    if (endRaw == null || _isSameCalendarDay(start, endRaw) || endRaw.isBefore(start)) {
      return _formatDateYmd(start);
    }
    final end = endRaw;
    return '${_formatDateYmd(start)} - ${_formatDateYmd(end)}';
  }

  DateTime? _parseTaskDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    // 统一使用 _parseTaskTime 解析，确保所有视图时间一致
    try {
      return _parseTaskTime(value);
    } catch (e) {
      return null;
    }
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateYmd(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  // 处理日期点击
  void _onDateTapped(DateTime day) {
    // 只显示详情弹窗，不需要调用 onDateSelected（那个会显示旧的弹窗）
    _showDayDetail(day);
  }

  // 显示日期详情
  Future<void> _showDayDetail(DateTime day) async {
    try {
      final dayDetail = await CalendarService.getDayDetail(day);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.year}年${day.month}月${day.day}日',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dayDetail.tasks.length}个任务 · ${dayDetail.logs.length}个日志',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 内容区域
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 任务列表
                        if (dayDetail.tasks.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '任务',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...dayDetail.tasks.map((task) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getTaskColor(task),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        color: Colors.blue,
                                        onPressed: () {
                                          _showEditTaskDialog(context, task, day);
                                        },
                                        tooltip: '编辑',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18),
                                        color: Colors.red,
                                        onPressed: () {
                                          _deleteTask(context, task, day);
                                        },
                                        tooltip: '删除',
                                      ),
                                    ],
                                  ),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      task.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildChip(
                                        label: _getStatusText(task.status),
                                        color: _getStatusColor(task.status),
                                      ),
                                      _buildChip(
                                        label: _getPriorityText(task.priority),
                                        color: _getPriorityColor(task.priority),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )).toList(),
                        ],

                        // 日志列表
                        if (dayDetail.logs.isNotEmpty) ...[
                          if (dayDetail.tasks.isNotEmpty)
                            const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '日志',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...dayDetail.logs.map((log) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getLogColor(log),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          log.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        color: Colors.blue,
                                        onPressed: () {
                                          _showEditLogDialog(context, log, dayDetail, day);
                                        },
                                        tooltip: '编辑',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18),
                                        color: Colors.red,
                                        onPressed: () {
                                          _deleteLog(context, log, day);
                                        },
                                        tooltip: '删除',
                                      ),
                                    ],
                                  ),
                                  if (log.content.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      log.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildChip(
                                        label: _getCategoryText(log.category),
                                        color: _getLogColor(log),
                                      ),
                                      if (log.quadrant != null)
                                        _buildChip(
                                          label: _getQuadrantText(log.quadrant!),
                                          color: Colors.purple,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )).toList(),
                        ],

                        // 无数据提示
                        if (dayDetail.tasks.isEmpty && dayDetail.logs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '该日期没有任务和日志',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载日期详情失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 显示单个任务详情
  void _showTaskDetail(CalendarTask task, DateTime day) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTaskDateRange(task, day),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 任务描述
                      if (task.description.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (task.attachments.isNotEmpty) ...[
                        Text(
                          '图片/附件',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: task.attachments.length,
                            itemBuilder: (context, index) {
                              final path = task.attachments[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _showCalendarImagePreview(context, path),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildCalendarImage(path),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 任务信息标签
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            label: _getStatusText(task.status),
                            color: _getStatusColor(task.status),
                          ),
                          _buildChip(
                            label: _getPriorityText(task.priority),
                            color: _getPriorityColor(task.priority),
                          ),
                          if (task.assigneeName != null && task.assigneeName!.isNotEmpty)
                            _buildChip(
                              label: '执行人: ${task.assigneeName}',
                              color: Colors.blue,
                            ),
                        ],
                      ),

                      // 时间信息
                      if (task.startTime != null || task.endTime != null || task.deadline != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.startTime != null) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '开始时间:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        _formatDateTimeString(task.startTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (task.endTime != null || task.deadline != null)
                                  const SizedBox(height: 8),
                              ],
                              if (task.endTime != null) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '结束时间:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        _formatDateTimeString(task.endTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (task.deadline != null)
                                  const SizedBox(height: 8),
                              ],
                              if (task.deadline != null) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.event, size: 16, color: Colors.orange.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '截止时间:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        _formatDateTimeString(task.deadline),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange.shade700,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 需求：月视图任务详情中不显示“编辑任务”和“删除任务”按钮（移除底部按钮栏）
            ],
          ),
        ),
      ),
    );
  }

  // 获取任务颜色
  Color _getTaskColor(CalendarTask task) {
    // 统一使用浅红色显示任务，与绿色的学习日志区分
    return Colors.red.shade300;
  }

  // 获取日志颜色
  Color _getLogColor(CalendarLog log) {
    switch (log.category.toLowerCase()) {
      case 'work':
        return Colors.blue; // 工作 - 蓝色
      case 'meeting':
        return Colors.purple; // 会议 - 紫色
      case 'learning':
        return Colors.green; // 学习 - 绿色
      case 'personal':
        return Colors.orange; // 个人 - 橙色
      default:
        return Colors.lightGreen; // 其他 - 浅绿色
    }
  }

  // 获取分类标签
  String _getCategoryLabel(String category) {
    // 现在分类支持手动输入，优先直接展示用户填写的内容
    if (category.trim().isNotEmpty) {
      return category.trim();
    }
    return '其他';
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已完成';
      default:
        return '待处理';
    }
  }

  // 获取优先级文本
  String _getPriorityText(String priority) {
    switch (priority) {
      case 'p0':
        return 'P0';
      case 'p1':
        return 'P1';
      case 'p2':
        return 'P2';
      case 'p3':
        return 'P3';
      case 'important_urgent':
        return '工作';
      case 'important_not_urgent':
        return '学习';
      case 'not_important_urgent':
        return '生活';
      case 'not_important_not_urgent':
        return '其他';
      default:
        return 'P2';
    }
  }

  // 获取分类文本
  String _getCategoryText(String category) {
    if (category.trim().isNotEmpty) {
      return category.trim();
    }
    return '其他';
  }

  // 获取象限文本
  String _getQuadrantText(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return '重要紧急';
      case 'important_not_urgent':
        return '重要不紧急';
      case 'not_important_urgent':
        return '紧急不重要';
      case 'not_important_not_urgent':
        return '不重要不紧急';
      default:
        return '重要不紧急';
    }
  }

  // 获取状态颜色
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // 获取优先级颜色
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'p0':
        return Colors.red;
      case 'p1':
        return Colors.deepOrange;
      case 'p2':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // 构建标签芯片
  Widget _buildChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 显示编辑任务对话框（高级版）
  Future<void> _showEditTaskDialog(
    BuildContext context,
    CalendarTask task,
    DateTime day,
  ) async {
    final result = await showDialog<_CalendarTaskEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CalendarTaskEditDialog(
          task: task,
          initialDate: day,
        );
      },
    );

    if (result != null && mounted) {
      await _updateTask(context, task, result, day);
    }
  }

  // 更新任务
  Future<void> _updateTask(
    BuildContext context,
    CalendarTask task,
    _CalendarTaskEditResult editResult,
    DateTime day,
  ) async {
    try {
      // 先上传新选择的图片
      List<String> uploadedImageUrls = [];
      if (editResult.newImages.isNotEmpty) {
        final snackBar = SnackBar(
          content: const Text('正在上传图片...'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        uploadedImageUrls = await ApiService.uploadImages(editResult.newImages);
      }

      final allAttachments = [
        ...editResult.persistedAttachments,
        ...uploadedImageUrls,
      ];

      // 基础字段更新（标题、内容、优先级、状态、附件）
      await CalendarService.updateTask(
        task.id,
        title: editResult.title,
        description: editResult.description,
        priority: editResult.priority,
        status: editResult.status,
        attachments: allAttachments,
      );

      // 完成度 & 状态联动（调用专门的状态接口，保持与任务详情一致）
      await TaskService.updateTaskStatus(
        task.id,
        status: editResult.status,
        progressPercentage: editResult.progressPercentage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务更新成功'),
            backgroundColor: Colors.green,
          ),
        );
        // 重新加载日期详情和周视图数据，确保甘特图也刷新
        Navigator.of(context).pop();
        _showDayDetail(day);
        // 刷新周视图数据，确保甘特图中的任务状态也更新
        await _loadWeekViewData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新任务失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 删除任务
  Future<void> _deleteTask(BuildContext context, CalendarTask task, DateTime day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除任务"${task.title}"吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await CalendarService.deleteTask(task.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('任务删除成功'),
              backgroundColor: Colors.green,
            ),
          );
          // 重新加载日期详情和周视图数据，确保甘特图也刷新
          Navigator.of(context).pop();
          _showDayDetail(day);
          // 刷新周视图数据，确保甘特图中的任务也被移除
          await _loadWeekViewData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除任务失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 显示编辑日志对话框
  Future<void> _showEditLogDialog(
    BuildContext context,
    CalendarLog log,
    DayDetailData dayDetail,
    DateTime day,
  ) async {
    DateTime initialDate = day;
    if (log.logDate != null && log.logDate!.isNotEmpty) {
      initialDate = DateTime.tryParse(log.logDate!) ?? day;
    } else {
      try {
        initialDate = DateTime.parse(log.createdAt);
      } catch (_) {}
    }

    final result = await showDialog<_CalendarLogEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CalendarLogEditDialog(
          log: log,
          availableTasks: dayDetail.tasks,
          initialDate: initialDate,
        );
      },
    );

    if (result != null && mounted) {
      await _updateLog(context, log, result, day);
    }
  }

  // 更新日志
  Future<void> _updateLog(
    BuildContext context,
    CalendarLog log,
    _CalendarLogEditResult editResult,
    DateTime day,
  ) async {
    try {
      final logDateStr = DateFormat('yyyy-MM-dd').format(editResult.selectedDate);

      DateTime? parsedCreatedAt;
      try {
        if (log.createdAt.isNotEmpty) {
          parsedCreatedAt = DateTime.parse(log.createdAt);
        }
      } catch (_) {
        parsedCreatedAt = null;
      }

      final createdAtDateTime = DateTime(
        editResult.selectedDate.year,
        editResult.selectedDate.month,
        editResult.selectedDate.day,
        parsedCreatedAt?.hour ?? 0,
        parsedCreatedAt?.minute ?? 0,
        parsedCreatedAt?.second ?? 0,
        parsedCreatedAt?.millisecond ?? 0,
        parsedCreatedAt?.microsecond ?? 0,
      );

      List<String> uploadedImageUrls = [];
      if (editResult.newImages.isNotEmpty) {
        final snackBar = SnackBar(
          content: const Text('正在上传图片...'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue.shade600,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        uploadedImageUrls = await ApiService.uploadImages(editResult.newImages);
      }

      final allImages = [
        ...editResult.persistedImages,
        ...uploadedImageUrls,
      ];

      await CalendarService.updateLog(
        log.id,
        title: editResult.title,
        content: editResult.content,
        category: editResult.category,
        isCompleted: log.isCompleted,
        createdAt: createdAtDateTime.toIso8601String(),
        logDate: logDateStr,
        weather: editResult.weather,
        keywords: editResult.keywords,
        images: allImages,
        locationName: editResult.locationName,
        latitude: editResult.latitude,
        longitude: editResult.longitude,
        linkages: editResult.taskUpdates,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('日志更新成功'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        _showDayDetail(day);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新日志失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 删除日志
  Future<void> _deleteLog(BuildContext context, CalendarLog log, DateTime day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除日志"${log.title}"吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await CalendarService.deleteLog(log.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('日志删除成功'),
              backgroundColor: Colors.green,
            ),
          );
          // 重新加载日期详情
          Navigator.of(context).pop();
          _showDayDetail(day);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除日志失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 格式化时间字符串为易读的中文格式
  // 统一依赖 _parseTaskTime（已经保证所有视图时间计算规则一致）
  String _formatDateTimeString(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return '';
    }

    try {
      // 解析任务时间并转换为系统本地时间（由 _parseTaskTime 统一处理偏移）
      final dateTime = _parseTaskTime(dateTimeStr);
      // 格式化为 YYYY-MM-DD HH:MM:SS 格式
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      // 如果解析失败，返回原字符串
      return dateTimeStr;
    }
  }

  // 显示本月日志对话框
  void _showMonthlyLogsDialog() {
    if (_monthViewData == null) return;

    // 收集所有有日志的日期，按日期排序
    final daysWithLogs = <DayData>[];
    for (final day in _monthViewData!.days) {
      if (day.logs.isNotEmpty) {
        daysWithLogs.add(day);
      }
    }

    if (daysWithLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本月暂无日志')),
      );
      return;
    }

    // 按日期排序
    daysWithLogs.sort((a, b) => a.date.compareTo(b.date));

    // 显示对话框（对话框内部会初始化本地化数据）
    showDialog(
      context: context,
      builder: (context) => _MonthlyLogsDialog(
        daysWithLogs: daysWithLogs,
        currentMonth: _currentDate,
      ),
    );
  }

  // 显示本月任务对话框
  void _showMonthlyTasksDialog() {
    if (_monthViewData == null) return;

    // 收集所有有任务的日期，按日期排序
    final daysWithTasks = <DayData>[];
    for (final day in _monthViewData!.days) {
      if (day.tasks.isNotEmpty) {
        daysWithTasks.add(day);
      }
    }

    if (daysWithTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本月暂无任务')),
      );
      return;
    }

    daysWithTasks.sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (context) => _MonthlyTasksDialog(
        daysWithTasks: daysWithTasks,
        currentMonth: _currentDate,
      ),
    );
  }

  // 显示当天任务对话框
  void _showDayTasksDialog(DayDetailData dayData) {
    if (dayData.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当天暂无任务')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.assignment, color: Colors.red.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '任务详情',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          Text(
                            '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日',
                            style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),

              // 任务列表
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: dayData.tasks.length,
                  itemBuilder: (context, index) {
                    final task = dayData.tasks[index];
                    final status = task.status?.toString() ?? '';
                    final isCompleted = status == 'completed' || status == 'done';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompleted ? Colors.grey.shade300 : Colors.red.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 任务标题和状态
                          Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : Icons.assignment,
                                size: 20,
                                color: isCompleted ? Colors.green : Colors.red.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.title ?? '无标题',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 优先级
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _priorityColor(task.priority).withOpacity(0.3),
                                  border: Border.all(color: _priorityColor(task.priority)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (task.priority?.toString().toUpperCase() ?? 'P3'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 状态
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                                  border: Border.all(
                                    color: isCompleted ? Colors.green.shade300 : Colors.orange.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isCompleted ? '已完成' : '进行中',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // 任务时间
                          if ((task.startTime != null && task.endTime != null) || (task.isAllDay == true)) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  task.isAllDay == true
                                      ? '全天任务'
                                      : '${DateFormat('HH:mm').format(_parseTaskTime(task.startTime!).toLocal())} - ${DateFormat('HH:mm').format(_parseTaskTime(task.endTime!).toLocal())}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],

                          if (task.attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: task.attachments.length,
                                itemBuilder: (context, imgIndex) {
                                  final path = task.attachments[imgIndex];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showCalendarImagePreview(context, path),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildCalendarImage(
                                          path,
                                          width: 100,
                                          height: 80,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // 任务描述
                          if ((task.description?.toString().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.description, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        '任务内容',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    task.description ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示已完成任务对话框
  void _showCompletedLogsDialog(DayDetailData dayData) {
    final completedTasks = dayData.tasks.where((t) => t.status == 'completed' || t.status == 'done').toList();
    
    if (completedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当天暂无已完成任务')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已完成任务',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text(
                            '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),

              // 已完成任务列表
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = completedTasks[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 任务标题和状态
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.title ?? '无标题',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 优先级
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _priorityColor(task.priority).withOpacity(0.3),
                                  border: Border.all(color: _priorityColor(task.priority)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (task.priority?.toString().toUpperCase() ?? 'P3'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 状态
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  border: Border.all(color: Colors.green.shade300),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '已完成',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // 任务时间
                          if ((task.startTime != null && task.endTime != null) || (task.isAllDay == true)) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  task.isAllDay == true
                                      ? '全天任务'
                                      : '${DateFormat('HH:mm').format(_parseTaskTime(task.startTime!).toLocal())} - ${DateFormat('HH:mm').format(_parseTaskTime(task.endTime!).toLocal())}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],

                          // 任务描述
                          if ((task.description?.toString().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                task.description?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示本月已完成任务对话框
  void _showCompletedTasksDialog() {
    if (_monthViewData == null) return;

    // 收集所有已完成任务，使用Map按id去重（跨天数任务只显示一条）
    final completedTasksMap = <String, CalendarTask>{};
    for (final day in _monthViewData!.days) {
      for (final task in day.tasks) {
        if (task.status == 'completed' || task.status == 'done') {
          // 如果任务ID已存在，保留第一个（或可以根据需要选择最新的）
          if (!completedTasksMap.containsKey(task.id)) {
            completedTasksMap[task.id] = task;
          }
        }
      }
    }

    final completedTasks = completedTasksMap.values.toList();

    if (completedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本月暂无已完成任务')),
      );
      return;
    }

    // 按开始时间排序
    completedTasks.sort((a, b) {
      if (a.startTime == null && b.startTime == null) return 0;
      if (a.startTime == null) return 1;
      if (b.startTime == null) return -1;
      try {
        final aTime = _parseTaskTime(a.startTime!);
        final bTime = _parseTaskTime(b.startTime!);
        return aTime.compareTo(bTime);
      } catch (e) {
        return 0;
      }
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '本月已完成任务',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text(
                            '${_currentDate.year}年${_currentDate.month}月 · 共${completedTasks.length}个任务',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),

              // 已完成任务列表
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = completedTasks[index];
                    final priorityColor = _getPriorityColor(task.priority);
                    final priorityText = _getPriorityText(task.priority);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 任务标题和标签
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 标题行
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade900,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    // 右上角标签：优先级和状态（水平排列）
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 优先级标签
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: priorityColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: priorityColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.flag,
                                                size: 12,
                                                color: priorityColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                priorityText,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: priorityColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // 状态标签
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.green.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_outline,
                                                size: 12,
                                                color: Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '已完成',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // 时间信息
                                if (task.startTime != null || task.endTime != null || task.isAllDay == true) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            task.isAllDay == true
                                                ? '全天任务'
                                                : (task.startTime != null && task.endTime != null
                                                    ? '${DateFormat('yyyy-MM-dd HH:mm').format(_parseTaskTime(task.startTime!).toLocal())} - ${DateFormat('HH:mm').format(_parseTaskTime(task.endTime!).toLocal())}'
                                                    : (task.startTime != null
                                                        ? '开始时间: ${DateFormat('yyyy-MM-dd HH:mm').format(_parseTaskTime(task.startTime!).toLocal())}'
                                                        : '时间未设置')),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // 任务内容
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.description,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '任务内容',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SelectableText(
                                          task.description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取优先级颜色
  Color _priorityColor(dynamic priority) {
    final p = priority?.toString().toLowerCase() ?? '';
    switch (p) {
      case 'high':
      case 'urgent':
      case 'p1':
        return Colors.red.shade200;
      case 'medium':
      case 'p2':
        return Colors.orange.shade200;
      case 'low':
      case 'p3':
      default:
        return Colors.blue.shade200;
    }
  }

  // 显示当天日志列表对话框
  void _showDayLogsDialog(DayDetailData dayData) {
    if (dayData.logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当天暂无日志')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.description, color: Colors.blue.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '日志详情',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日',
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),

              // 日志列表
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: dayData.logs.length,
                  itemBuilder: (context, index) {
                    final log = dayData.logs[index];
                    final accentColor = _getLogColor(log);

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showLogDetailDialog(log);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 日志标题和分类
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 20,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.title.isNotEmpty ? log.title : '无标题',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 分类标签
                                if (log.category.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.2),
                                      border: Border.all(color: accentColor),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _getCategoryLabel(log.category),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // 日志内容预览
                            if (log.content.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  log.content.length > 100
                                      ? '${log.content.substring(0, 100)}...'
                                      : log.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.5,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],

                            if (log.images.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: log.images.length,
                                  itemBuilder: (context, imgIndex) {
                                    final path = log.images[imgIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => _showCalendarImagePreview(context, path),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _buildCalendarImage(
                                            path,
                                            width: 100,
                                            height: 80,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示日志详情对话框（用于周视图甘特图）
  void _showLogDetailDialog(CalendarLog log) {
    showDialog(
      context: context,
      builder: (ctx) {
        final Color accentLightColor = _getLogColor(log);
        final Color accentDarkColor = _getLogDetailAccentColor(log);
        final Color textColor = Colors.blueGrey.shade900;

        final String title = log.title;
        final String content = log.content;
        final String timeStr = log.createdAt != null
            ? _formatLogCreatedTime(log.createdAt)
            : '';
        final String category = log.category;
        // 在闭包内部获取天气标签（直接内联转换逻辑）
        final String weatherLabel = log.weather != null && log.weather.toString().isNotEmpty
            ? () {
                final w = log.weather.toString().toLowerCase();
                switch (w) {
                  case 'sunny': return '☀️ 晴天';
                  case 'cloudy': return '⛅ 多云';
                  case 'light_rain': return '🌧️ 小雨';
                  case 'heavy_rain': return '⛈️ 大雨';
                  case 'snow': return '❄️ 雪';
                  case 'storm': return '⚡ 暴风雨';
                  case 'fog': return '🌫️ 雾';
                  default: return log.weather.toString();
                }
              }()
            : '';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentLightColor.withOpacity(0.6),
                        accentLightColor.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentLightColor, width: 1),
                        ),
                        child: Icon(Icons.description, color: accentDarkColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isNotEmpty ? title : '日志详情',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                            Row(
                              children: [
                                if (category.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(top: 6, right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: accentLightColor, width: 1),
                                    ),
                                    child: Text(
                                      _getCategoryLabel(category),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: accentDarkColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (timeStr.isNotEmpty)
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 天气信息 - 移到上面
                        if (weatherLabel.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wb_sunny, size: 18, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  '天气: $weatherLabel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // 位置信息 - 移到上面
                        if ((log.locationName != null && log.locationName!.isNotEmpty) ||
                            (log.latitude != null && log.longitude != null)) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 18, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      '位置信息',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (log.locationName != null && log.locationName!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '地点: ${log.locationName}',
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                                if (log.latitude != null && log.longitude != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '经纬度: ${log.latitude!.toStringAsFixed(6)}, ${log.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // 日志内容
                        SelectableText(
                          content.isNotEmpty ? content : '无内容',
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor,
                            height: 1.6,
                          ),
                        ),
                        
                        // 图片
                        if (log.images.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('图片', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: log.images.length,
                              itemBuilder: (context, index) {
                                final path = log.images[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _showCalendarImagePreview(context, path),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildCalendarImage(path),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (log.locationName != null && log.locationName!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: accentDarkColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log.locationName!,
                                  style: TextStyle(fontSize: 14, color: textColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final buffer = StringBuffer();
                          if (title.isNotEmpty) buffer.writeln(title);
                          if (timeStr.isNotEmpty) buffer.writeln(timeStr);
                          buffer.writeln(content);
                          await Clipboard.setData(ClipboardData(text: buffer.toString()));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('已复制到剪贴板')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('关闭', style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 格式化日志创建时间（增加8小时）
  String _formatLogCreatedTime(String timeStr) {
    try {
      // 解析日志时间并转换为系统本地时间
      final dateTime = _parseLogTime(timeStr);
      // 增加8小时
    final adjustedDateTime = dateTime.toLocal();
      // 仅显示为 YYYY-MM-DD（不显示时分秒）
      return DateFormat('yyyy-MM-dd').format(adjustedDateTime);
    } catch (e) {
      return '';
    }
  }

  // 获取日志详情的深色强调色（用于标题/文字）
  Color _getLogDetailAccentColor(CalendarLog log) {
    final category = log.category;
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue.shade800;
      case 'meeting':
        return Colors.purple.shade800;
      case 'learning':
        return Colors.green.shade800;
      case 'personal':
        return Colors.orange.shade800;
      default:
        return Colors.teal.shade800;
    }
  }

}

class _CalendarLogEditResult {
  final DateTime selectedDate;
  final String title;
  final String content;
  final String category;
  final String weather;
  final List<String> keywords;
  final List<String> persistedImages;
  final List<File> newImages;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final List<LogTaskUpdate> taskUpdates;

  _CalendarLogEditResult({
    required this.selectedDate,
    required this.title,
    required this.content,
    required this.category,
    required this.weather,
    required this.keywords,
    required this.persistedImages,
    required this.newImages,
    required this.taskUpdates,
    this.locationName,
    this.latitude,
    this.longitude,
  });
}

class _CalendarTaskEditResult {
  final String title;
  final String description;
  final String priority;
  final String status;
  final int progressPercentage;
  final List<String> persistedAttachments;
  final List<File> newImages;

  _CalendarTaskEditResult({
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.progressPercentage,
    required this.persistedAttachments,
    required this.newImages,
  });
}

class _CalendarLogEditDialog extends StatefulWidget {
  final CalendarLog log;
  final List<CalendarTask> availableTasks;
  final DateTime initialDate;

  const _CalendarLogEditDialog({
    required this.log,
    required this.availableTasks,
    required this.initialDate,
  });

  @override
  State<_CalendarLogEditDialog> createState() => _CalendarLogEditDialogState();
}

class _CalendarLogEditDialogState extends State<_CalendarLogEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _categoryController;
  late final TextEditingController _keywordController;
  late final TextEditingController _locationController;

  DateTime _selectedDate = DateTime.now();
  String _selectedWeather = 'sunny';
  final List<String> _keywords = [];
  List<String> _persistedImages = [];
  final List<File> _newImages = [];
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;
  late List<LogTaskUpdate> _taskUpdates;

  static const int _maxKeywords = 5;
  static const List<Map<String, String>> _weatherOptions = [
    {'value': 'sunny', 'label': '晴朗', 'icon': '☀️'},
    {'value': 'cloudy', 'label': '多云', 'icon': '⛅'},
    {'value': 'light_rain', 'label': '小雨', 'icon': '🌦️'},
    {'value': 'heavy_rain', 'label': '大雨', 'icon': '⛈️'},
    {'value': 'snow', 'label': '下雪', 'icon': '❄️'},
    {'value': 'storm', 'label': '雷暴', 'icon': '⚡'},
    {'value': 'fog', 'label': '多雾', 'icon': '🌫️'},
  ];
  static const Map<String, String> _taskStatuses = {
    'pending': '待处理',
    'in_progress': '进行中',
    'completed': '已完成',
    'cancelled': '已完成',
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedWeather = widget.log.weather ?? 'sunny';
    _keywords
      ..clear()
      ..addAll(widget.log.keywords);
    _persistedImages = List<String>.from(widget.log.images);
    _latitude = widget.log.latitude;
    _longitude = widget.log.longitude;
    _taskUpdates = widget.log.taskUpdates.map((e) => e.copyWith()).toList();

    _titleController = TextEditingController(text: widget.log.title);
    _contentController = TextEditingController(text: widget.log.content);
    _categoryController = TextEditingController(text: widget.log.category);
    _keywordController = TextEditingController();
    _locationController = TextEditingController(text: widget.log.locationName ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery.of(context).size.width * 0.9, 900),
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateAndWeather(),
                      const SizedBox(height: 16),
                      _buildTitleAndCategory(),
                      const SizedBox(height: 16),
                      _buildKeywordInput(),
                      const SizedBox(height: 16),
                      _buildContentInput(),
                      const SizedBox(height: 16),
                      _buildImageSection(),
                      const SizedBox(height: 16),
                      _buildLocationSection(),
                      const SizedBox(height: 16),
                      _buildTaskSection(),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.note_alt, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '编辑日志',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndWeather() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                leading: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('天气', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weatherOptions.map((option) {
            final isSelected = _selectedWeather == option['value'];
            return ChoiceChip(
              label: Text('${option['icon']} ${option['label']}'),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedWeather = option['value']!;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTitleAndCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '标题',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入日志标题';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: '分类（可手动输入，例如：培训、总结、项目等）',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('关键词 (${_keywords.length}/$_maxKeywords)',
                style: Theme.of(context).textTheme.titleMedium),
            if (_keywords.length >= _maxKeywords)
              const Text('已达上限', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _keywords
              .map(
                (keyword) => Chip(
                  label: Text(keyword),
                  onDeleted: () => setState(() => _keywords.remove(keyword)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _keywordController,
          decoration: InputDecoration(
            labelText: '输入后按回车添加',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _submitKeyword(_keywordController.text),
            ),
          ),
          onSubmitted: _submitKeyword,
        ),
      ],
    );
  }

  Widget _buildContentInput() {
    return TextFormField(
      controller: _contentController,
      maxLines: 6,
      decoration: const InputDecoration(
        labelText: '详细内容',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('图片', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('相册'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_persistedImages.isEmpty && _newImages.isEmpty)
          Text('暂无图片', style: TextStyle(color: Colors.grey[600])),
        if (_persistedImages.isNotEmpty) ...[
          Text('已保存', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 8),
          _buildImageList(
            children: List.generate(_persistedImages.length, (index) {
              final path = _persistedImages[index];
              return _buildImagePreview(
                child: _buildCalendarImage(path, width: 100, height: 80),
                onRemove: () => setState(() => _persistedImages.removeAt(index)),
              );
            }),
          ),
        ],
        if (_newImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('待上传', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 8),
          _buildImageList(
            children: List.generate(_newImages.length, (index) {
              final file = _newImages[index];
              return _buildImagePreview(
                child: Image.file(file, width: 100, height: 80, fit: BoxFit.cover),
                onRemove: () => setState(() => _newImages.removeAt(index)),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildImageList({required List<Widget> children}) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: children.length,
      ),
    );
  }

  Widget _buildImagePreview({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('地理位置', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: _locationController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: '地点描述（通过按钮自动获取）',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isLocating ? null : _getCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('获取当前位置'),
            ),
            const SizedBox(width: 12),
            if (_latitude != null && _longitude != null)
              Expanded(
                child: Text(
                  '(${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})',
                  style: const TextStyle(color: Colors.green),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('关联的任务', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _showAddTaskDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_taskUpdates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '暂无关联任务',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          Column(
            children: List.generate(_taskUpdates.length, (index) {
              final update = _taskUpdates[index];
              final sliderValue = (update.progress_percentage ?? 0).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            update.taskName ?? '任务 #${update.taskId}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _taskUpdates.removeAt(index)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('进度'),
                        Text('${sliderValue.round()}%'),
                      ],
                    ),
                    Slider(
                      min: 0,
                      max: 100,
                      divisions: 10,
                      value: sliderValue,
                      onChanged: (value) => _updateTaskProgress(index, value.round()),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: update.task_status,
                      hint: const Text('状态（可选）'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _taskStatuses.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => _updateTaskStatus(index, value),
                    ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _newImages.add(File(picked.path));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被拒绝'), backgroundColor: Colors.red),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final address = await GeocodingService.reverseGeocodeCached(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text =
            address ?? '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLocating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddTaskDialog() {
    final existingIds = _taskUpdates.map((e) => e.taskId).toSet();
    final available = widget.availableTasks.where((task) => !existingIds.contains(task.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可关联的任务')),
      );
      return;
    }

    CalendarTask? selectedTask;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择任务'),
          content: DropdownButtonFormField<CalendarTask>(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: available
                .map(
                  (task) => DropdownMenuItem<CalendarTask>(
                    value: task,
                    child: Text(task.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              selectedTask = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedTask != null) {
                  setState(() {
                    _taskUpdates.add(
                      LogTaskUpdate(
                        taskId: selectedTask!.id,
                        taskName: selectedTask!.title,
                        progress_percentage: 0,
                        task_status: 'in_progress',
                      ),
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _updateTaskProgress(int index, int value) {
    setState(() {
      _taskUpdates[index] = _taskUpdates[index].copyWith(progress_percentage: value);
    });
  }

  void _updateTaskStatus(int index, String? value) {
    setState(() {
      _taskUpdates[index] = _taskUpdates[index].copyWith(
        task_status: value,
        setStatusToNull: value == null,
      );
    });
  }

  void _submitKeyword(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return;
    if (_keywords.length >= _maxKeywords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多添加$_maxKeywords 个关键词')),
      );
      return;
    }
    if (!_keywords.contains(value)) {
      setState(() {
        _keywords.add(value);
      });
    }
    _keywordController.clear();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locationName = _locationController.text.trim();
    final result = _CalendarLogEditResult(
      selectedDate: _selectedDate,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _categoryController.text.trim(),
      weather: _selectedWeather,
      keywords: List<String>.from(_keywords),
      persistedImages: List<String>.from(_persistedImages),
      newImages: List<File>.from(_newImages),
      locationName: locationName.isEmpty ? null : locationName,
      latitude: _latitude,
      longitude: _longitude,
      taskUpdates: _taskUpdates.map((e) => e.copyWith()).toList(),
    );

    Navigator.of(context).pop(result);
  }

}

Widget _buildCalendarImage(String path, {double width = 120, double height = 90}) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildBrokenCalendarImage(width: width, height: height),
    );
  }
  final file = File(path);
  if (file.existsSync()) {
    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
  return _buildBrokenCalendarImage(width: width, height: height);
}

Widget _buildBrokenCalendarImage({double width = 120, double height = 90}) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey.shade200,
    child: const Icon(Icons.broken_image, color: Colors.grey),
  );
}

Future<void> _showCalendarImagePreview(BuildContext context, String path) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(32),
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: _buildCalendarPreviewImage(path),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildCalendarPreviewImage(String path) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _buildBrokenCalendarImage(width: 200, height: 200),
    );
  }
  final file = File(path);
  if (file.existsSync()) {
    return Image.file(
      file,
      fit: BoxFit.contain,
    );
  }
  return _buildBrokenCalendarImage(width: 200, height: 200);
}

// 本月日志对话框
class _MonthlyLogsDialog extends StatefulWidget {
  final List<DayData> daysWithLogs;
  final DateTime currentMonth;

  const _MonthlyLogsDialog({
    required this.daysWithLogs,
    required this.currentMonth,
  });

  @override
  State<_MonthlyLogsDialog> createState() => _MonthlyLogsDialogState();
}

class _MonthlyLogsDialogState extends State<_MonthlyLogsDialog> {
  int _currentDayIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('zh_CN', null);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (widget.daysWithLogs.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentDay = widget.daysWithLogs[_currentDayIndex];
    final dayDate = DateTime.parse(currentDay.date);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description,
                      color: Colors.purple.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本月日志',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                        Text(
                          '${widget.currentMonth.year}年${widget.currentMonth.month}月',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.purple.shade700),
                  ),
                ],
              ),
            ),

            // 日期切换控制栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentDayIndex > 0
                        ? () {
                            setState(() {
                              _currentDayIndex--;
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentDayIndex > 0
                          ? Colors.purple.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          DateFormat('M月d日', 'zh_CN').format(dayDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE', 'zh_CN').format(dayDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _currentDayIndex < widget.daysWithLogs.length - 1
                        ? () {
                            setState(() {
                              _currentDayIndex++;
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _currentDayIndex < widget.daysWithLogs.length - 1
                          ? Colors.purple.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),

            // 日期指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_currentDayIndex + 1} / ${widget.daysWithLogs.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // 日志列表
            Expanded(
              child: currentDay.logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '该日暂无日志',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: currentDay.logs.length,
                      itemBuilder: (context, index) {
                        final log = currentDay.logs[index];
                        return _buildLogCard(log, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(dynamic log, int index) {
    // 根据类别和象限选择颜色（浅色系，使用深色文字）
    Color accentLightColor = _getLogColor(log);
    Color accentDarkColor = _getLogAccentColor(log);
    Color textColor = Colors.blueGrey.shade900;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentDarkColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentLightColor.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showLogDetailDialog(log);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题（使用类别对应的浅色矩形框包裹）
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentLightColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentLightColor, width: 1),
                  ),
                  child: Text(
                    log.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentDarkColor,
                    ),
                  ),
                ),

                // 内容
                if (log.content != null && log.content.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    log.content.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.9),
                      height: 1.4,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (log.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: log.images.length,
                      itemBuilder: (context, imgIndex) {
                        final path = log.images[imgIndex];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _showCalendarImagePreview(context, path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildCalendarImage(
                                path,
                                width: 100,
                                height: 80,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // 底部信息栏
                const SizedBox(height: 12),
                Row(
                  children: [
                    // 类别
                    if (log.category != null && log.category.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentLightColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentLightColor,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _getCategoryLabel(log.category.toString()),
                          style: TextStyle(
                            fontSize: 11,
                            color: accentDarkColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // 时间 - 已移除
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 解析日志时间并转换为系统本地时间
  DateTime _parseLogTime(String timeStr) {
    final dateTime = DateTime.parse(timeStr);
    return dateTime.toLocal();
  }

  String _formatLogTime(String timeStr) {
    try {
      // 解析日志时间并转换为系统本地时间
      final dateTime = _parseLogTime(timeStr);
      // 格式化为 YYYY-MM-DD HH:MM:SS 格式
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  void _showLogDetailDialog(dynamic log) {
    showDialog(
      context: context,
      builder: (ctx) {
        final Color accentLightColor = _getLogColor(log);
        final Color accentDarkColor = _getLogAccentColor(log);
        final Color textColor = Colors.blueGrey.shade900;

        final String title = (log.title ?? '').toString();
        final String content = (log.content ?? '').toString();
        final String category = (log.category ?? '').toString();

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentLightColor.withOpacity(0.6),
                        accentLightColor.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentLightColor, width: 1),
                        ),
                        child: Icon(Icons.description, color: accentDarkColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isNotEmpty ? title : '日志详情',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                            Row(
                              children: [
                                if (category.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(top: 6, right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: accentLightColor, width: 1),
                                    ),
                                    child: Text(
                                      _getCategoryLabel(category),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: accentDarkColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 天气信息 - 移到上面
                        if (log.weather != null && log.weather.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wb_sunny, size: 18, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  '天气: ${_getWeatherLabel(log.weather.toString())}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // 位置信息 - 移到上面
                        if ((log.locationName != null && log.locationName.toString().isNotEmpty) ||
                            (log.latitude != null && log.longitude != null)) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 18, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      '位置信息',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (log.locationName != null && log.locationName.toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '地点: ${log.locationName}',
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                                if (log.latitude != null && log.longitude != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '经纬度: ${log.latitude!.toStringAsFixed(6)}, ${log.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // 日志内容
                        SelectableText(
                          content.isNotEmpty ? content : '无内容',
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor,
                            height: 1.6,
                          ),
                        ),
                        
                        // 关联任务
                        if (log.taskUpdates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.link, size: 18, color: Colors.purple.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      '关联任务',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...log.taskUpdates.map((taskUpdate) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.task, size: 16, color: Colors.purple.shade600),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                taskUpdate.taskName ?? '未知任务',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                              if (taskUpdate.progress_percentage != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '进度: ${taskUpdate.progress_percentage}%',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                              ],
                                              if (taskUpdate.task_status != null) ...[
                                                Text(
                                                  '状态: ${taskUpdate.task_status}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                        
                        // 图片
                        if (log.images.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            '图片',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: log.images.length,
                              itemBuilder: (context, index) {
                                final path = log.images[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _showCalendarImagePreview(context, path),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildCalendarImage(path),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final buffer = StringBuffer();
                          if (title.isNotEmpty) buffer.writeln(title);
                          buffer.writeln(content);
                          await Clipboard.setData(ClipboardData(text: buffer.toString()));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('关闭'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getLogColor(dynamic log) {
    // 根据类别返回颜色（浅色系），只支持四个类别
    final category = log.category?.toString() ?? '';

    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue.shade50; // 工作：更浅蓝色
      case 'personal':
        return Colors.red.shade50; // 个人：更浅红色
      case 'study':
      case 'learning':
        return Colors.orange.shade50; // 学习：更浅橙色
      case 'meeting':
        return Colors.purple.shade50; // 会议：更浅紫色
      default:
        return Colors.grey.shade50; // 未分类：更浅灰色
    }
  }

  // 获取类别对应的深色强调色（用于标题/文字）
  Color _getLogAccentColor(dynamic log) {
    final category = log.category?.toString() ?? '';
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue.shade700;
      case 'personal':
        return Colors.red.shade700;
      case 'study':
      case 'learning':
        return Colors.orange.shade700;
      case 'meeting':
        return Colors.purple.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // 获取分类标签（中文）
  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return '工作';
      case 'meeting':
        return '会议';
      case 'learning':
      case 'study':
        return '学习';
      case 'personal':
        return '个人';
      case 'health':
        return '健康';
      default:
        return category; // 如果无法识别，返回原值
    }
  }

  // 获取天气标签（中文）
  String _getWeatherLabel(String weather) {
    return _convertWeatherToLabel(weather);
  }

  // 转换天气为标签（辅助方法，可在闭包内使用）
  String _convertWeatherToLabel(String weather) {
    switch (weather.toLowerCase()) {
      case 'sunny':
        return '☀️ 晴天';
      case 'cloudy':
        return '⛅ 多云';
      case 'light_rain':
        return '🌧️ 小雨';
      case 'heavy_rain':
        return '⛈️ 大雨';
      case 'snow':
        return '❄️ 雪';
      case 'storm':
        return '⚡ 暴风雨';
      case 'fog':
        return '🌫️ 雾';
      default:
        return weather; // 如果无法识别，返回原值
    }
  }

  // 构建日历图片
  Widget _buildCalendarImage(String path, {double width = 120, double height = 90}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildBrokenCalendarImage(width: width, height: height),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return _buildBrokenCalendarImage(width: width, height: height);
  }

  Widget _buildBrokenCalendarImage({double width = 120, double height = 90}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  // 显示图片预览
  Future<void> _showCalendarImagePreview(BuildContext context, String path) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(32),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: path.startsWith('http')
                      ? Image.network(path, fit: BoxFit.contain)
                      : Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 本月任务对话框
class _MonthlyTasksDialog extends StatefulWidget {
  final List<DayData> daysWithTasks;
  final DateTime currentMonth;

  const _MonthlyTasksDialog({
    required this.daysWithTasks,
    required this.currentMonth,
  });

  @override
  State<_MonthlyTasksDialog> createState() => _MonthlyTasksDialogState();
}

class _MonthlyTasksDialogState extends State<_MonthlyTasksDialog> {
  int _currentDayIndex = 0;
  bool _isInitialized = false;

  /// 仅用于"本月任务"对话框内部的时间解析
  /// 统一使用与主视图相同的时间解析逻辑，确保与所有视图时间一致
  DateTime _parseTaskTimeForMonthlyDialog(String timeStr) {
    // 如果字符串包含时区信息（Z或+/-），按标准方式解析
    if (timeStr.endsWith('Z') || (timeStr.contains('+') || timeStr.contains('-')) && timeStr.length > 19) {
      final dateTime = DateTime.parse(timeStr);
      // 如果解析后是UTC时间，转换为本地时间
      if (dateTime.isUtc) {
        return dateTime.toLocal();
      }
      return dateTime;
    } else {
      // 没有时区信息，假设是本地时间字符串（后端返回的格式）
      // 直接解析为本地时间，不做时区转换
      var normalized = timeStr.trim();
      if (!normalized.contains('T') && normalized.contains(' ')) {
        normalized = normalized.replaceFirst(' ', 'T');
      }
      final dateTime = DateTime.parse(normalized);
      // 如果解析后是UTC时间，转换为本地时间；否则直接返回
      return dateTime.isUtc ? dateTime.toLocal() : dateTime;
    }
  }

  /// 构造本月任务对话框中“开始-结束”时间段文案
  /// 统一格式：MM-dd HH:mm - MM-dd HH:mm
  String _buildMonthlyTaskTimeRange(CalendarTask task) {
    if (task.isAllDay == true) {
      return '全天';
    }
    if (task.startTime == null || task.endTime == null) {
      return '时间未设置';
    }

    final start = _parseTaskTimeForMonthlyDialog(task.startTime!);
    final end = _parseTaskTimeForMonthlyDialog(task.endTime!);
    final fmt = DateFormat('MM-dd HH:mm');
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('zh_CN', null);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Color _priorityColor(dynamic priority) {
    final p = priority?.toString().toLowerCase() ?? '';
    switch (p) {
      case 'high':
      case 'urgent':
      case 'p1':
        return Colors.red.shade200;
      case 'medium':
      case 'p2':
        return Colors.orange.shade200;
      case 'low':
      case 'p3':
      default:
        return Colors.blue.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentDay = widget.daysWithTasks[_currentDayIndex];
    final dayDate = DateTime.parse(currentDay.date);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment, color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本月任务',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          '${widget.currentMonth.year}年${widget.currentMonth.month}月',
                          style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

            // 日期切换
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentDayIndex > 0
                        ? () => setState(() => _currentDayIndex--)
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentDayIndex > 0 ? Colors.blue.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          DateFormat('M月d日', 'zh_CN').format(dayDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE', 'zh_CN').format(dayDate),
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _currentDayIndex < widget.daysWithTasks.length - 1
                        ? () => setState(() => _currentDayIndex++)
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _currentDayIndex < widget.daysWithTasks.length - 1
                          ? Colors.blue.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),

            // 内容
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentDay.tasks.length,
                itemBuilder: (context, index) {
                  final task = currentDay.tasks[index];
                  final status = task.status?.toString() ?? '';
                  final isCompleted = status == 'completed' || status == 'done';

                  return GestureDetector(
                    onTap: () => _showTaskDetailDialog(task),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompleted ? Colors.grey.shade300 : Colors.blue.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.assignment,
                              size: 18,
                              color: isCompleted ? Colors.green : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.title ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 优先级
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _priorityColor(task.priority).withOpacity(0.3),
                                border: Border.all(color: _priorityColor(task.priority)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (task.priority?.toString().toUpperCase() ?? 'P3'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 状态
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                                border: Border.all(color: isCompleted ? Colors.green.shade300 : Colors.orange.shade300),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isCompleted ? '已完成' : '进行中',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if ((task.startTime != null && task.endTime != null) || (task.isAllDay == true))
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(
                                _buildMonthlyTaskTimeRange(task),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        if ((task.description?.toString().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.description ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                          ),
                        ],
                        if (task.attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: task.attachments.length,
                              itemBuilder: (context, imgIndex) {
                                final path = task.attachments[imgIndex];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _showCalendarImagePreview(context, path),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildCalendarImage(
                                        path,
                                        width: 100,
                                        height: 80,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示任务详情对话框
  void _showTaskDetailDialog(CalendarTask task) {
    final status = task.status?.toString() ?? '';
    final isCompleted = status == 'completed' || status == 'done';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.assignment, color: Colors.blue.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title ?? '无标题',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          if (task.assigneeName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '负责人: ${task.assigneeName}',
                              style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),

              // 任务详情内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态和优先级
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                              border: Border.all(
                                color: isCompleted ? Colors.green.shade300 : Colors.orange.shade300,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isCompleted ? '已完成' : '进行中',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority).withOpacity(0.3),
                              border: Border.all(color: _priorityColor(task.priority)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '优先级: ${(task.priority?.toString().toUpperCase() ?? 'P3')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 时间信息（本月任务详情，要求带月日并修正多出的 8 小时）
                      if ((task.startTime != null && task.endTime != null) || (task.isAllDay == true)) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.isAllDay == true
                                    ? '全天任务'
                                    : _buildMonthlyTaskTimeRange(task),
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // 截止时间（同样按“本月任务”规则减 8 小时并带月日）
                      if (task.deadline != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.event, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              '截止时间: ${DateFormat('MM-dd HH:mm').format(_parseTaskTimeForMonthlyDialog(task.deadline!))}',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],

                      // 任务描述
                      if ((task.description?.toString().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    '任务内容',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                task.description ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 附件
                      if (task.attachments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '附件',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: task.attachments.length,
                            itemBuilder: (context, imgIndex) {
                              final path = task.attachments[imgIndex];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _showCalendarImagePreview(context, path),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildCalendarImage(
                                      path,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建日历图片
  Widget _buildCalendarImage(String path, {double width = 120, double height = 90}) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildBrokenCalendarImage(width: width, height: height),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return _buildBrokenCalendarImage(width: width, height: height);
  }

  Widget _buildBrokenCalendarImage({double width = 120, double height = 90}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  // 显示图片预览
  Future<void> _showCalendarImagePreview(BuildContext context, String path) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(32),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: path.startsWith('http')
                      ? Image.network(path, fit: BoxFit.contain)
                      : Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyTaskEntry {
  final CalendarTask task;
  final DateTime anchorDay;

  const _MonthlyTaskEntry({
    required this.task,
    required this.anchorDay,
  });
}

/// 月视图任务编辑对话框（美观版）
class _CalendarTaskEditDialog extends StatefulWidget {
  final CalendarTask task;
  final DateTime initialDate;

  const _CalendarTaskEditDialog({
    required this.task,
    required this.initialDate,
  });

  @override
  State<_CalendarTaskEditDialog> createState() => _CalendarTaskEditDialogState();
}

class _CalendarTaskEditDialogState extends State<_CalendarTaskEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String _selectedPriority = 'p2';
  String _selectedStatus = 'pending';
  double _progress = 0;

  late List<String> _persistedAttachments;
  final List<File> _newImages = [];

  static const Map<String, String> _priorityLabels = {
    'p0': '重要且紧急',
    'p1': '重要不紧急',
    'p2': '不重要紧急',
    'p3': '不重要不紧急',
  };

  static const Map<String, String> _statusLabels = {
    'pending': '待处理',
    'in_progress': '进行中',
    'completed': '已完成',
    'cancelled': '已取消',
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedPriority = widget.task.priority;
    _selectedStatus = widget.task.status;
    _progress = widget.task is Task
        ? (widget.task as Task).progressPercentage.toDouble()
        : 0;
    _persistedAttachments = List<String>.from(widget.task.attachments);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery.of(context).size.width * 0.9, 800),
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleAndStatusRow(),
                      const SizedBox(height: 16),
                      _buildDescriptionInput(),
                      const SizedBox(height: 16),
                      _buildImageSection(),
                      const SizedBox(height: 16),
                      _buildProgressSection(),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final dateStr = DateFormat('yyyy年MM月dd日').format(widget.initialDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        color: Theme.of(context).primaryColor.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '编辑任务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleAndStatusRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '标题',
            hintText: '请输入任务标题',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 1,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '标题不能为空';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPriorityDropdown(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusDropdown(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '优先级',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPriority,
          isExpanded: true,
          items: _priorityLabels.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedPriority = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '状态',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          items: _statusLabels.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedStatus = value;
              if (_selectedStatus == 'completed') {
                _progress = 100;
              } else if (_progress == 100) {
                _progress = 90;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: '内容',
        hintText: '请输入任务内容（可选）',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: 4,
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '图片',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('相册'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('拍照'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_persistedAttachments.isEmpty && _newImages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  '暂无图片，点击上方按钮添加',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._persistedAttachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final path = entry.value;
                  return _buildImageThumbnail(
                    image: _buildPersistedAttachment(path),
                    onRemove: () {
                      setState(() {
                        _persistedAttachments.removeAt(index);
                      });
                    },
                  );
                }),
                ..._newImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return _buildImageThumbnail(
                    image: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
                    onRemove: () {
                      setState(() {
                        _newImages.removeAt(index);
                      });
                    },
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPersistedAttachment(String path) {
    const double thumbSize = 100;
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: thumbSize,
        height: thumbSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildBrokenCalendarImage(width: thumbSize, height: thumbSize),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: thumbSize,
        height: thumbSize,
        fit: BoxFit.cover,
      );
    }
    return _buildBrokenCalendarImage(width: thumbSize, height: thumbSize);
  }

  Widget _buildImageThumbnail({required Widget image, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '完成度',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _progress,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_progress.round()}%',
                onChanged: (value) {
                  setState(() {
                    _progress = value;
                    if (_progress == 100) {
                      _selectedStatus = 'completed';
                    } else if (_progress > 0 && _selectedStatus == 'pending') {
                      _selectedStatus = 'in_progress';
                    }
                  });
                },
              ),
            ),
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_progress.round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        color: Colors.grey.shade50,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _newImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final result = _CalendarTaskEditResult(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      status: _selectedStatus,
      progressPercentage: _progress.round(),
      persistedAttachments: List<String>.from(_persistedAttachments),
      newImages: List<File>.from(_newImages),
    );

    Navigator.of(context).pop(result);
  }
}
