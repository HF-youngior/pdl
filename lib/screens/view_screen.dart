import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../widgets/calendar_widget.dart';
import 'task_edit_screen.dart';

class ViewScreen extends StatefulWidget {
  final User user;

  const ViewScreen({
    super.key,
    required this.user,
  });

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}


class _ViewScreenState extends State<ViewScreen> {
  // === 核心状态变量 ===
  List<Task> _allTasks = [];      // 从API获取的所有任务
  List<Task> _filteredTasks = [];    // 筛选后的任务列表
  String _selectedView = 'month';     // month, week, day
  String _selectedFilter = 'all';     // all, pending, completed
  DateTime _currentDate = DateTime.now(); // 基准日期
  
  // === UI状态变量 ===
  bool _isLoading = false;
  String? _error;
  bool _isCalendarExpanded = true;    // 日历展开状态（仅月任务视图）
  
  // === 筛选选项 ===
  final Map<String, String> _viewOptions = {
    'month': '月任务',
    'week': '周任务', 
    'day': '日任务',
  };
  
  final Map<String, String> _filterOptions = {
    'all': '全部任务',
    'pending': '待处理',
    'completed': '已完成',
  };

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // === 数据加载 ===
  Future<void> _loadTasks() async {
      setState(() {
        _isLoading = true;
        _error = null;
      });

    try {
      final tasks = await TaskService.getTasks();
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
      _filterAndSortTasks();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // === 核心筛选排序逻辑 ===
  void _filterAndSortTasks() {
    List<Task> filteredTasks = List.from(_allTasks);
    
    // 1. 时间范围筛选
    filteredTasks = _filterByTimeRange(filteredTasks);
    
    // 2. 状态筛选
    filteredTasks = _filterByStatus(filteredTasks);
    
    // 3. 强制排序
    filteredTasks = _sortTasks(filteredTasks);
    
    setState(() {
      _filteredTasks = filteredTasks;
    });
  }

  // === 时间范围筛选 ===
  List<Task> _filterByTimeRange(List<Task> tasks) {
    switch (_selectedView) {
      case 'month':
        return _filterByMonth(tasks, _currentDate);
      case 'week':
        return _filterByWeek(tasks, _currentDate);
      case 'day':
        return _filterByDay(tasks, _currentDate);
      default:
        return tasks;
    }
  }

  // === 状态筛选 ===
  List<Task> _filterByStatus(List<Task> tasks) {
    switch (_selectedFilter) {
      case 'pending':
        return tasks.where((task) => 
          task.status == 'pending' || task.status == 'in_progress').toList();
      case 'completed':
        return tasks.where((task) => task.status == 'completed').toList();
      case 'all':
      default:
        return tasks;
    }
  }

  // === 强制排序 ===
  List<Task> _sortTasks(List<Task> tasks) {
    tasks.sort((a, b) {
      // 1. 优先级排序 (P0 > P1 > P2 > P3)
      int priorityComparison = _getPriorityWeight(a.priority).compareTo(_getPriorityWeight(b.priority));
      if (priorityComparison != 0) return priorityComparison;
      
      // 2. 优先级相同时按截止日期排序
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      } else if (a.deadline != null) {
        return -1;
      } else if (b.deadline != null) {
        return 1;
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    });
    
    return tasks;
  }

  // === 日期范围计算辅助方法 ===
  List<Task> _filterByMonth(List<Task> tasks, DateTime date) {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    
    return tasks.where((task) {
      return task.startTime.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
             task.startTime.isBefore(endOfMonth.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<Task> _filterByWeek(List<Task> tasks, DateTime date) {
    final weekday = date.weekday;
    final startOfWeek = date.subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    return tasks.where((task) {
      return task.startTime.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
             task.startTime.isBefore(endOfWeek.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<Task> _filterByDay(List<Task> tasks, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    
    return tasks.where((task) {
      return task.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
             task.startTime.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();
  }

  // === 优先级权重 ===
  int _getPriorityWeight(String priority) {
    switch (priority) {
      case 'p0': return 0;
      case 'p1': return 1;
      case 'p2': return 2;
      case 'p3': return 3;
      default: return 4;
    }
  }

  // === 事件处理 ===
  void _onViewChanged(String view) {
    setState(() {
      _selectedView = view;
      // 切换到非月任务视图时，自动展开日历
      if (view != 'month') {
        _isCalendarExpanded = true;
      }
    });
    _filterAndSortTasks();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterAndSortTasks();
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _currentDate = date;
    });
    _filterAndSortTasks();
  }

  void _toggleCalendarExpansion() {
    setState(() {
      _isCalendarExpanded = !_isCalendarExpanded;
    });
  }

  // === 任务操作 ===
  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      final newStatus = task.status == 'completed' ? 'pending' : 'completed';
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        assigneeId: task.assigneeId,
        assigneeName: task.assigneeName,
        department: task.department,
        priority: task.priority,
        status: newStatus,
        createdAt: task.createdAt,
        deadline: task.deadline,
        createdBy: task.createdBy,
        startTime: task.startTime,
        endTime: task.endTime,
        color: task.color,
        location: task.location,
        isAllDay: task.isAllDay,
        progressPercentage: newStatus == 'completed' ? 100 : task.progressPercentage,
      );

      await TaskService.updateTask(task.id, updatedTask);
      await _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'completed' ? '任务已完成' : '任务已重新激活'),
            backgroundColor: newStatus == 'completed' ? Colors.green : Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('状态更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTask() async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          currentUser: widget.user,
        ),
      ),
    );

    if (result != null) {
      await _loadTasks();
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: task,
          currentUser: widget.user,
        ),
      ),
    );

    if (result != null) {
      await _loadTasks();
    }
  }

  // === UI构建 ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务视图'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createTask,
            tooltip: '创建任务',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0), // 保持外层水平内边距
      child: Column(
        children: [
          // --- 顶部筛选器区域 (固定高度) ---
          Column(
            children: [
              const SizedBox(height: 8), // 顶部留一点空间
              _buildViewToggleButtons(),
              const SizedBox(height: 8.0), // 视图按钮和状态按钮之间的间距
              _buildStatusFilterButtons(),
              const SizedBox(height: 8.0), // 状态按钮和内容区域之间的间距
            ],
          ),
          
          // --- 底部内容区域 (自动填充剩余空间) ---
          Expanded(
            child: _selectedView == 'month' 
                ? _buildMonthView()
                : _buildTaskListView(),
          ),
        ],
      ),
    );
  }

