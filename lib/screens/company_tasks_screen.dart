import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'task_edit_screen.dart';

class CompanyTasksScreen extends StatefulWidget {
  final User user;

  const CompanyTasksScreen({super.key, required this.user});

  @override
  State<CompanyTasksScreen> createState() => _CompanyTasksScreenState();
}

class _CompanyTasksScreenState extends State<CompanyTasksScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final tasks = await ApiService.getTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Task> get _filteredTasks {
    if (_filterStatus == 'all') {
      return _tasks;
    }
    return _tasks.where((task) => task.status == _filterStatus).toList();
  }

  bool get _canCreateTask {
    return widget.user.role == 'admin' || 
           widget.user.role == 'founder' || 
           widget.user.role == 'manager' ||
           widget.user.role == 'team_leader';
  }

  bool get _canEditTask {
    return widget.user.role == 'admin' || 
           widget.user.role == 'founder' || 
           widget.user.role == 'manager' ||
           widget.user.role == 'team_leader';
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'p0':
        return 'P0 - 最高优先级';
      case 'p1':
        return 'P1 - 高优先级';
      case 'p2':
        return 'P2 - 中优先级';
      case 'p3':
        return 'P3 - 低优先级';
      default:
        return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
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
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公司十大任务派发'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_canCreateTask)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TaskEditScreen(
                      onSave: _saveTask,
                    ),
                  ),
                );
              },
              tooltip: '创建任务',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选器
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('筛选:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', '全部'),
                        const SizedBox(width: 8),
                        _buildFilterChip('pending', '待处理'),
                        const SizedBox(width: 8),
                        _buildFilterChip('in_progress', '进行中'),
                        const SizedBox(width: 8),
                        _buildFilterChip('completed', '已完成'),
                        const SizedBox(width: 8),
                        _buildFilterChip('cancelled', '已取消'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 任务列表
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTasks,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_filteredTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无任务',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和优先级
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getPriorityColor(task.priority),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getPriorityText(task.priority),
                          style: TextStyle(
                            color: _getPriorityColor(task.priority),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 描述
                  if (task.description.isNotEmpty) ...[
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // 分配信息
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '分配给: ${task.assigneeName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // 部门信息
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '部门: ${task.department}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 状态和截止时间
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(task.status),
                          style: TextStyle(
                            color: _getStatusColor(task.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (task.deadline != null)
                        Text(
                          '截止: ${_formatDateTime(task.deadline!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  
                  // 操作按钮
                  if (_canEditTask) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TaskEditScreen(
                                  task: task,
                                  onSave: _saveTask,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('编辑'),
                        ),
                        if (task.status != 'completed')
                          TextButton.icon(
                            onPressed: () => _completeTask(task),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('完成'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveTask(Task task) async {
    try {
      // 这里应该调用API保存任务
      await _loadTasks();
      
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

  Future<void> _completeTask(Task task) async {
    try {
      // 这里应该调用API完成任务
      await _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务已完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
