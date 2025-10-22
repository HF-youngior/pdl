import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final DateTime? initialDate;
  final Future<void> Function(Task) onSave;

  const TaskEditScreen({
    super.key,
    this.task,
    this.initialDate,
    required this.onSave,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String _selectedColor = '#4CAF50';
  String _selectedPriority = 'important_not_urgent';
  bool _isAllDay = false;

  final List<Map<String, String>> _colorOptions = [
    {'name': '绿色', 'value': '#4CAF50'},
    {'name': '蓝色', 'value': '#2196F3'},
    {'name': '红色', 'value': '#F44336'},
    {'name': '橙色', 'value': '#FF9800'},
    {'name': '紫色', 'value': '#9C27B0'},
    {'name': '粉色', 'value': '#E91E63'},
    {'name': '青色', 'value': '#00BCD4'},
    {'name': '黄色', 'value': '#FFEB3B'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _locationController.text = widget.task!.location ?? '';
      _startDate = widget.task!.startTime;
      _startTime = TimeOfDay.fromDateTime(widget.task!.startTime);
      _endDate = widget.task!.endTime;
      _endTime = TimeOfDay.fromDateTime(widget.task!.endTime);
      _selectedColor = widget.task!.color;
      _selectedPriority = widget.task!.priority;
      _isAllDay = widget.task!.isAllDay;
    } else if (widget.initialDate != null) {
      _startDate = widget.initialDate!;
      _endDate = widget.initialDate!;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    } else {
      final now = DateTime.now();
      _startDate = now;
      _endDate = now;
      _startTime = TimeOfDay.fromDateTime(now);
      _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate! : _endDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    if (_isAllDay) return; // 全天任务不需要选择时间
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime! : _endTime!,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写必填字段'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 验证时间逻辑
    if (_endDate!.isBefore(_startDate!) || 
        (_endDate!.isAtSameMomentAs(_startDate!) && !_isAllDay && _endTime!.hour <= _startTime!.hour)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('结束时间必须晚于开始时间'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _isAllDay ? 0 : _startTime!.hour,
      _isAllDay ? 0 : _startTime!.minute,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _isAllDay ? 23 : _endTime!.hour,
      _isAllDay ? 59 : _endTime!.minute,
    );

    final task = Task(
      id: widget.task?.id ?? '', // 新任务让后端生成ID
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assigneeId: widget.task?.assigneeId ?? 'guest',
      assigneeName: widget.task?.assigneeName ?? '访客用户',
      department: widget.task?.department ?? '访客',
      priority: _selectedPriority,
      status: widget.task?.status ?? 'pending',
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      deadline: endDateTime,
      createdBy: widget.task?.createdBy ?? 'guest',
      startTime: startDateTime,
      endTime: endDateTime,
      color: _selectedColor,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      isAllDay: _isAllDay,
    );

    try {
      // 显示保存提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.task == null ? '正在创建任务...' : '正在保存修改...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );

      await widget.onSave(task);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? '新建任务' : '编辑任务'),
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
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
              // 任务标题
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '任务标题',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入任务标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 任务描述
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '任务描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // 全天任务开关
              SwitchListTile(
                title: const Text('全天任务'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value;
                  });
                },
              ),

              // 开始时间
              ListTile(
                title: const Text('开始时间'),
                subtitle: Text(
                  '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')} '
                  '${_isAllDay ? '' : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  await _selectDate(context, true);
                  if (!_isAllDay) {
                    await _selectTime(context, true);
                  }
                },
              ),

              // 结束时间
              ListTile(
                title: const Text('结束时间'),
                subtitle: Text(
                  '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')} '
                  '${_isAllDay ? '' : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  await _selectDate(context, false);
                  if (!_isAllDay) {
                    await _selectTime(context, false);
                  }
                },
              ),

              const SizedBox(height: 16),

              // 地点
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '地点（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 任务分类
              const Text('任务分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'important_urgent', child: Text('工作')),
                  DropdownMenuItem(value: 'important_not_urgent', child: Text('学习')),
                  DropdownMenuItem(value: 'not_important_urgent', child: Text('生活')),
                  DropdownMenuItem(value: 'not_important_not_urgent', child: Text('其他')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // 颜色选择
              const Text('任务颜色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color['value']!;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _parseColor(color['value']!),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      // 底部保存按钮
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                widget.task == null ? '创建任务' : '保存修改',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.blue;
    }
  }
}
