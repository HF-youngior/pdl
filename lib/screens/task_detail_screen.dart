import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final User currentUser;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.currentUser,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _currentTask;
  List<Task> _subtasks = [];
  bool _isLoadingSubtasks = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _loadSubtasks();
  }

  // 加载子任务
  Future<void> _loadSubtasks() async {
    setState(() {
      _isLoadingSubtasks = true;
    });

    try {
      // 使用 TaskService 获取所有任务，然后筛选出子任务
      final allTasks = await TaskService.getTasks();
      setState(() {
        _subtasks = allTasks.where((t) => 
          t.parentTaskId != null && t.parentTaskId == _currentTask!.id
        ).toList();
        _isLoadingSubtasks = false;
      });
    } catch (e) {
      print('加载子任务失败: $e');
      setState(() {
        _isLoadingSubtasks = false;
      });
    }
  }

  // 检查是否可以创建子任务
  bool get _canCreateSubtask {
    // 只有任务接收者且不是普通员工才能创建子任务
    final isAssignee = _currentTask!.assigneeId == widget.currentUser.id;
    final canCreateTask = widget.currentUser.role != 'employee';
    final isNotCompleted = _currentTask!.status != 'completed';
    return isAssignee && canCreateTask && isNotCompleted;
  }

  // 创建子任务
  Future<void> _createSubtask() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          currentUser: widget.currentUser,
          task: null,
          parentTaskId: _currentTask!.id,
          onSave: (task) {
            // 子任务创建成功后刷新列表
            _loadSubtasks();
          },
        ),
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('子任务创建成功'),
          backgroundColor: Colors.green,
        ),
      );
      _loadSubtasks();
    }
  }

  // 编辑任务
  Future<void> _editTask() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: _currentTask,
          currentUser: widget.currentUser,
          onSave: (task) {
            setState(() {
              _currentTask = task;
            });
            _loadSubtasks();
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentTask = result;
      });
      _loadSubtasks();
    }
  }

  // 获取优先级颜色
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'p0':
        return Colors.red;
      case 'p1':
        return Colors.amber.shade700;
      case 'p2':
        return Colors.blue.shade700;
      case 'p3':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  // 获取优先级文本
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

  // 获取状态颜色
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
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTask == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final task = _currentTask!;
    // 使用任务本身的进度（后端已经根据子任务自动更新）
    final progress = task.progressPercentage / 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          task.title,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // 右上角加号按钮（创建子任务）
          if (_canCreateSubtask)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createSubtask,
              tooltip: '创建子任务',
            ),
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTask,
            tooltip: '编辑任务',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 刷新任务信息（进度可能已更新）
          try {
            // 重新加载任务列表以获取最新进度
            final allTasks = await TaskService.getTasks();
            final updatedTask = allTasks.firstWhere(
              (t) => t.id == _currentTask!.id,
              orElse: () => _currentTask!,
            );
            setState(() {
              _currentTask = updatedTask;
            });
            // 刷新子任务列表
            await _loadSubtasks();
          } catch (e) {
            print('刷新任务信息失败: $e');
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 任务基本信息卡片
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 优先级和状态
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getPriorityColor(task.priority),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _getPriorityText(task.priority),
                              style: TextStyle(
                                color: _getPriorityColor(task.priority),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(task.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(task.status),
                              style: TextStyle(
                                color: _getStatusColor(task.status),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 任务描述
                      if (task.description.isNotEmpty) ...[
                        Text(
                          '任务描述',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 进度条
                      Text(
                        '完成进度',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress == 1.0 ? Colors.green : Colors.blue,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${task.progressPercentage}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 任务信息列表
                      _buildInfoRow(
                        icon: Icons.person,
                        label: '负责人',
                        value: task.assigneeName,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.business,
                        label: '部门',
                        value: task.department,
                      ),
                      const SizedBox(height: 8),
                      if (task.startTime != null)
                        _buildInfoRow(
                          icon: Icons.play_arrow,
                          label: '开始时间',
                          value: DateFormat('yyyy-MM-dd HH:mm').format(task.startTime),
                        ),
                      if (task.startTime != null) const SizedBox(height: 8),
                      if (task.deadline != null)
                        _buildInfoRow(
                          icon: Icons.schedule,
                          label: '截止时间',
                          value: DateFormat('yyyy-MM-dd HH:mm').format(task.deadline!),
                        ),
                      if (task.deadline != null) const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: '创建时间',
                        value: DateFormat('yyyy-MM-dd HH:mm').format(task.createdAt),
                      ),
                      if (task.location != null && task.location!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          icon: Icons.location_on,
                          label: '地点',
                          value: task.location!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 子任务列表
              if (_canCreateSubtask || _subtasks.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '子任务',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (_canCreateSubtask)
                              TextButton.icon(
                                onPressed: _createSubtask,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('创建子任务'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingSubtasks)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_subtasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                '暂无子任务',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._subtasks.map((subtask) => _buildSubtaskItem(subtask)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskItem(Task subtask) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(
              task: subtask,
              currentUser: widget.currentUser,
            ),
          ),
        ).then((_) {
          // 从子任务详情返回后刷新
          _loadSubtasks();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtask.title,
                    style: const TextStyle(
                      fontSize: 16,
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
                    color: _getStatusColor(subtask.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(subtask.status),
                    style: TextStyle(
                      color: _getStatusColor(subtask.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (subtask.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtask.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  subtask.assigneeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                if (subtask.deadline != null) ...[
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MM-dd HH:mm').format(subtask.deadline!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

