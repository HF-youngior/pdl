import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../widgets/calendar_widget.dart';
import '../utils/test_data_generator.dart';
import 'task_edit_screen.dart';
import 'api_test_screen.dart';
import 'log_edit_screen.dart';

class ViewScreen extends StatefulWidget {
  final User user;
  
  const ViewScreen({super.key, required this.user});

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  List<Task> _tasks = [];
  DateTime _currentDate = DateTime.now();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 月视图现在使用新的API，不需要在这里加载任务数据
    setState(() {
      _isLoading = false;
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _currentDate = date;
    });
    
    // 显示该日期的任务列表
    _showDateTasks(date);
  }

  void _showDateTasks(DateTime date) {
    final dayTasks = _tasks.where((task) {
      final taskStartDate = DateTime(task.startTime.year, task.startTime.month, task.startTime.day);
      final taskEndDate = DateTime(task.endTime.year, task.endTime.month, task.endTime.day);
      final selectedDate = DateTime(date.year, date.month, date.day);
      
      // 检查任务是否在选定的日期范围内
      return taskStartDate.isAtSameMomentAs(selectedDate) || 
             taskEndDate.isAtSameMomentAs(selectedDate) ||
             (taskStartDate.isBefore(selectedDate) && taskEndDate.isAfter(selectedDate));
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${date.year}年${date.month}月${date.day}日 任务',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 任务列表
              Expanded(
                child: dayTasks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '该日期没有任务',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: dayTasks.length,
                        itemBuilder: (context, index) {
                          final task = dayTasks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: task.status == 'completed' 
                                      ? Colors.grey 
                                      : Color(int.parse(task.color.replaceFirst('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.status == 'completed' 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  color: task.status == 'completed' 
                                      ? Colors.grey 
                                      : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task.description ?? ''),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${task.startTime.hour.toString().padLeft(2, '0')}:${task.startTime.minute.toString().padLeft(2, '0')} - ${task.endTime.hour.toString().padLeft(2, '0')}:${task.endTime.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task.status != 'completed')
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _completeTask(task);
                                      },
                                      tooltip: '完成任务',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => TaskEditScreen(
                                            task: task,
                                            onSave: _saveTask,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: '编辑任务',
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                _showTaskDetails(task);
                              },
                            ),
                          );
                        },
                      ),
              ),
              
              // 添加任务按钮
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _onTaskAdd(date);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加任务'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTaskSelected(Task task) {
    _showTaskDetails(task);
  }

  void _onTaskAdd(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          initialDate: date,
          onSave: _saveTask,
        ),
      ),
    );
  }

  void _onLogAdd(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogEditScreen(
          user: widget.user,
          initialDate: date,
        ),
      ),
    );
  }

  Future<void> _saveTask(Task task) async {
    try {
      // 检查是否是新建任务（ID是时间戳格式且没有对应的数据库记录）
      final isNewTask = task.id.contains(DateTime.now().millisecondsSinceEpoch.toString()) || 
                       task.id.length < 10; // UUID通常更长
      
      if (isNewTask) {
        // 新任务 - 让后端生成ID
        final newTask = Task(
          id: '', // 让后端生成ID
          title: task.title,
          description: task.description,
          assigneeId: task.assigneeId,
          assigneeName: task.assigneeName,
          department: task.department,
          priority: task.priority,
          status: task.status,
          createdAt: task.createdAt,
          deadline: task.deadline,
          createdBy: task.createdBy,
          startTime: task.startTime,
          endTime: task.endTime,
          color: task.color,
          location: task.location,
          isAllDay: task.isAllDay,
        );
        await TaskService.createTask(newTask);
      } else {
        // 更新任务
        await TaskService.updateTask(task.id, task);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务保存成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const Text('描述:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.description),
              const SizedBox(height: 8),
            ],
            const Text('时间:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${_formatDateTime(task.startTime)} - ${_formatDateTime(task.endTime)}'),
            if (task.location != null) ...[
              const SizedBox(height: 8),
              const Text('地点:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.location!),
            ],
            const SizedBox(height: 8),
            const Text('分类:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_getPriorityText(task.priority)),
            const SizedBox(height: 8),
            const Text('状态:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_getStatusText(task.status)),
          ],
        ),
        actions: [
          if (task.status != 'completed') ...[
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _completeTask(task);
              },
              child: const Text('完成任务', style: TextStyle(color: Colors.green)),
            ),
          ],
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TaskEditScreen(
                    task: task,
                    onSave: _saveTask,
                  ),
                ),
              );
            },
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteTask(task);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTask(Task task) async {
    try {
      print('开始完成任务: ${task.id}');
      
      final completedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        assigneeId: task.assigneeId,
        assigneeName: task.assigneeName,
        department: task.department,
        priority: task.priority,
        status: 'completed',
        createdAt: task.createdAt,
        deadline: task.deadline,
        createdBy: task.createdBy,
        startTime: task.startTime,
        endTime: task.endTime,
        color: task.color,
        location: task.location,
        isAllDay: task.isAllDay,
      );
      
      print('准备更新任务: ${completedTask.toJson()}');
      await TaskService.updateTask(task.id, completedTask);
      
      // 更新本地任务列表，而不是重新加载
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = completedTask;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务已完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('完成任务错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('完成任务失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await TaskService.deleteTask(task.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'important_urgent':
        return '工作';
      case 'important_not_urgent':
        return '学习';
      case 'not_important_urgent':
        return '生活';
      case 'not_important_not_urgent':
        return '其他';
      default:
        return '学习';
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务视图'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TaskEditScreen(
                    onSave: _saveTask,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: () => TestDataGenerator.showGenerateDialog(context),
            icon: const Icon(Icons.data_usage),
            tooltip: '生成测试数据',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ApiTestScreen(),
                ),
              );
            },
            icon: const Icon(Icons.network_check),
            tooltip: 'API测试',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return CalendarWidget(
      tasks: _tasks, // 保留兼容性，但月视图不再使用这个数据
      currentDate: _currentDate,
      onDateSelected: _onDateSelected,
      onTaskSelected: _onTaskSelected,
      onTaskAdd: _onTaskAdd,
      onLogAdd: _onLogAdd,
    );
  }
}
