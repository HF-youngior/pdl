import 'package:flutter/material.dart';
import '../models/personal_log.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/task_service.dart';
import '../models/user.dart';
import 'package:testflutterproject/models/log_task_update.dart';

class LogEnhancedScreen extends StatefulWidget {
  final User user;

  const LogEnhancedScreen({super.key, required this.user});

  @override
  State<LogEnhancedScreen> createState() => _LogEnhancedScreenState();
}

class _LogEnhancedScreenState extends State<LogEnhancedScreen> {
  List<PersonalLog> _logs = [];
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
        ApiService.getPersonalLogs(widget.user.id),
        ApiService.getTasks(),
      ]);

      setState(() {
        _logs = futures[0] as List<PersonalLog>;
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

  List<PersonalLog> get _filteredLogs {
    if (_filterCategory == 'all') {
      return _logs;
    }
    return _logs.where((log) => (log.category??'').toLowerCase() == _filterCategory).toList();
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

  Widget _buildLogCard(PersonalLog log) {
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
                  _getCategoryIcon(log.category??''),
                  color: _getCategoryColor(log.category??''),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.logTitle ?? '无标题',
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
                    color: _getCategoryColor(log.category??'').withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategoryText(log.category??''),
                    style: TextStyle(
                      color: _getCategoryColor(log.category??''),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 描述
            if (log.content != null && log.content!.isNotEmpty)
              Text(
                log.content ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            // 天气和关键词信息
            Row(
              children: [
                // 天气emoji
                Text(
                  _getWeatherEmoji(log.weather ?? 'sunny'),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                
                // 关键词
                if (log.keywords.isNotEmpty) ...[
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      children: log.keywords.take(3).map((keyword) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          keyword,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                Text(
                  '${widget.user.name} • ${_formatDateTime(DateTime.parse(log.createdAt??''))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            // 关联任务
            if (log.linkages.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...log.linkages.map((linkage) => Container(
                margin: const EdgeInsets.only(bottom: 4),
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
                    Expanded(
                      child: Text(
                        '关联任务: ${_getTaskTitle(linkage.taskId)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${linkage.progressPercentage}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )).toList(),
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

  // 天气emoji映射方法
  String _getWeatherEmoji(String weather) {
    switch (weather) {
      case 'sunny':
        return '☀️';
      case 'cloudy':
        return '⛅';
      case 'light_rain':
        return '🌧️';
      case 'heavy_rain':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'storm':
        return '⚡';
      case 'fog':
        return '🌫️';
      default:
        return '☀️';
    }
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
  // 日志标题与正文输入控制器
  final _actionController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 旧版字段（分类/四象限/单任务关联）已废弃，不再在 UI 中展示
  // 如需兼容后端旧接口，内部将使用合理默认值
  String _selectedCategory = 'work';
  String? _selectedTaskId; // 仅用于兼容字段（选择的第一个关联任务）

  // 新增：日期、天气、关键词、关联任务编辑状态
  DateTime _selectedDate = DateTime.now();
  String _selectedWeather = 'sunny'; // sunny, cloudy, light_rain, heavy_rain, snow, storm, fog
  final List<String> _keywords = [];
  final TextEditingController _keywordInputController = TextEditingController();
  final Map<String, _AssociatedTaskEdit> _selectedTaskEdits = {}; // taskId -> edit state
  // 任务搜索输入与焦点（用于清空与收起下拉）
  TextEditingController? _taskSearchController;
  FocusNode? _taskSearchFocusNode;

  @override
  void dispose() {
    _actionController.dispose();
    _descriptionController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    // 1) 校验必填：标题与正文
    if (!_formKey.currentState!.validate()) return;

    try {
      // 1) 组装一个匹配当前模型的对象
      final log = PersonalLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.user.id,
        title: _actionController.text.trim().isEmpty
            ? '个人日志'
            : _actionController.text.trim(),
        content: _buildLogDescription(),
        category: _selectedCategory,
        isCompleted: false,
        createdAt: DateTime.now().toIso8601String(),
        weather: _selectedWeather,
        keywords: _keywords,
        // 修复名称：用 taskUpdates
        taskUpdates: _selectedTaskEdits.values
            .map((edit) => LogTaskUpdate(
                  taskId: edit.taskId,
                  taskName: edit.title,
                  progress_percentage: edit.progress ?? 0,
                  task_status: edit.status,
                ))
            .toList(),
      );

      // 2) 调用 API（传 JSON Map）
      await ApiService.createPersonalLog(log.toJson());

      // 3) 同步更新每个已关联任务的进度/状态（逐条尝试，失败不阻断整体）
      for (final edit in _selectedTaskEdits.values) {
        try {
          await TaskService.updateTaskStatus(
            edit.taskId,
            status: edit.status,
            progressPercentage: edit.progress,
            specialNotes: null,
          );
        } catch (e) {
          // 单个任务失败不阻断整体
        }
      }

      // 4) 成功后的操作
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

  String _buildLogDescription() {
    final parts = <String>[];
    if (_keywords.isNotEmpty) {
      parts.add('关键词: ${_keywords.join(', ')}');
    }
    parts.add(_descriptionController.text.trim());
    return parts.where((e) => e.isNotEmpty).join('\n\n');
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
              
              // 表单内容：将旧版的分类/四象限/心情/完成情况全部替换为新设计
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 日期/天气 选择行
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerCard(context),
                          ),
                          const SizedBox(width: 12),
                          _buildWeatherPickerButton(context),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 关键词输入区
                      _buildKeywordsInputArea(),
                      const SizedBox(height: 16),
                      
                      // 去除“活动标题”输入框：action 将在保存时使用默认“个人日志”或内联规则生成
                      
                      // 正文输入：今日总结/复盘，包含富文本功能占位按钮
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '详细描述',
                          border: OutlineInputBorder(),
                          hintText: '今天也辛苦啦~',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入详细描述';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // 去除加粗/列表占位按钮
                      const SizedBox(height: 16),

                      // 关联任务选择与编辑
                      _buildAssociateTaskSelector(context),
                      const SizedBox(height: 8),
                      _buildAssociatedTaskList(),
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

  // UI 片段：日期选择卡片
  Widget _buildDatePickerCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue.withOpacity(0.06),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // 文案移除：仅显示已选日期
          ],
        ),
      ),
    );
  }

  // UI 片段：天气选择按钮
  Widget _buildWeatherPickerButton(BuildContext context) {
    final weatherToEmoji = {
      'sunny': '☀️',
      'cloudy': '⛅',
      'light_rain': '🌧️',
      'heavy_rain': '⛈️',
      'snow': '❄️',
      'storm': '⚡',
      'fog': '🌫️',
    };
    return InkWell(
      onTap: () async {
        final value = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWeatherOption(ctx, 'sunny', '晴朗', weatherToEmoji['sunny']!),
                  _buildWeatherOption(ctx, 'cloudy', '多云', weatherToEmoji['cloudy']!),
                  _buildWeatherOption(ctx, 'light_rain', '小雨', weatherToEmoji['light_rain']!),
                  _buildWeatherOption(ctx, 'heavy_rain', '大雨', weatherToEmoji['heavy_rain']!),
                  _buildWeatherOption(ctx, 'snow', '下雪', weatherToEmoji['snow']!),
                  _buildWeatherOption(ctx, 'storm', '雷暴', weatherToEmoji['storm']!),
                  _buildWeatherOption(ctx, 'fog', '多雾', weatherToEmoji['fog']!),
                ],
              ),
            );
          },
        );
        if (value != null) {
          setState(() {
            _selectedWeather = value;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.orange.withOpacity(0.06),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weatherEmoji(_selectedWeather),
              style: const TextStyle(fontSize: 18),
            ),
            // 文案移除：仅显示天气图标
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherOption(BuildContext context, String value, String label, String emoji) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 18)),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  String _weatherEmoji(String value) {
    switch (value) {
      case 'sunny':
        return '☀️';
      case 'cloudy':
        return '⛅';
      case 'light_rain':
        return '🌧️';
      case 'heavy_rain':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'storm':
        return '⚡';
      case 'fog':
        return '🌫️';
      default:
        return '☀️';
    }
  }

  // UI 片段：关键词区
  Widget _buildKeywordsInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordInputController,
                decoration: InputDecoration(
                  labelText: _keywords.length < 3 ? '添加关键词' : null,
                  hintText: _keywords.length >= 3 ? '够了够了 三个能概括' : null,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addKeyword(),
                enabled: _keywords.length < 3,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addKeyword,
              child: const Text('添加'),
            )
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _keywords
              .map((k) => Chip(
                    label: Text(k),
                    onDeleted: () {
                      setState(() {
                        _keywords.remove(k);
                      });
                    },
                  ))
              .toList(),
        ),
        // 文本框已显示提示语，这里不再单独提示
      ],
    );
  }

  void _addKeyword() {
    final value = _keywordInputController.text.trim();
    if (value.isEmpty) return;
    if (_keywords.length >= 3) return;
    if (_keywords.contains(value)) return;
    setState(() {
      _keywords.add(value);
      _keywordInputController.clear();
    });
  }

  // 关联任务选择器
  Widget _buildAssociateTaskSelector(BuildContext context) {
    final taskItems = widget.tasks
        .where((t) => t.status == 'in_progress' || t.status == 'completed')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 6),
            const Text('关联任务'),
            const Spacer(),
            Text('${_selectedTaskEdits.length} 已关联'),
          ],
        ),
        const SizedBox(height: 8),
        Autocomplete<Task>(
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.toLowerCase();
            return taskItems.where((t) => t.title.toLowerCase().contains(q));
          },
          displayStringForOption: (t) => t.title,
          onSelected: (task) {
            setState(() {
              _selectedTaskEdits.putIfAbsent(
                task.id,
                () => _AssociatedTaskEdit(
                  taskId: task.id,
                  title: task.title,
                  priority: task.priority,
                  deadline: task.deadline,
                  progress: 0,
                  status: task.status,
                ),
              );
            });
            // 选择后：清空输入并收起下拉
            _taskSearchController?.clear();
            _taskSearchFocusNode?.unfocus();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _taskSearchController = controller;
            _taskSearchFocusNode = focusNode;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: '搜索任务标题...',
                border: OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final t = options.elementAt(index);
                      return ListTile(
                        title: Text(t.title),
                        subtitle: Text('优先级: ${t.priority}  截止: ${t.deadline != null ? _fmtDate(t.deadline!) : '无'}'),
                        onTap: () => onSelected(t),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 已关联任务列表
  Widget _buildAssociatedTaskList() {
    if (_selectedTaskEdits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withOpacity(0.05),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('尚未关联任务'),
        ),
      );
    }
    final edits = _selectedTaskEdits.values.toList();
    return Column(
      children: edits.map((e) => _buildTaskEditCard(e)).toList(),
    );
  }

  Widget _buildTaskEditCard(_AssociatedTaskEdit edit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(edit.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: '移除',
                  onPressed: () {
                    setState(() {
                      _selectedTaskEdits.remove(edit.taskId);
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTag('优先级: ${edit.priority.toUpperCase()}'),
                const SizedBox(width: 8),
                _buildTag('截止: ${edit.deadline != null ? _fmtDate(edit.deadline!) : '无'}'),
              ],
            ),
            const SizedBox(height: 12),
            // 进度
            Row(
              children: [
                const Text('完成进度'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: (edit.progress ?? 0).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${edit.progress ?? 0}%',
                    onChanged: (v) {
                      setState(() {
                        edit.progress = v.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${edit.progress ?? 0}%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 状态
            Row(
              children: [
                const Text('任务状态'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: edit.status,
                  items: const [
                    DropdownMenuItem(value: 'in_progress', child: Text('进行中')),
                    DropdownMenuItem(value: 'completed', child: Text('已完成')),
                    DropdownMenuItem(value: 'cancelled', child: Text('已中断')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      edit.status = v;
                      // 若选择“已完成”，自动将进度置为100%
                      if (v == 'completed') {
                        edit.progress = 100;
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _AssociatedTaskEdit {
  final String taskId;
  final String title;
  final String priority;
  final DateTime? deadline;
  int? progress;
  String status;

  _AssociatedTaskEdit({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.deadline,
    required this.progress,
    required this.status,
  });
}
