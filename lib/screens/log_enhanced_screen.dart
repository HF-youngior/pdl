import 'package:flutter/material.dart';
import '../models/log.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class LogEnhancedScreen extends StatefulWidget {
  final User user;

  const LogEnhancedScreen({super.key, required this.user});

  @override
  State<LogEnhancedScreen> createState() => _LogEnhancedScreenState();
}

class _LogEnhancedScreenState extends State<LogEnhancedScreen> {
  List<Log> _logs = [];
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        ApiService.getLogs(),
        ApiService.getTasks(),
      ]);

      setState(() {
        _logs = futures[0] as List<Log>;
        _tasks = futures[1] as List<Task>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Log> get _filteredLogs {
    if (_filterCategory == 'all') {
      return _logs;
    }
    return _logs.where((log) => log.category.toLowerCase() == _filterCategory).toList();
  }

  String _getCategoryText(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return '工作';
      case 'learning':
        return '学习';
      case 'personal':
        return '个人';
      case 'meeting':
        return '会议';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'learning':
        return Colors.green;
      case 'personal':
        return Colors.orange;
      case 'meeting':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work;
      case 'learning':
        return Icons.school;
      case 'personal':
        return Icons.person;
      case 'meeting':
        return Icons.meeting_room;
      default:
        return Icons.description;
    }
  }

  String _getQuadrantText(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return '重要且紧急';
      case 'important_not_urgent':
        return '重要不紧急';
      case 'not_important_urgent':
        return '紧急不重要';
      case 'not_important_not_urgent':
        return '不重要不紧急';
      default:
        return quadrant;
    }
  }

  Color _getQuadrantColor(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return Colors.red;
      case 'important_not_urgent':
        return Colors.orange;
      case 'not_important_urgent':
        return Colors.blue;
      case 'not_important_not_urgent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人日志'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddLogDialog();
            },
            tooltip: '添加日志',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                        _buildFilterChip('work', '工作'),
                        const SizedBox(width: 8),
                        _buildFilterChip('learning', '学习'),
                        const SizedBox(width: 8),
                        _buildFilterChip('personal', '个人'),
                        const SizedBox(width: 8),
                        _buildFilterChip('meeting', '会议'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 日志列表
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterCategory = value;
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
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_filteredLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无日志',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '点击右上角 + 号添加日志',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) {
          final log = _filteredLogs[index];
          return _buildLogCard(log);
        },
      ),
    );
  }

  Widget _buildLogCard(Log log) {
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
            // 标题和分类
            Row(
              children: [
                Icon(
                  _getCategoryIcon(log.category),
                  color: _getCategoryColor(log.category),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.action,
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
                    color: _getCategoryColor(log.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategoryText(log.category),
                    style: TextStyle(
                      color: _getCategoryColor(log.category),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 描述
            Text(
              log.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            
            // 象限和用户信息
            Row(
              children: [
                if (log.quadrant.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getQuadrantColor(log.quadrant).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getQuadrantColor(log.quadrant),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getQuadrantText(log.quadrant),
                      style: TextStyle(
                        color: _getQuadrantColor(log.quadrant),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  '${log.userName} • ${_formatDateTime(log.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            // 关联任务
            if (log.relatedTaskId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '关联任务: ${_getTaskTitle(log.relatedTaskId!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTaskTitle(String taskId) {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => Task(
        id: taskId,
        title: '未知任务',
        description: '',
        assigneeId: '',
        assigneeName: '',
        department: '',
        priority: 'p1',
        status: 'pending',
        createdAt: DateTime.now(),
        createdBy: '',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      ),
    );
    return task.title;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAddLogDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddLogDialog(
        user: widget.user,
        tasks: _tasks,
        onLogAdded: () {
          _loadData();
        },
      ),
    );
  }
}

class _AddLogDialog extends StatefulWidget {
  final User user;
  final List<Task> tasks;
  final VoidCallback onLogAdded;

  const _AddLogDialog({
    required this.user,
    required this.tasks,
    required this.onLogAdded,
  });

  @override
  State<_AddLogDialog> createState() => _AddLogDialogState();
}

class _AddLogDialogState extends State<_AddLogDialog> {
  final _formKey = GlobalKey<FormState>();
  final _actionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _moodController = TextEditingController();
  final _completionController = TextEditingController();
  
  String _selectedCategory = 'work';
  String _selectedQuadrant = 'important_not_urgent';
  String? _selectedTaskId;

  @override
  void dispose() {
    _actionController.dispose();
    _descriptionController.dispose();
    _moodController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final log = Log(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.user.id,
        userName: widget.user.name,
        action: _actionController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        quadrant: _selectedQuadrant,
        createdAt: DateTime.now(),
        relatedTaskId: _selectedTaskId,
      );

      final success = await ApiService.createLog(log);
      
      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onLogAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('日志添加成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('保存失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '添加日志',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 表单内容
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 活动标题
                      TextFormField(
                        controller: _actionController,
                        decoration: const InputDecoration(
                          labelText: '活动标题',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入活动标题';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 分类选择
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'work', child: Text('工作')),
                          DropdownMenuItem(value: 'learning', child: Text('学习')),
                          DropdownMenuItem(value: 'personal', child: Text('个人')),
                          DropdownMenuItem(value: 'meeting', child: Text('会议')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 四象限选择
                      DropdownButtonFormField<String>(
                        value: _selectedQuadrant,
                        decoration: const InputDecoration(
                          labelText: '重要紧急程度',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'important_urgent', child: Text('重要且紧急')),
                          DropdownMenuItem(value: 'important_not_urgent', child: Text('重要不紧急')),
                          DropdownMenuItem(value: 'not_important_urgent', child: Text('紧急不重要')),
                          DropdownMenuItem(value: 'not_important_not_urgent', child: Text('不重要不紧急')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedQuadrant = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 关联任务
                      DropdownButtonFormField<String?>(
                        value: _selectedTaskId,
                        decoration: const InputDecoration(
                          labelText: '关联任务（可选）',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('无关联任务')),
                          ...widget.tasks.map((task) => DropdownMenuItem<String?>(
                            value: task.id,
                            child: Text(task.title),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTaskId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 详细描述
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '详细描述',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入详细描述';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 心情感受
                      TextFormField(
                        controller: _moodController,
                        decoration: const InputDecoration(
                          labelText: '心情感受',
                          border: OutlineInputBorder(),
                          hintText: '今天的心情如何？有什么感受？',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // 完成情况
                      TextFormField(
                        controller: _completionController,
                        decoration: const InputDecoration(
                          labelText: '工作完成情况',
                          border: OutlineInputBorder(),
                          hintText: '今天的工作完成情况如何？',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              
              // 按钮
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveLog,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
