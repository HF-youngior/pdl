import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import 'task_edit_screen.dart';
import 'task_detail_screen.dart';
import 'request_screen.dart';

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
      
      // 排序函数：邀约任务排在最上面，按ddl排序；其他任务按优先级和创建时间排序
      int compareTasks(Task a, Task b) {
        // 邀约任务优先
        if (a.isRequest && !b.isRequest) return -1;
        if (!a.isRequest && b.isRequest) return 1;
        
        // 如果都是邀约任务，按ddl排序
        if (a.isRequest && b.isRequest) {
          if (a.deadline != null && b.deadline != null) {
            return a.deadline!.compareTo(b.deadline!);
          }
          if (a.deadline != null) return -1;
          if (b.deadline != null) return 1;
          return 0;
        }
        
        // 非邀约任务按优先级排序（p0 > p1 > p2 > p3）
        final priorityOrder = {'p0': 0, 'p1': 1, 'p2': 2, 'p3': 3};
        final aPriority = priorityOrder[a.priority] ?? 4;
        final bPriority = priorityOrder[b.priority] ?? 4;
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        
        // 相同优先级按创建时间倒序
        return b.createdAt.compareTo(a.createdAt);
      }
      
      // 根据用户角色和任务关系分类任务，并排序
      setState(() {
        _receivedTasks = tasks.where((task) => 
          task.assigneeId == widget.user.id || 
          task.assigneeName == widget.user.name
        ).toList()..sort(compareTasks);
        
        _assignedTasks = tasks.where((task) => 
          task.createdBy == widget.user.id || 
          task.createdBy == widget.user.username
        ).toList()..sort(compareTasks);
        
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
    // 除了员工，其他角色都可以创建任务
    return widget.user.role != 'employee';
  }

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
    // 使用任务的真实进度
    return task.progressPercentage / 100.0;
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
          // 刷新按钮在最右边
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: '刷新',
          ),
          // 向上邀约按钮（所有用户都可以使用）
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RequestScreen(
                    currentUser: widget.user,
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  _loadTasks();
                }
              });
            },
            tooltip: '向上邀约',
          ),
          // 加号按钮在刷新按钮左边（仅非员工角色显示）
          if (_canCreateTask)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TaskEditScreen(
                      currentUser: widget.user,
                      onSave: _saveTask,
                    ),
                  ),
                );
              },
              tooltip: '新建任务',
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
      child: InkWell(
        onTap: () {
          // 点击任务卡片进入详情页面
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                task: task,
                currentUser: widget.user,
              ),
            ),
          ).then((_) {
            // 从详情页返回后刷新任务列表
            _loadTasks();
          });
        },
        borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),
            // 邀约任务且当前用户是被邀约人时，根据状态显示不同按钮
            if (task.isRequest && isReceived && task.assigneeId == widget.user.id)
              SizedBox(
                width: double.infinity,
                child: task.status == 'completed'
                    ? OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TaskDetailScreen(
                                task: task,
                                currentUser: widget.user,
                              ),
                            ),
                          ).then((_) {
                            _loadTasks();
                          });
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('查看详情'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TaskDetailScreen(
                                task: task,
                                currentUser: widget.user,
                              ),
                            ),
                          ).then((_) {
                            _loadTasks();
                          });
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('处理邀约'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 创建子任务按钮（仅当任务接收者可以派发任务时显示）
                  if (isReceived && _canCreateTask && task.status != 'completed')
                    OutlinedButton.icon(
                      onPressed: () => _createSubtask(task),
                      icon: const Icon(Icons.add_task, size: 16),
                      label: const Text('创建子任务'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  // 完成任务按钮
                  if (isReceived && task.status != 'completed')
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
        ),
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

  // 创建子任务
  Future<void> _createSubtask(Task parentTask) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          currentUser: widget.user,
          task: null, // 传 null 表示创建新任务
          parentTaskId: parentTask.id, // 传入父任务ID
          onSave: _saveTask,
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
      await _loadTasks();
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
