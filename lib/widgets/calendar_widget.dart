import 'package:flutter/material.dart';
import '../models/task.dart';

enum CalendarView { month, week, day }

class CalendarWidget extends StatefulWidget {
  final List<Task> tasks;
  final DateTime currentDate;
  final Function(DateTime) onDateSelected;
  final Function(Task) onTaskSelected;
  final Function(DateTime) onTaskAdd;

  const CalendarWidget({
    super.key,
    required this.tasks,
    required this.currentDate,
    required this.onDateSelected,
    required this.onTaskSelected,
    required this.onTaskAdd,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarView _currentView = CalendarView.month;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentDate = widget.currentDate;
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
    widget.onDateSelected(_currentDate);
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
              final dayTasks = _getTasksForDay(day);

              return GestureDetector(
                onTap: () {
                  widget.onDateSelected(day);
                },
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
                      Expanded(
                        child: ListView.builder(
                          itemCount: dayTasks.length > 3 ? 3 : dayTasks.length,
                          itemBuilder: (context, taskIndex) {
                            final task = dayTasks[taskIndex];
                            return GestureDetector(
                              onTap: () => widget.onTaskSelected(task),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: task.status == 'completed' ? Colors.grey : _parseColor(task.color),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: task.status == 'completed' ? Colors.white70 : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (dayTasks.length > 3)
                        Text(
                          '+${dayTasks.length - 3}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
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
              final dayTasks = _getTasksForDay(day);
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDateSelected(day),
                  onLongPress: () => widget.onTaskAdd(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: dayTasks.length,
                      itemBuilder: (context, index) {
                        final task = dayTasks[index];
                        return GestureDetector(
                          onTap: () => widget.onTaskSelected(task),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: task.status == 'completed' ? Colors.grey : _parseColor(task.color),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.title,
                              style: TextStyle(
                                color: task.status == 'completed' ? Colors.white70 : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
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
            color: task.status == 'completed' ? Colors.grey : _parseColor(task.color),
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
}
