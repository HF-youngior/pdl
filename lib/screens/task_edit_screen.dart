import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task; // 如果为null，表示创建新任务
  final User currentUser;
  final Function(Task)? onSave;

  const TaskEditScreen({
    super.key,
    this.task,
    required this.currentUser,
    this.onSave,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 任务属性
  String _priority = 'p1';
  String _status = 'pending';
  DateTime? _deadline;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isAllDay = false;
  bool _isLoading = false;
  double _progressPercentage = 0.0;

  // 可用的优先级选项
  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 'p0', 'label': 'P0 - 最高优先级', 'color': Colors.red},
    {'value': 'p1', 'label': 'P1 - 高优先级', 'color': Colors.amber},
    {'value': 'p2', 'label': 'P2 - 中优先级', 'color': Colors.blue},
    {'value': 'p3', 'label': 'P3 - 低优先级', 'color': Colors.green},
  ];

  // 可用的状态选项
  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'pending', 'label': '待处理'},
    {'value': 'in_progress', 'label': '进行中'},
    {'value': 'completed', 'label': '已完成'},
    {'value': 'cancelled', 'label': '已取消'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 初始化表单数据
  void _initializeForm() {
    if (widget.task != null) {
      // 编辑现有任务
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _progressPercentage = (widget.task!.progressPercentage).toDouble();
      _priority = widget.task!.priority;
      _status = widget.task!.status;
      _deadline = widget.task!.deadline;
      _startTime = widget.task!.startTime;
      _endTime = widget.task!.endTime;
      _isAllDay = widget.task!.isAllDay;
        } else {
      // 创建新任务，设置默认值
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  // 保存任务
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
    final task = Task(
        id: widget.task?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
        assigneeId: widget.task?.assigneeId ?? widget.currentUser.id,
        assigneeName: widget.task?.assigneeName ?? widget.currentUser.name,
        department: widget.task?.department ?? widget.currentUser.department,
        priority: _priority,
        status: _status,
        createdAt: widget.task?.createdAt ?? now,
        deadline: _deadline,
        createdBy: widget.task?.createdBy ?? widget.currentUser.id,
        startTime: _startTime ?? now,
        endTime: _endTime ?? now.add(const Duration(hours: 1)),
        progressPercentage: _progressPercentage.round(),
      isAllDay: _isAllDay,
    );

      // 调用服务保存任务
      if (widget.task == null) {
        await TaskService.createTask(task);
      } else {
        await TaskService.updateTask(task.id, task);
      }

      // 回调通知父组件
      widget.onSave?.call(task);
      
      if (mounted) {
        Navigator.of(context).pop(task);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.task == null ? '任务创建成功' : '任务更新成功'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 选择日期时间
  Future<void> _selectDateTime({
    required DateTime? initialDate,
    required String title,
    required Function(DateTime) onDateSelected,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        onDateSelected(dateTime);
      }
    }
  }

  // 选择日期（仅日期，不包含时间）
  Future<void> _selectDate({
    required DateTime? initialDate,
    required String title,
    required Function(DateTime) onDateSelected,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? '创建任务' : '编辑任务'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
          TextButton(
            onPressed: _saveTask,
            child: const Text(
              '保存',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本信息
              _buildSectionTitle('基本信息'),
              _buildTextField(
                controller: _titleController,
                label: '任务标题',
                hint: '请输入任务标题',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入任务标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: '任务描述',
                hint: '请输入任务描述（可选）',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // 进度百分比滑块
              _buildProgressSlider(),

              const SizedBox(height: 24),

              // 优先级和状态
              _buildSectionTitle('优先级和状态'),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _priority,
                      label: '优先级',
                      items: _priorityOptions,
                      onChanged: (value) {
                        setState(() {
                          _priority = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      value: _status,
                      label: '状态',
                      items: _statusOptions,
                      onChanged: (value) {
                        setState(() {
                          _status = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              // 进度百分比显示
              _buildProgressDisplay(),

              const SizedBox(height: 24),

              // 时间设置
              _buildSectionTitle('时间设置'),
              _buildDateTimeField(
                label: '开始时间',
                value: _startTime,
                onTap: () => _selectDateTime(
                  initialDate: _startTime,
                  title: '选择开始时间',
                  onDateSelected: (dateTime) {
                    setState(() {
                      _startTime = dateTime;
                      // 如果结束时间早于开始时间，自动调整结束时间
                      if (_endTime == null || _endTime!.isBefore(dateTime)) {
                        _endTime = dateTime.add(const Duration(hours: 1));
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildDateTimeField(
                label: '结束时间',
                value: _endTime,
                onTap: () => _selectDateTime(
                  initialDate: _endTime,
                  title: '选择结束时间',
                  onDateSelected: (dateTime) {
                    setState(() {
                      _endTime = dateTime;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('全天任务'),
                subtitle: const Text('勾选后任务将显示为全天事件'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTask,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.task == null ? '创建任务' : '更新任务',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建节标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  // 构建下拉选择框
  Widget _buildDropdown({
    required String value,
    required String label,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item['value'],
          child: Row(
            children: [
              if (item['color'] != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(item['label']),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // 构建日期时间选择字段
  Widget _buildDateTimeField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label + (isOptional ? ' (可选)' : ''),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(value)
              : isOptional
                  ? '未设置'
                  : '请选择',
          style: TextStyle(
            color: value != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  // 构建进度百分比滑块
  Widget _buildProgressSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '任务进度',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
              const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
              child: Slider(
                value: _progressPercentage,
                min: 0.0,
                max: 100.0,
                divisions: 100,
                label: '${_progressPercentage.round()}%',
                          onChanged: (value) {
                            setState(() {
                    _progressPercentage = value;
                            });
                          },
                        ),
                      ),
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${_progressPercentage.round()}%',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
        const SizedBox(height: 4),
                  Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
            Text(
              '0%',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
    );
  }

  // 构建进度显示
  Widget _buildProgressDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
        color: _getProgressColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getProgressColor().withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getProgressIcon(),
            color: _getProgressColor(),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _getProgressText(),
            style: TextStyle(
              color: _getProgressColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            width: 80,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progressPercentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getProgressColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 根据进度获取颜色
  Color _getProgressColor() {
    if (_progressPercentage == 0) {
      return Colors.grey;
    } else if (_progressPercentage < 30) {
      return Colors.red;
    } else if (_progressPercentage < 60) {
      return Colors.orange;
    } else if (_progressPercentage < 90) {
      return Colors.blue;
    } else if (_progressPercentage < 100) {
      return Colors.green;
    } else {
      return Colors.green.shade700;
    }
  }

  // 根据进度获取图标
  IconData _getProgressIcon() {
    if (_progressPercentage == 0) {
      return Icons.play_circle_outline;
    } else if (_progressPercentage < 30) {
      return Icons.schedule;
    } else if (_progressPercentage < 60) {
      return Icons.trending_up;
    } else if (_progressPercentage < 90) {
      return Icons.double_arrow;
    } else if (_progressPercentage < 100) {
      return Icons.check_circle_outline;
    } else {
      return Icons.check_circle;
    }
  }

  // 根据进度获取文本
  String _getProgressText() {
    if (_progressPercentage == 0) {
      return '未开始';
    } else if (_progressPercentage < 30) {
      return '刚开始';
    } else if (_progressPercentage < 60) {
      return '进行中';
    } else if (_progressPercentage < 90) {
      return '接近完成';
    } else if (_progressPercentage < 100) {
      return '即将完成';
    } else {
      return '已完成';
    }
  }
}