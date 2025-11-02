import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/task.dart';
import '../services/calendar_service.dart';

enum CalendarView { month, week, day }

class CalendarWidget extends StatefulWidget {
  final List<Task> tasks;
  final DateTime currentDate;
  final Function(DateTime) onDateSelected;
  final Function(Task) onTaskSelected;
  final Function(DateTime) onTaskAdd;
  final Function(DateTime) onLogAdd;

  const CalendarWidget({
    super.key,
    required this.tasks,
    required this.currentDate,
    required this.onDateSelected,
    required this.onTaskSelected,
    required this.onTaskAdd,
    required this.onLogAdd,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarView _currentView = CalendarView.month;
  DateTime _currentDate = DateTime.now();
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
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
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
        const SizedBox(height: 16),
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
            margin: const EdgeInsets.all(16),
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
                  height: 300,
                  padding: const EdgeInsets.all(4),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isCurrentMonth = day.month == _currentDate.month;
                      final isToday = _isSameDay(day, DateTime.now());

                      // 获取该日期的数据
                      final dayData = _getDayData(day);
                      final hasData = dayData != null && dayData.hasData;

                      return GestureDetector(
                        onTap: () => _onDateTapped(day),
                        onLongPress: () => widget.onTaskAdd(day),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: isToday
                                ? Border.all(
                                    color: Colors.blue.shade300,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isCurrentMonth
                                      ? (isToday ? Colors.blue.shade700 : Colors.grey.shade800)
                                      : Colors.grey.shade300,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 15,
                                ),
                              ),
                              // 数据指示器 - 简约版
                              if (hasData) ...[
                                const SizedBox(height: 3),
                                _buildBeautifiedDataIndicators(dayData),
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
              final isToday = _isSameDay(day, DateTime.now());
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
    if (task.startTime == null || task.endTime == null) {
      return const SizedBox.shrink();
    }

    try {
      // 直接从ISO字符串提取日期部分，避免时区转换
      final taskStartDate = _extractDateFromISO(task.startTime!);
      final taskEndDate = _extractDateFromISO(task.endTime!);

      // 找出任务在本周的起始和结束位置
      int? startIndex;
      int? endIndex;

      for (int i = 0; i < weekDays.length; i++) {
        final day = weekDays[i];
        final dayOnly = DateTime(day.year, day.month, day.day);

        // 检查任务是否覆盖这一天
        if (dayOnly.isAtSameMomentAs(taskStartDate) ||
            (dayOnly.isAfter(taskStartDate) && dayOnly.isBefore(taskEndDate)) ||
            dayOnly.isAtSameMomentAs(taskEndDate)) {
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
      print('Error parsing task dates: $e');
      return const SizedBox.shrink();
    }
  }

  // 构建甘特图日志条
  Widget _buildGanttLogBar(CalendarLog log, List<DateTime> weekDays, {VoidCallback? onTap}) {
    if (log.createdAt == null) {
      return const SizedBox.shrink();
    }

    try {
      // 日志只显示在创建当天
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
      // 只有非全天任务且有具体开始和结束时间的才显示在时间轴
      // 全天任务或没有时间的任务显示在"无具体时间段"区域
      if (task.startTime != null && task.endTime != null && task.isAllDay == false) {
        tasksWithTime.add(task);
      } else {
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
            const SizedBox(height: 12),
            _buildTimelineView(tasksWithTime, logsWithTime),
            const SizedBox(height: 24),
          ],
          
          // 4. 无时间段区域
          if (tasksWithoutTime.isNotEmpty || logsWithoutTime.isNotEmpty) ...[
            _buildSectionTitle('无具体时间段'),
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
  }) {
    return Column(
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
  }

  // 区域标题
  Widget _buildSectionTitle(String title) {
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
    
    return Container(
      height: 60.0 * 24, // 每小时60像素高度
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
      child: Row(
        children: [
          // 时间轴
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: hours.map((hour) {
                return Container(
                  height: 60,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // 任务和日志区域
          Expanded(
            child: Stack(
              children: [
                // 时间网格背景
                Column(
                  children: hours.map((hour) {
                    return Container(
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // 任务和日志
                ...tasks.map((task) => _buildTaskInTimeline(task)),
                ...logs.map((log) => _buildLogInTimeline(log)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 在时间轴中显示任务
  Widget _buildTaskInTimeline(CalendarTask task) {
    if (task.startTime == null || task.endTime == null) {
      return const SizedBox.shrink();
    }
    
    try {
      final startTime = DateTime.parse(task.startTime!);
      final endTime = DateTime.parse(task.endTime!);
      
      final startHour = startTime.hour + startTime.minute / 60.0;
      final endHour = endTime.hour + endTime.minute / 60.0;
      final duration = endHour - startHour;
      
      if (duration <= 0) return const SizedBox.shrink();

      return Positioned(
        top: startHour * 60,
        left: 4,
        right: 4,
        child: Container(
          height: duration * 60 - 4,
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
            padding: const EdgeInsets.all(6),
            child: Column(
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                if (duration * 60 > 50 && task.description.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  // 在时间轴中显示日志
  Widget _buildLogInTimeline(CalendarLog log) {
    // 日志当前没有时间字段，所以不在时间轴中显示
    return const SizedBox.shrink();
  }

  // 无时间段区域
  Widget _buildNoTimeSection(List<CalendarTask> tasks, List<CalendarLog> logs) {
    return Column(
      children: [
        // 无时间段的任务
        if (tasks.isNotEmpty) ...[
          ...tasks.map((task) => Container(
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
          )),
        ],
        
        // 无时间段的日志
        if (logs.isNotEmpty) ...[
          ...logs.map((log) => Container(
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

    final totalTasks = _monthViewData!.summary.totalTasks;
    final totalLogs = _monthViewData!.summary.totalLogs;
    final completedTasks = _monthViewData!.days.fold<int>(
      0,
      (sum, day) => sum + day.tasks.where((t) => t.status == 'completed').length
    );
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
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
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

    // 收集所有任务
    final allTasks = <Map<String, dynamic>>[];
    for (final day in _monthViewData!.days) {
      for (final task in day.tasks) {
        allTasks.add({
          'task': task,
          'date': day.date,
          'day': DateTime.parse(day.date),
        });
      }
    }

    // 根据筛选条件过滤任务
    final filteredTasks = allTasks.where((item) {
      final task = item['task'] as CalendarTask;
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
                    itemBuilder: (context, index) {
                      final item = filteredTasks[index];
                      final task = item['task'] as CalendarTask;
                      final date = item['date'] as String;
                      final day = item['day'] as DateTime;

                      return _buildTaskListItem(task, date, day);
                    },
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
  Widget _buildTaskListItem(CalendarTask task, String date, DateTime day) {
    final statusColor = _getStatusColor(task.status);
    final statusText = _getStatusText(task.status);

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
                Text(
                  '${day.month}/${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
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
        trailing: IconButton(
          icon: Icon(
            Icons.visibility,
            color: Colors.blue.shade400,
            size: 18,
          ),
          onPressed: () => _showTaskDetail(task, day),
          tooltip: '查看详情',
        ),
      ),
    );
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
                                          _showEditLogDialog(context, log, day);
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

                // 底部按钮栏
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onTaskAdd(day);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_task),
                          label: const Text(
                            '添加任务',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onLogAdd(day);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note),
                          label: const Text(
                            '添加日志',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
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
                            '${day.year}年${day.month}月${day.day}日',
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

              // 底部按钮栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditTaskDialog(context, task, day);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text(
                          '编辑任务',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteTask(context, task, day);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text(
                          '删除任务',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    switch (category.toLowerCase()) {
      case 'work':
        return '工作';
      case 'meeting':
        return '会议';
      case 'learning':
        return '学习';
      case 'personal':
        return '个人';
      default:
        return '其他';
    }
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
        return '已取消';
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
    switch (category.toLowerCase()) {
      case 'work':
        return '工作';
      case 'meeting':
        return '会议';
      case 'learning':
        return '学习';
      case 'personal':
        return '个人';
      default:
        return '其他';
    }
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
        return Colors.grey;
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

  // 显示编辑任务对话框
  Future<void> _showEditTaskDialog(BuildContext context, CalendarTask task, DateTime day) async {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    String? selectedPriority = task.priority;
    String? selectedStatus = task.status;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑任务'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('标题:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: '请输入任务标题',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),
                    const Text('内容:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        hintText: '请输入任务内容',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text('优先级:'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedPriority,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'p0', child: Text('P0 - 最高')),
                        DropdownMenuItem(value: 'p1', child: Text('P1 - 高')),
                        DropdownMenuItem(value: 'p2', child: Text('P2 - 中')),
                        DropdownMenuItem(value: 'p3', child: Text('P3 - 低')),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          selectedPriority = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('完成状态:'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('待处理')),
                        DropdownMenuItem(value: 'in_progress', child: Text('进行中')),
                        DropdownMenuItem(value: 'completed', child: Text('已完成')),
                        DropdownMenuItem(value: 'cancelled', child: Text('已取消')),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('标题不能为空'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'priority': selectedPriority ?? 'p2',
                      'status': selectedStatus ?? 'pending',
                    });
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
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
    Map<String, String> updates,
    DateTime day,
  ) async {
    try {
      await CalendarService.updateTask(
        task.id,
        title: updates['title'],
        description: updates['description'],
        priority: updates['priority'],
        status: updates['status'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务更新成功'),
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
          // 重新加载日期详情
          Navigator.of(context).pop();
          _showDayDetail(day);
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
  Future<void> _showEditLogDialog(BuildContext context, CalendarLog log, DateTime day) async {
    final titleController = TextEditingController(text: log.title);
    final contentController = TextEditingController(text: log.content);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑日志'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('标题:'),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '请输入日志标题',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('内容:'),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '请输入日志内容',
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'title': titleController.text,
                  'content': contentController.text,
                });
              },
              child: const Text('保存'),
            ),
          ],
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
    Map<String, String> updates,
    DateTime day,
  ) async {
    try {
      await CalendarService.updateLog(
        log.id,
        title: updates['title'],
        content: updates['content'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('日志更新成功'),
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
  String _formatDateTimeString(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return '';
    }

    try {
      // 解析 ISO 8601 格式的字符串 (例如: 2025-10-01T02:00:00.000Z)
      final dateTime = DateTime.parse(dateTimeStr);

      // 转换为本地时区
      final localDateTime = dateTime.toLocal();

      // 格式化为中文格式: 2025年10月1日 10:00
      return DateFormat('yyyy年M月d日 HH:mm', 'zh_CN').format(localDateTime);
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
                    child: SelectableText(
                      content.isNotEmpty ? content : '无内容',
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                        height: 1.6,
                      ),
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

  // 格式化日志创建时间
  String _formatLogCreatedTime(String timeStr) {
    try {
      final dateTime = DateTime.parse(timeStr);
      final localDateTime = dateTime.toLocal();
      return DateFormat('HH:mm', 'zh_CN').format(localDateTime);
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
                    // 时间
                    if (log.createdAt != null)
                      Text(
                        _formatLogTime(log.createdAt.toString()),
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLogTime(String timeStr) {
    try {
      final dateTime = DateTime.parse(timeStr);
      final localDateTime = dateTime.toLocal();
      return DateFormat('HH:mm', 'zh_CN').format(localDateTime);
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
        final String timeStr = log.createdAt != null
            ? _formatLogTime(log.createdAt.toString())
            : '';
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
                    child: SelectableText(
                      content.isNotEmpty ? content : '无内容',
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                        height: 1.6,
                      ),
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

                  return Container(
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
                                task.isAllDay == true
                                    ? '全天'
                                    : '${DateFormat('HH:mm').format(DateTime.parse(task.startTime!))} - ${DateFormat('HH:mm').format(DateTime.parse(task.endTime!))}',
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
                      ],
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
}
