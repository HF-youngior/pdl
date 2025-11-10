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
  Set<String> _previousReceivedTaskIds = {}; // 用于跟踪之前的接收任务ID
  Set<String> _previousAssignedTaskIds = {}; // 用于跟踪之前的分配任务ID
  Map<String, String?> _previousRequestResponses = {}; // 用于跟踪之前的邀约回复状态
  DateTime? _lastLoadTime; // 上次加载时间

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
      
      // 排序函数：未处理的邀约始终在最上方，已处理的邀约按正常排序
      int compareTasks(Task a, Task b) {
        // 判断是否为未处理的邀约（isRequest为true且requestResponse为null）
        final bool aIsUnhandledRequest = a.isRequest && (a.requestResponse == null || a.requestResponse?.isEmpty == true);
        final bool bIsUnhandledRequest = b.isRequest && (b.requestResponse == null || b.requestResponse?.isEmpty == true);
        
        // 未处理的邀约始终在最上方
        if (aIsUnhandledRequest && !bIsUnhandledRequest) return -1;
        if (!aIsUnhandledRequest && bIsUnhandledRequest) return 1;
        
        // 如果都是未处理的邀约，按ddl排序
        if (aIsUnhandledRequest && bIsUnhandledRequest) {
          if (a.deadline != null && b.deadline != null) {
            return a.deadline!.compareTo(b.deadline!);
          }
          if (a.deadline != null) return -1;
          if (b.deadline != null) return 1;
          // 如果都没有ddl，按创建时间倒序（新的在上）
          return b.createdAt.compareTo(a.createdAt);
        }
        
        // 已处理的邀约和普通任务按优先级排序（p0 > p1 > p2 > p3）
        final priorityOrder = {'p0': 0, 'p1': 1, 'p2': 2, 'p3': 3};
        final aPriority = priorityOrder[a.priority] ?? 4;
        final bPriority = priorityOrder[b.priority] ?? 4;
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        
        // 相同优先级按创建时间倒序（新创建的任务在上）
        return b.createdAt.compareTo(a.createdAt);
      }
      
      // 根据用户角色和任务关系分类任务，并排序
      final receivedTasks = tasks.where((task) => 
        task.assigneeId == widget.user.id || 
        task.assigneeName == widget.user.name
      ).toList()..sort(compareTasks);
      
      final assignedTasks = tasks.where((task) => 
        task.createdBy == widget.user.id || 
        task.createdBy == widget.user.username
      ).toList()..sort(compareTasks);
      
      final now = DateTime.now();
      final currentReceivedTaskIds = receivedTasks.map((t) => t.id).toSet();
      final currentAssignedTaskIds = assignedTasks.map((t) => t.id).toSet();
      
      // 检测新邀约、新任务和邀约回复
      if (_lastLoadTime != null && _previousReceivedTaskIds.isNotEmpty) {
        final newReceivedTasks = receivedTasks.where((task) => 
          !_previousReceivedTaskIds.contains(task.id)
        ).toList();
        
        final newRequests = newReceivedTasks.where((task) => 
          task.isRequest && 
          (task.requestResponse == null || task.requestResponse?.isEmpty == true)
        ).toList();
        
        final newRegularTasks = newReceivedTasks.where((task) => !task.isRequest).toList();
        
        // 检测邀约回复（用户发送的邀约被处理了）
        final newRequestReplies = assignedTasks.where((task) {
          if (!task.isRequest || task.createdBy != widget.user.id) return false;
          if (task.requestResponse == null || task.requestResponse!.isEmpty) return false;
          
          // 检查之前的状态：如果之前没有回复，现在有回复，就是新回复
          final previousResponse = _previousRequestResponses[task.id];
          final wasUnhandled = previousResponse == null || previousResponse.isEmpty;
          final nowHandled = task.requestResponse != null && task.requestResponse!.isNotEmpty;
          
          return wasUnhandled && nowHandled;
        }).toList();
        
        // 显示弹窗提示（优先级：新邀约 > 邀约回复 > 新任务）
        if (mounted) {
          if (newRequests.isNotEmpty) {
            _showNotificationDialog(
              title: '新邀约',
              message: '您收到了 ${newRequests.length} 个新邀约',
              tasks: newRequests,
            );
          } else if (newRequestReplies.isNotEmpty) {
            _showNotificationDialog(
              title: '邀约回复',
              message: '您的 ${newRequestReplies.length} 个邀约已收到回复',
              tasks: newRequestReplies,
            );
          } else if (newRegularTasks.isNotEmpty) {
            _showNotificationDialog(
              title: '新任务',
              message: '您收到了 ${newRegularTasks.length} 个新任务',
              tasks: newRegularTasks,
            );
          }
        }
      }
      
      // 更新邀约回复状态记录
      final newRequestResponses = <String, String?>{};
      for (final task in assignedTasks) {
        if (task.isRequest && task.createdBy == widget.user.id) {
          newRequestResponses[task.id] = task.requestResponse;
        }
      }
      
      setState(() {
        _receivedTasks = receivedTasks;
        _assignedTasks = assignedTasks;
        _isLoading = false;
        _previousReceivedTaskIds = currentReceivedTaskIds;
        _previousAssignedTaskIds = currentAssignedTaskIds;
        _previousRequestResponses = newRequestResponses;
        _lastLoadTime = now;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // 显示通知弹窗
  void _showNotificationDialog({
    required String title,
    required String message,
    required List<Task> tasks,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              title.contains('邀约回复') 
                ? Icons.reply 
                : (title.contains('邀约') ? Icons.mail : Icons.task),
              color: title.contains('邀约回复') 
                ? Colors.purple 
                : (title.contains('邀约') ? Colors.orange : Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (tasks.length <= 3) ...[
              const Text('任务列表：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.arrow_right, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              )),
            ] else
              Text('共 ${tasks.length} 个任务', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
          // 向上邀约按钮（admin用户不显示）
          if (widget.user.role != 'admin')
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
                // 邀约标识
                if (task.isRequest && (task.requestResponse == null || task.requestResponse?.isEmpty == true))
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '邀约',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
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
              // 创建子任务按钮（仅当任务接收者可以派发任务时显示）
              if (isReceived && _canCreateTask && task.status != 'completed')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _createSubtask(task),
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('创建子任务'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
          ],
        ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // 增加8小时
    final adjustedDateTime = dateTime.add(const Duration(hours: 8));
    return '${adjustedDateTime.year}-${adjustedDateTime.month.toString().padLeft(2, '0')}-${adjustedDateTime.day.toString().padLeft(2, '0')}';
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
