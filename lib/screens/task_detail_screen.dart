import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';
import '../utils/time_utils.dart';
import 'task_edit_screen.dart';
import 'request_screen.dart';
import 'dart:math' as math;

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final User currentUser;
  final bool showTaskTree;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.currentUser,
    this.showTaskTree = true,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _currentTask;
  List<Task> _subtasks = [];
  bool _isLoadingSubtasks = false;
  final TextEditingController _notesController = TextEditingController();
  Map<String, dynamic>? _taskTree;
  bool _isLoadingTaskTree = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    // 邀约任务不加载子任务
    if (!_currentTask!.isRequest) {
      _loadSubtasks();
      if (widget.showTaskTree) {
        _loadTaskTree();
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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

  // 加载任务树
  Future<void> _loadTaskTree() async {
    if (_currentTask == null) return;
    
    setState(() {
      _isLoadingTaskTree = true;
    });

    try {
      final tree = await ApiService.getTaskTree(_currentTask!.id);
      setState(() {
        _taskTree = tree;
        _isLoadingTaskTree = false;
      });
    } catch (e) {
      print('加载任务树失败: $e');
      setState(() {
        _isLoadingTaskTree = false;
      });
    }
  }

  // 处理邀约请求（批准/反驳）
  Future<void> _handleRequestResponse(String action) async {
    if (!_currentTask!.isRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此任务不是邀约任务'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentTask!.assigneeId != widget.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('只有被邀约人可以处理此邀约请求'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentTask!.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此邀约请求已被处理'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final actionText = action == 'approve' ? '批准' : '反驳';
    final notes = _notesController.text.trim();

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionText邀约请求'),
        content: Text('确定要$actionText此邀约请求吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final success = await ApiService.handleRequestResponse(
        taskId: _currentTask!.id,
        action: action,
        notes: notes.isEmpty ? null : notes,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('邀约请求已$actionText！'),
            backgroundColor: Colors.green,
          ),
        );

        // 刷新任务信息以获取最新的备注信息
        try {
          final updatedTask = await TaskService.getTaskById(_currentTask!.id);
          setState(() {
            _currentTask = updatedTask;
          });
        } catch (e) {
          print('刷新任务信息失败: $e');
          // 如果刷新失败，至少更新本地状态
          setState(() {
            _currentTask = Task(
              id: _currentTask!.id,
              title: _currentTask!.title,
              description: _currentTask!.description,
              assigneeId: _currentTask!.assigneeId,
              assigneeName: _currentTask!.assigneeName,
              department: _currentTask!.department,
              priority: _currentTask!.priority,
              status: 'completed',
              createdAt: _currentTask!.createdAt,
              deadline: _currentTask!.deadline,
              createdBy: _currentTask!.createdBy,
              startTime: _currentTask!.startTime,
              endTime: _currentTask!.endTime,
              color: _currentTask!.color,
              location: _currentTask!.location,
              isAllDay: _currentTask!.isAllDay,
              progressPercentage: 100,
              parentTaskId: _currentTask!.parentTaskId,
              subtasks: _currentTask!.subtasks,
              isRequest: _currentTask!.isRequest,
              requestType: _currentTask!.requestType,
              requestResponse: action, // 保存处理结果
              specialNotes: notes.isEmpty ? null : notes, // 保存备注
              completedAt: DateTime.now(),
            );
          });
        }

        // 清空备注输入框
        _notesController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionText邀约请求失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 编辑任务
  Future<void> _editTask() async {
    // 如果是邀约任务，使用RequestScreen编辑
    if (_currentTask!.isRequest) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RequestScreen(
            currentUser: widget.currentUser,
            task: _currentTask,
          ),
        ),
      );

      if (result == true && mounted) {
        // 刷新任务信息
        try {
          final updatedTask = await TaskService.getTaskById(_currentTask!.id);
          setState(() {
            _currentTask = updatedTask;
          });
        } catch (e) {
          print('刷新任务信息失败: $e');
        }
      }
    } else {
      // 普通任务，使用TaskEditScreen编辑
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
        return '重要且紧急';
      case 'p1':
        return '重要不紧急';
      case 'p2':
        return '不重要紧急';
      case 'p3':
        return '不重要不紧急';
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
        return Colors.green;
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
        return '已完成';
      default:
        return status;
    }
  }
  
  // 格式化日期时间，带本地时区标签，便于与管理端对照
  String _formatDateTime(DateTime dateTime, {bool includeSeconds = false}) {
    return TimeUtils.formatDateTimeWithZone(
      dateTime,
      includeSeconds: includeSeconds,
    );
  }

  // 构建任务树可视化
  Widget _buildTaskTreeVisualization() {
    if (_currentTask == null || _currentTask!.isRequest) {
      return const SizedBox.shrink(); // 邀约任务不显示任务树
    }

    return Card(
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
              children: [
                const Icon(
                  Icons.account_tree,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '任务关系树',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (_isLoadingTaskTree)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTaskTree,
                    tooltip: '刷新任务树',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingTaskTree)
              const Center(child: CircularProgressIndicator())
            else if (_taskTree == null)
              const Center(
                child: Text(
                  '无法加载任务关系树',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              _buildTaskTreeWidget(_taskTree!),
          ],
        ),
      ),
    );
  }

  // 构建任务树组件
  Widget _buildTaskTreeWidget(Map<String, dynamic> treeData) {
    // 如果任务树为空，显示提示信息
    if (treeData.isEmpty) {
      return const Center(
        child: Text(
          '此任务没有父任务或子任务',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 获取树的高度（用于计算画布大小）
    final treeHeight = _calculateTreeHeight(treeData);
    final treeWidth = _calculateTreeWidth(treeData);

    return SizedBox(
      height: math.max(300.0, treeHeight * 80.0),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(MediaQuery.of(context).size.width - 32, treeWidth * 150.0),
          child: CustomPaint(
            painter: TaskTreePainter(treeData: treeData),
            child: _buildTaskNodes(treeData),
          ),
        ),
      ),
    );
  }

  // 构建任务节点
  Widget _buildTaskNodes(Map<String, dynamic> treeData) {
    return _buildTaskNodeWidget(treeData, 0, 0);
  }

  Widget _buildTaskNodeWidget(Map<String, dynamic> nodeData, int level, int position) {
    final isCurrentTask = nodeData['id'] == _currentTask!.id;
    final nodeWidth = 140.0;
    final nodeHeight = 60.0;
    final horizontalSpacing = 160.0;
    final verticalSpacing = 80.0;

    // 计算节点位置
    final left = position * horizontalSpacing;
    final top = level * verticalSpacing;

    // 构建子节点
    final children = <Widget>[];
    if (nodeData['subtasks'] != null && (nodeData['subtasks'] as List).isNotEmpty) {
      final subtasks = nodeData['subtasks'] as List;
      for (int i = 0; i < subtasks.length; i++) {
        children.add(_buildTaskNodeWidget(
          subtasks[i] as Map<String, dynamic>,
          level + 1,
          position + i,
        ));
      }
    }

    return Stack(
      children: [
        // 节点卡片
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: nodeWidth,
            height: nodeHeight,
            decoration: BoxDecoration(
              color: isCurrentTask ? Colors.blue.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentTask ? Colors.blue : Colors.grey.shade300,
                width: isCurrentTask ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nodeData['title'] ?? '无标题',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTask ? Colors.blue.shade800 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nodeData['assignee_name'] ?? '未分配',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        // 子节点
        ...children,
      ],
    );
  }

  // 计算树的高度
  int _calculateTreeHeight(Map<String, dynamic> node) {
    if (node['subtasks'] == null || (node['subtasks'] as List).isEmpty) {
      return 1;
    }

    int maxHeight = 0;
    for (final subtask in node['subtasks'] as List) {
      final height = _calculateTreeHeight(subtask as Map<String, dynamic>);
      if (height > maxHeight) {
        maxHeight = height;
      }
    }

    return maxHeight + 1;
  }

  // 计算树的宽度
  int _calculateTreeWidth(Map<String, dynamic> node) {
    if (node['subtasks'] == null || (node['subtasks'] as List).isEmpty) {
      return 1;
    }

    int totalWidth = 0;
    for (final subtask in node['subtasks'] as List) {
      totalWidth += _calculateTreeWidth(subtask as Map<String, dynamic>);
    }

    return math.max(1, totalWidth);
  }

  // 构建邀约信息
  Widget _buildRequestInfo(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 创建者和被邀约人信息
        Row(
          children: [
            Icon(
              Icons.person,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '创建者: ${task.createdBy}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.person_outline,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '被邀约人: ${task.assigneeName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (task.deadline != null)
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '截止时间: ${_formatDateTime(task.deadline!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 构建邀约处理结果
  Widget _buildRequestResult(Task task) {
    final isApproved = task.requestResponse == 'approve';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isApproved ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isApproved ? '已批准' : '已反驳',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isApproved ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (task.specialNotes != null && task.specialNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '备注: ${task.specialNotes}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
          if (task.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '处理时间: ${_formatDateTime(task.completedAt!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建任务属性
  Widget _buildTaskProperties(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 负责人
        Row(
          children: [
            Icon(
              Icons.person,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '负责人: ${task.assigneeName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 部门
        Row(
          children: [
            Icon(
              Icons.business,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '部门: ${task.department}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 创建时间
        Row(
          children: [
            Icon(
              Icons.access_time,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '创建时间: ${_formatDateTime(task.createdAt)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        if (task.deadline != null) ...[
          const SizedBox(height: 8),
          // 截止时间
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '截止时间: ${_formatDateTime(task.deadline!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
        if (task.location != null && task.location!.isNotEmpty) ...[
          const SizedBox(height: 8),
          // 地点
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '地点: ${task.location}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 构建子任务列表
  Widget _buildSubtasksList() {
    return Card(
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
              children: [
                const Icon(
                  Icons.list_alt,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '子任务列表',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (_isLoadingSubtasks)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadSubtasks,
                    tooltip: '刷新子任务',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingSubtasks)
              const Center(child: CircularProgressIndicator())
            else if (_subtasks.isEmpty)
              const Center(
                child: Text(
                  '暂无子任务',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subtasks.length,
                itemBuilder: (context, index) {
                  final subtask = _subtasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        subtask.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  _formatDateTime(subtask.deadline!),
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
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(subtask.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TaskDetailScreen(
                              task: subtask,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 构建邀约处理部分
  Widget _buildRequestAction(Task task) {
    // 只有被邀约人且未处理的邀约任务才显示处理部分
    if (task.assigneeId != widget.currentUser.id || 
        task.requestResponse != null || 
        task.status == 'completed') {
      return const SizedBox.shrink();
    }

    return Card(
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
              children: [
                Icon(
                  Icons.how_to_vote,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '处理邀约',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '请选择是否批准此邀约请求：',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            // 备注输入框
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
                hintText: '请输入处理此邀约的备注信息...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRequestResponse('approve'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('批准'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRequestResponse('reject'),
                    icon: const Icon(Icons.cancel),
                    label: const Text('反驳'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          // 邀约任务：只有创建者可以编辑，被邀约人不能编辑
          // 普通任务：根据权限显示编辑按钮
          if (_currentTask!.isRequest) ...[
            // 邀约任务：只有创建者可以编辑，且未审批时才能编辑
            if ((_currentTask!.createdBy == widget.currentUser.id || 
                _currentTask!.createdBy == widget.currentUser.username) &&
                _currentTask!.requestResponse == null &&
                _currentTask!.status != 'completed')
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editTask,
                tooltip: '编辑邀约内容',
              ),
          ] else ...[
            // 普通任务：邀约任务且当前用户是被邀约人时，不显示编辑按钮
            if (!(_currentTask!.isRequest && _currentTask!.assigneeId == widget.currentUser.id))
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editTask,
                tooltip: '编辑任务',
              ),
          ],
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
            // 刷新任务树
            if (!_currentTask!.isRequest) {
              await _loadTaskTree();
            }
          } catch (e) {
            print('刷新任务信息失败: $e');
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 邀约任务信息（邀约任务专用）
              if (task.isRequest)
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
                        // 请求类型和状态
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                task.requestType ?? '未知',
                                style: const TextStyle(
                                  color: Colors.blue,
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
                                color: _getStatusColor(task.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(task.status),
                                  width: 1.5,
                                ),
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
                        
                        // 邀约信息
                        _buildRequestInfo(task),
                        
                        // 处理结果（如果已处理）
                        if (task.requestResponse != null) ...[
                          const SizedBox(height: 16),
                          _buildRequestResult(task),
                        ],
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // 任务基本信息
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
                      // 任务标题和优先级
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 20,
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
                              color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(height: 12),
                      
                      // 任务描述
                      if (task.description.isNotEmpty) ...[
                        Text(
                          task.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // 任务进度条
                      if (!task.isRequest) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '任务进度',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${task.progressPercentage.toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // 任务属性
                      _buildTaskProperties(task),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 任务树可视化（非邀约任务且showTaskTree为true）
              if (!task.isRequest && widget.showTaskTree)
                _buildTaskTreeVisualization(),
              
              const SizedBox(height: 16),
              
              // 子任务列表（非邀约任务）
              if (!task.isRequest)
                _buildSubtasksList(),
              
              // 邀约处理部分（邀约任务专用）
              if (task.isRequest)
                _buildRequestAction(task),
            ],
          ),
        ),
      ),
    );
  }
}

// 任务树画笔类，用于绘制节点之间的连线
class TaskTreePainter extends CustomPainter {
  final Map<String, dynamic> treeData;
  final double nodeWidth = 140.0;
  final double nodeHeight = 60.0;
  final double horizontalSpacing = 160.0;
  final double verticalSpacing = 80.0;

  TaskTreePainter({required this.treeData});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    _drawNodeConnections(canvas, paint, treeData, 0, 0);
  }

  void _drawNodeConnections(Canvas canvas, Paint paint, Map<String, dynamic> node, int level, int position) {
    if (node['subtasks'] == null || (node['subtasks'] as List).isEmpty) {
      return;
    }

    final parentCenterX = position * horizontalSpacing + nodeWidth / 2;
    final parentBottomY = level * verticalSpacing + nodeHeight;

    final subtasks = node['subtasks'] as List;
    for (int i = 0; i < subtasks.length; i++) {
      final subtask = subtasks[i] as Map<String, dynamic>;
      final childCenterX = (position + i) * horizontalSpacing + nodeWidth / 2;
      final childTopY = (level + 1) * verticalSpacing;

      // 绘制从父节点底部到子节点顶部的连线
      final path = Path();
      path.moveTo(parentCenterX, parentBottomY);
      
      // 使用贝塞尔曲线使连线更平滑
      final controlPoint1X = parentCenterX;
      final controlPoint1Y = parentBottomY + (childTopY - parentBottomY) / 2;
      final controlPoint2X = childCenterX;
      final controlPoint2Y = parentBottomY + (childTopY - parentBottomY) / 2;
      
      path.cubicTo(
        controlPoint1X, controlPoint1Y,
        controlPoint2X, controlPoint2Y,
        childCenterX, childTopY,
      );
      
      canvas.drawPath(path, paint);

      // 递归绘制子节点的连线
      _drawNodeConnections(canvas, paint, subtask, level + 1, position + i);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}