  // === 月任务视图（包含可折叠日历） ===
  Widget _buildMonthView() {
    return Column(
      children: [
        // 可折叠的日历区域
        Stack(
          children: [
            // 日历内容
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isCalendarExpanded ? 1.0 : 0.0,
                child: _isCalendarExpanded
                    ? CalendarWidget(
                        tasks: _allTasks,
                        onDateSelected: _onDateChanged,
                        onTaskSelected: _editTask,
                        selectedDate: _currentDate,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            
            // 右上角的折叠/展开按钮
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: _toggleCalendarExpansion,
                icon: Icon(
                  _isCalendarExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Theme.of(context).primaryColor,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
        
        // 日历收起时显示展开提示和按钮
        if (!_isCalendarExpanded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                // 显示当前选中的日期
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前日期',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy年MM月dd日').format(_currentDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 展开日历按钮
                IconButton(
                  onPressed: _toggleCalendarExpansion,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // 任务列表区域
        Expanded(
          child: _buildTaskList(),
        ),
      ],
    );
  }

  // === 周任务和日任务视图 ===
  Widget _buildTaskListView() {
    // 周视图和日视图直接显示任务列表
    return _buildTaskList();
  }

  // === 视图切换按钮组 (无修改) ===
  Widget _buildViewToggleButtons() {
    return Row(
      children: _viewOptions.entries.map((entry) {
        final isSelected = _selectedView == entry.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // 按钮间距优化
            child: ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) => _onViewChanged(entry.key),
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey.shade100,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 调整高度
              elevation: isSelected ? 2 : 0,
            ),
          ),
        );
      }).toList(),
    );
  }

  // === 状态筛选按钮组 ===
  Widget _buildStatusFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.entries.map((entry) {
          final isSelected = _selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0), // 足够的水平间隔
            child: FilterChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 11, // 减小字体大小
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) => _onFilterChanged(selected ? entry.key : 'all'),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.15), // 选中颜色使用主题色
              backgroundColor: Colors.grey.shade100, // 未选中时背景为浅灰色
              checkmarkColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 减小内边距
              elevation: isSelected ? 1 : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  // === 任务列表 (无修改) ===
  Widget _buildTaskList() {
    if (_filteredTasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        // 将 padding 调整为仅顶部和水平内边距，移除底部的 16，避免双重滚动条或过多的底部空间
        padding: const EdgeInsets.only(top: 8, left: 0, right: 0),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  // === 任务列表项 (无修改) ===
  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0), // 增加卡片垂直外边距
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _editTask(task),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 增加内边距使任务条目更"厚实"
        
        // 左侧：复选框和优先级颜色点
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 任务完成状态复选框
            GestureDetector(
              onTap: () => _toggleTaskCompletion(task),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.status == 'completed' 
                        ? Colors.green 
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: task.status == 'completed' 
                      ? Colors.green 
                      : Colors.transparent,
                ),
                child: task.status == 'completed'
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            
            // 优先级颜色点
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: task.getPriorityColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: task.getPriorityColor().withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // 主内容
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: task.status == 'completed' 
                ? TextDecoration.lineThrough 
                : null,
            color: task.status == 'completed' 
                ? Colors.grey 
                : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            
            // 任务描述
            if (task.description.isNotEmpty) ...[
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  decoration: task.status == 'completed' 
                      ? TextDecoration.lineThrough 
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            
            // 任务信息行 - 只保留优先级和进度标签
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 优先级标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: task.getPriorityColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.getPriorityLabel(),
                    style: TextStyle(
                      color: task.getPriorityColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // 进度百分比
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getProgressColor(task.progressPercentage).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${task.progressPercentage}%',
                    style: TextStyle(
                      color: _getProgressColor(task.progressPercentage),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // 右侧：截止日期和状态标签组合
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 顶部显示截止日期
            if (task.deadline != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: task.isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MM-dd').format(task.deadline!),
                    style: TextStyle(
                      fontSize: 12,
                      color: task.isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // 底部显示状态标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: task.getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: task.getStatusColor().withOpacity(0.3),
                ),
              ),
              child: Text(
                task.getStatusText(),
                style: TextStyle(
                  color: task.getStatusColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 辅助方法 (无修改) ===
  String _getDateRangeText() {
    switch (_selectedView) {
      case 'week':
        final weekday = _currentDate.weekday;
        final startOfWeek = _currentDate.subtract(Duration(days: weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MM月dd日').format(startOfWeek)} - ${DateFormat('MM月dd日').format(endOfWeek)}';
      case 'day':
        return DateFormat('yyyy年MM月dd日').format(_currentDate);
      default:
        return DateFormat('yyyy年MM月').format(_currentDate);
    }
  }

  Color _getProgressColor(int progress) {
    if (progress == 0) return Colors.grey;
    if (progress < 30) return Colors.red;
    if (progress < 60) return Colors.orange;
    if (progress < 90) return Colors.blue;
    if (progress < 100) return Colors.green;
    return Colors.green.shade700;
  }

  Widget _buildErrorState() {
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
          ElevatedButton(onPressed: _loadTasks, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '暂无任务',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 号创建任务',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}