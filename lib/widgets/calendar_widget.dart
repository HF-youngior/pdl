import 'package:flutter/material.dart';
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
  bool _isLoading = false;
  String? _error;

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
    
    // 如果是月视图，重新加载数据并显示提示
    if (_currentView == CalendarView.month) {
      _loadMonthViewData(showToast: true);
      // 月视图切换时不触发日期选择事件，避免弹出浮窗
    } else if (_currentView == CalendarView.week) {
      _loadWeekViewData();
    } else {
      // 日视图切换时才触发日期选择事件
      widget.onDateSelected(_currentDate);
    }
  }

  Future<void> _loadMonthViewData({bool showToast = false}) async {
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

      // 如果需要显示提示（切换月份时）
      if (showToast && mounted) {
        final totalTasks = monthData.days.fold<int>(
          0, 
          (sum, day) => sum + day.tasks.length
        );
        final totalLogs = monthData.days.fold<int>(
          0, 
          (sum, day) => sum + day.logs.length
        );
        
        String message;
        if (totalTasks == 0 && totalLogs == 0) {
          message = '本月没有任务和日志';
        } else {
          message = '本月有 $totalTasks 个任务、$totalLogs 个日志';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: totalTasks == 0 && totalLogs == 0 
              ? Colors.grey[600] 
              : Theme.of(context).primaryColor,
          ),
        );
      }
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

  Widget _buildViewSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildViewButton('月', CalendarView.month),
        const SizedBox(width: 8),
        _buildViewButton('周', CalendarView.week),
        const SizedBox(width: 8),
        _buildViewButton('日', CalendarView.day),
      ],
    );
  }

  Widget _buildViewButton(String label, CalendarView view) {
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () => _changeView(view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).primaryColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
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
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
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

    return Column(
      children: [
        // 星期标题
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // 日期网格
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
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
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isToday ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                    border: isToday ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isCurrentMonth ? Colors.black87 : Colors.grey,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      // 数据指示器
                      if (hasData && dayData != null) ...[
                        const SizedBox(height: 2),
                        _buildDataIndicators(dayData),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekView() {
    final weekStart = _getWeekStart(_currentDate);
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));

    // 如果正在加载，显示加载指示器
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 星期标题
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: weekDays.map((day) {
              final isToday = _isSameDay(day, DateTime.now());
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '${day.month}/${day.day}',
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Theme.of(context).primaryColor : Colors.black87,
                      ),
                    ),
                    Text(
                      ['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // 周视图内容
        Expanded(
          child: Row(
            children: weekDays.map((day) {
              final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final dayData = _weekViewData[dateKey];
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onDateTapped(day),
                  onLongPress: () => widget.onTaskAdd(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: dayData == null 
                      ? const Center(child: Text(''))
                      : ListView(
                          padding: const EdgeInsets.all(2),
                          children: [
                            // 任务列表
                            ...dayData.tasks.map((task) => GestureDetector(
                              onTap: () => _onDateTapped(day),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: task.status == 'completed' ? Colors.grey : _getTaskColor(task),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )),
                            // 日志列表
                            ...dayData.logs.map((log) => GestureDetector(
                              onTap: () => _onDateTapped(day),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _getLogColor(log),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )),
                          ],
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDayView() {
    final dayTasks = _getTasksForDay(_currentDate);
    final hours = List.generate(24, (index) => index);

    return Row(
      children: [
        // 时间轴
        SizedBox(
          width: 60,
          child: Column(
            children: hours.map((hour) {
              return Container(
                height: 60,
                alignment: Alignment.topCenter,
                child: Text(
                  '$hour:00',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            }).toList(),
          ),
        ),
        // 任务区域
        Expanded(
          child: Stack(
            children: [
              // 时间网格
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
              // 任务
              ...dayTasks.map((task) => _buildTaskInDayView(task)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInDayView(Task task) {
    final startHour = task.startTime.hour + task.startTime.minute / 60.0;
    final endHour = task.endTime.hour + task.endTime.minute / 60.0;
    final duration = endHour - startHour;

    return Positioned(
      top: startHour * 60,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => widget.onTaskSelected(task),
        child: Container(
          height: duration * 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: task.status == 'completed' ? Colors.grey : Colors.red.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.status == 'completed' ? Colors.white70 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.location != null)
                  Text(
                    task.location!,
                    style: TextStyle(
                      color: task.status == 'completed' ? Colors.white60 : Colors.white70,
                      fontSize: 10,
                      decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Task> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) {
      return _isSameDay(task.startTime, day) || 
             _isSameDay(task.endTime, day) ||
             (task.startTime.isBefore(day) && task.endTime.isAfter(day));
    }).toList();
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
        return Colors.grey;
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
                      'priority': selectedPriority!,
                      'status': selectedStatus!,
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
}
