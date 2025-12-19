import 'dart:io';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';
import '../utils/time_utils.dart';
import 'task_edit_screen.dart';
import 'request_screen.dart';

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
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    // 邀约任务不加载子任务
    if (!_currentTask!.isRequest) {
    _loadSubtasks();
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
        title: Text('${actionText}邀约请求'),
        content: Text('确定要${actionText}此邀约请求吗？'),
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
            content: Text('邀约请求已${actionText}！'),
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
            content: Text('${actionText}邀约请求失败: $e'),
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
                                color: Colors.blue.withOpacity(0.1),
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
                            // 处理结果
                            if (task.requestResponse != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: task.requestResponse == 'approve' 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  task.requestResponse == 'approve' ? '已批准' : '已反驳',
                                  style: TextStyle(
                                    color: task.requestResponse == 'approve' ? Colors.green : Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // 请求内容
                        if (task.description.isNotEmpty) ...[
                          Text(
                            '请求内容',
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

                        // 邀约信息列表
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: '发起人',
                          value: task.createdBy,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          icon: Icons.person,
                          label: '接收人',
                          value: task.assigneeName,
                        ),
                        const SizedBox(height: 8),
                        if (task.requestResponse != null) ...[
                          _buildInfoRow(
                            icon: Icons.check_circle,
                            label: '处理结果',
                            value: task.requestResponse == 'approve' ? '已批准' : '已反驳',
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (task.completedAt != null) ...[
                          _buildInfoRow(
                            icon: Icons.access_time,
                            label: '处理时间',
                            value: _formatDateTime(task.completedAt!),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _buildInfoRow(
                          icon: Icons.access_time,
                          label: '创建时间',
                          value: _formatDateTime(task.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                
              // 备注信息卡片（邀约任务且已处理时显示）
              if (task.isRequest && task.requestResponse != null)
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
                        Text(
                          '备注',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.specialNotes ?? '无',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 任务基本信息卡片（非邀约任务显示）
              if (!task.isRequest)
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

                      if (task.attachments.isNotEmpty) ...[
                        Text(
                          '图片/附件',
                          style: TextStyle(
                            fontSize: 16,
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildAttachmentThumbnail(path),
                                ),
                              );
                            },
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
                          value: _formatDateTime(task.startTime),
                        ),
                      if (task.startTime != null) const SizedBox(height: 8),
                      if (task.deadline != null)
                        _buildInfoRow(
                          icon: Icons.schedule,
                          label: '截止时间',
                          value: _formatDateTime(task.deadline!),
                        ),
                      if (task.deadline != null) const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: '创建时间',
                        value: _formatDateTime(task.createdAt),
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

              // 邀约处理（仅邀约任务且当前用户是被邀约人且未完成时显示）
              if (_currentTask!.isRequest && 
                  _currentTask!.assigneeId == widget.currentUser.id && 
                  _currentTask!.status != 'completed')
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
                        Text(
                          '处理邀约',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            hintText: '请输入备注信息...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
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
                            const SizedBox(width: 12),
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
                ),

              const SizedBox(height: 16),

              // 子任务列表（邀约任务不显示）
              if (!_currentTask!.isRequest)
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
                        Text(
                          '子任务',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
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

  Widget _buildAttachmentThumbnail(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 100,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenThumbnail(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 100,
        height: 90,
        fit: BoxFit.cover,
      );
    }
    return _brokenThumbnail();
  }

  Widget _brokenThumbnail() {
    return Container(
      width: 100,
      height: 90,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
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
      ),
    );
  }
}

