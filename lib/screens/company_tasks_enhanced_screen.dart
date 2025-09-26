import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'task_edit_screen.dart';

class CompanyTasksEnhancedScreen extends StatefulWidget {
  final User user;

  const CompanyTasksEnhancedScreen({super.key, required this.user});

  @override
  State<CompanyTasksEnhancedScreen> createState() => _CompanyTasksEnhancedScreenState();
}

class _CompanyTasksEnhancedScreenState extends State<CompanyTasksEnhancedScreen> with TickerProviderStateMixin {
  List<Task> _receivedTasks = [];
  List<Task> _assignedTasks = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final tasks = await ApiService.getTasks();
      
      // 根据用户角色和任务关系分类任务
      setState(() {
        _receivedTasks = tasks.where((task) => 
          task.assigneeId == widget.user.id || 
          task.assigneeName == widget.user.name
        ).toList();
        
        _assignedTasks = tasks.where((task) => 
          task.createdBy == widget.user.id || 
          task.createdBy == widget.user.username
        ).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool get _canCreateTask {
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

  double _calculateProgress(Task task) {
    // 这里应该根据子任务完成情况计算进度
    // 暂时返回随机进度作为示例
    return 0.6;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公司任务派发'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '接收到的任务', icon: Icon(Icons.inbox)),
            Tab(text: '分配出去的任务', icon: Icon(Icons.send)),
          ],
        ),
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
      body: _buildBody(),
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

    return TabBarView(
      controller: _tabController,
      children: [
        _buildReceivedTasks(),
        _buildAssignedTasks(),
      ],
    );
  }

  Widget _buildReceivedTasks() {
    if (_receivedTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无接收到的任务',
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
        itemCount: _receivedTasks.length,
        itemBuilder: (context, index) {
          final task = _receivedTasks[index];
          return _buildTaskCard(task, isReceived: true);
        },
      ),
    );
  }

  Widget _buildAssignedTasks() {
    if (_assignedTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无分配出去的任务',
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
        itemCount: _assignedTasks.length,
        itemBuilder: (context, index) {
          final task = _assignedTasks[index];
          return _buildTaskCard(task, isReceived: false);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task, {required bool isReceived}) {
    final progress = _calculateProgress(task);
    
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
            
            // 任务信息
            Row(
              children: [
                Icon(
                  isReceived ? Icons.person : Icons.send,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  isReceived ? '分配给: ${task.assigneeName}' : '创建者: ${task.createdBy}',
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
            
            // 进度条
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '完成进度',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : Colors.blue,
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
            if (isReceived && task.status != 'completed') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _completeTask(task),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('完成任务'),
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
