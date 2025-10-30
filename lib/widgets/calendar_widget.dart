import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class CalendarWidget extends StatefulWidget {
  final List<Task> tasks;
  final Function(DateTime) onDateSelected;
  final Function(Task) onTaskSelected;
  final DateTime? selectedDate;

  const CalendarWidget({
    super.key,
    required this.tasks,
    required this.onDateSelected,
    required this.onTaskSelected,
    this.selectedDate,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _selectedDate = widget.selectedDate ?? DateTime.now();
  }

  @override
  void didUpdateWidget(CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate ?? DateTime.now();
    }
  }

  // 获取指定日期的任务
  List<Task> _getTasksForDate(DateTime date) {
    return widget.tasks.where((task) {
      final taskDate = DateTime(task.startTime.year, task.startTime.month, task.startTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return taskDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  // 构建日历网格
  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // 生成日历数据
    List<Widget> calendarDays = [];

    // 添加星期标题
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    for (int i = 0; i < 7; i++) {
      calendarDays.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            weekDays[i],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // 添加空白日期（上个月的末尾日期）
    for (int i = 1; i < firstWeekday; i++) {
      calendarDays.add(Container());
    }

    // 添加当月的日期
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final tasksForDate = _getTasksForDate(date);
      final isSelected = date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;
      final isToday = date.year == DateTime.now().year &&
                     date.month == DateTime.now().month &&
                     date.day == DateTime.now().day;

      calendarDays.add(_buildDayCell(date, tasksForDate, isSelected, isToday));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: calendarDays,
    );
  }

  // 构建日期单元格
  Widget _buildDayCell(DateTime date, List<Task> tasks, bool isSelected, bool isToday) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        widget.onDateSelected(date);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : isToday
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
              ),
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 2),
              // 任务指示点
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: tasks.take(3).map((task) {
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: task.getPriorityColor(),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
              if (tasks.length > 3)
                Text(
                  '+${tasks.length - 3}',
          style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
          ),
            ],
          ],
        ),
      ),
    );
  }

  // 构建月份导航
  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat('yyyy年MM月').format(_currentMonth),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // 构建选中日期的任务列表
Widget _buildSelectedDateTasks() {
  final selectedTasks = _getTasksForDate(_selectedDate);
  
  if (selectedTasks.isEmpty) {
    return Expanded(  // 添加 Expanded 包裹
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            '${DateFormat('MM月dd日').format(_selectedDate)} 暂无任务',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  return Expanded(  // 添加 Expanded 包裹
    child: Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MM月dd日').format(_selectedDate)} 的任务',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(  // 这个 Expanded 保持不变，让任务列表在 Column 中可滚动
            child: ListView.builder(
              itemCount: selectedTasks.length,
              itemBuilder: (context, index) {
                final task = selectedTasks[index];
                return _buildTaskItem(task);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  // 构建任务项
  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4), // 减少间距
      elevation: 1, // 减少阴影
      child: ListTile(
        dense: true, // 使用紧凑模式
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 减少内边距
        leading: Container(
          width: 6, // 减小指示点大小
          height: 6,
          decoration: BoxDecoration(
            color: task.getPriorityColor(),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontSize: 12), // 减小字体
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 10, // 减小字体
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // 减少内边距
                  decoration: BoxDecoration(
                    color: task.getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.getStatusText(),
                    style: TextStyle(
                      fontSize: 8, // 减小字体
                      color: task.getStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  task.getPriorityLabel(),
                  style: TextStyle(
                    fontSize: 8, // 减小字体
                    color: task.getPriorityColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => widget.onTaskSelected(task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 月份导航
        _buildMonthNavigation(),
        
        const SizedBox(height: 12), // 减少间距
        
        // 日历网格
        Container(
          padding: const EdgeInsets.all(12), // 减少内边距
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildCalendarGrid(),
        ),
        
        const SizedBox(height: 12), // 减少间距
        
        // 选中日期的任务列表 - 增加高度，确保标签完全显示
        Container(
          height: 200, // 增加高度，确保选中日期任务标签完全显示
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildSelectedDateTasks(),
        ),
      ],
    );
  }
}