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
  Set<String> _previousTaskIds = {}; // 用于跟踪之前的任务ID，检测新任务
  Map<String, String?> _previousRequestResponses = {}; // 用于跟踪之前的邀约回复状态
  DateTime? _lastLoadTime; // 上次加载时间，用于检测新任务

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
      
      final currentTaskIds = tasks.map((t) => t.id).toSet();
      final now = DateTime.now();
      
      // 检测新邀约、新任务和邀约回复
      if (_lastLoadTime != null && _previousTaskIds.isNotEmpty) {
        final newTasks = tasks.where((task) => !_previousTaskIds.contains(task.id)).toList();
        final newRequests = newTasks.where((task) => 
          task.isRequest && 
          (task.requestResponse == null || task.requestResponse?.isEmpty == true) &&
          task.assigneeId == widget.user.id
        ).toList();
        final newRegularTasks = newTasks.where((task) => 
          !task.isRequest && 
          task.assigneeId == widget.user.id
        ).toList();
        
        // 检测邀约回复（用户发送的邀约被处理了）
        final newRequestReplies = tasks.where((task) {
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
      for (final task in tasks) {
        if (task.isRequest && task.createdBy == widget.user.id) {
          newRequestResponses[task.id] = task.requestResponse;
        }
      }
      
      setState(() {
        _tasks = tasks..sort(compareTasks);
        _isLoading = false;
        _previousTaskIds = currentTaskIds;
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

  List<Task> get _filteredTasks {
    List<Task> filtered;
    if (_filterStatus == 'all') {
      filtered = _tasks;
    } else {
      filtered = _tasks.where((task) => task.status == _filterStatus).toList();
    }
    
    // 确保排序：未处理的邀约始终在最上方，已处理的邀约按正常排序
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
    
    return filtered..sort(compareTasks);
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
                      currentUser: widget.user,
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
                                  currentUser: widget.user,
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
    // 增加8小时
    final adjustedDateTime = dateTime.toLocal();
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
