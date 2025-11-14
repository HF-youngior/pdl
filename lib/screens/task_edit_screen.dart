import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/task.dart';
import '../models/user.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task; // 如果为null，表示创建新任务
  final User currentUser;
  final Function(Task)? onSave;
  final String? parentTaskId; // 父任务ID（用于创建子任务）

  const TaskEditScreen({
    super.key,
    this.task,
    required this.currentUser,
    this.onSave,
    this.parentTaskId,
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
  
  // 负责人选择
  List<User> _availableUsers = [];
  User? _selectedAssignee;
  bool _isLoadingUsers = false;
  
  // 图片相关
  final List<File> _selectedImages = [];
  final List<String> _persistedAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  // 可用的优先级选项
  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 'p0', 'label': '重要且紧急', 'color': Colors.red},
    {'value': 'p1', 'label': '重要不紧急', 'color': Colors.amber},
    {'value': 'p2', 'label': '不重要紧急', 'color': Colors.blue},
    {'value': 'p3', 'label': '不重要不紧急', 'color': Colors.green},
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
    _loadUsers();
  }
  
  // 加载可用用户列表
  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });
    
    try {
      final users = await ApiService.getUsers();
      setState(() {
        // 如果创建子任务，根据用户角色过滤可分配的用户
        List<User> filteredUsers = users;
        if (widget.parentTaskId != null) {
          // 如果是创建子任务，筛选可分配的下级用户
          switch (widget.currentUser.role) {
            case 'team_leader':
              // 团队长只能分配给下属员工
              // 注意：这里假设后端已经根据权限返回了可见的用户，但我们需要进一步筛选
              // 在实际项目中，应该根据 parent_id 关系过滤，这里先保留所有可见用户
              filteredUsers = users.where((u) => 
                u.role == 'employee' || u.id == widget.currentUser.id
              ).toList();
              break;
            case 'department_head':
              // 部门老总可以分配给本部门的团队长和员工
              filteredUsers = users.where((u) => 
                (u.role == 'team_leader' || u.role == 'employee') && 
                u.department == widget.currentUser.department
              ).toList();
              break;
            case 'admin':
            case 'founder':
              // 管理员和创始人可以看到所有用户，但创建子任务时优先选择下级
              filteredUsers = users.where((u) => 
                u.role != 'admin' && u.role != 'founder'
              ).toList();
              break;
            default:
              filteredUsers = users;
          }
        }
        
        _availableUsers = filteredUsers.isEmpty ? users : filteredUsers;
        
        // 如果是编辑现有任务，设置已选择的责任人
        if (widget.task != null) {
          _selectedAssignee = _availableUsers.firstWhere(
            (u) => u.id == widget.task!.assigneeId,
            orElse: () => _availableUsers.isNotEmpty ? _availableUsers.first : users.first,
          );
        } else {
          // 创建新任务时，默认选择当前用户（如果有权限派发）
          if (widget.currentUser.role != 'employee') {
            _selectedAssignee = _availableUsers.firstWhere(
              (u) => u.id == widget.currentUser.id,
              orElse: () => _availableUsers.isNotEmpty ? _availableUsers.first : null!,
            );
          } else {
            _selectedAssignee = _availableUsers.isNotEmpty ? _availableUsers.first : null;
          }
        }
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('加载用户列表失败: $e');
      setState(() {
        _isLoadingUsers = false;
      });
    }
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
      _descriptionController.text = _stripImageTag(widget.task!.description);
      _progressPercentage = (widget.task!.progressPercentage).toDouble();
      _priority = widget.task!.priority;
      _status = widget.task!.status;
      _deadline = widget.task!.deadline;
      _startTime = widget.task!.startTime;
      _endTime = widget.task!.endTime;
      _isAllDay = widget.task!.isAllDay;
      _persistedAttachments.addAll(widget.task!.attachments);
        } else {
      // 创建新任务，默认使用当前本地时间
      final now = DateTime.now();
      _startTime = now;
      _endTime = now.add(const Duration(hours: 1));
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
      
      // 确定责任人
      final assignee = _selectedAssignee ?? (widget.task?.assigneeId != null 
          ? _availableUsers.firstWhere(
              (u) => u.id == widget.task!.assigneeId,
              orElse: () => widget.currentUser,
            )
          : widget.currentUser);
      
      // 获取责任人的 department_id（优先使用departmentId，如果没有则使用department作为后备）
      String? departmentId = assignee.departmentId;
      
      // 如果departmentId为空或无效，尝试使用department字段（可能是部门名称）
      // 但这通常不应该发生，因为后端应该总是返回department_id
      if (departmentId == null || departmentId.isEmpty) {
        departmentId = assignee.department;
      }
      
      // 最终验证：确保有部门信息
      if (departmentId == null || departmentId.isEmpty) {
        throw Exception('用户缺少部门信息，无法创建任务。请确保该用户已分配部门。');
      }
      
      // 如果是邀约任务，只更新描述，其他字段保持不变
      final isRequest = widget.task?.isRequest ?? false;
      
      final attachmentPaths = [
        ..._persistedAttachments,
        ..._selectedImages.map((img) => img.path),
      ];
      
      final task = Task(
        id: widget.task?.id ?? const Uuid().v4(),
        title: isRequest ? (widget.task?.title ?? _titleController.text.trim()) : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assigneeId: isRequest ? (widget.task?.assigneeId ?? assignee.id) : assignee.id,
        assigneeName: isRequest ? (widget.task?.assigneeName ?? assignee.name) : assignee.name,
        department: isRequest ? (widget.task?.department ?? departmentId) : departmentId,
        priority: isRequest ? (widget.task?.priority ?? 'p0') : _priority,
        status: isRequest ? (widget.task?.status ?? 'pending') : _status,
        createdAt: widget.task?.createdAt ?? now,
        deadline: isRequest ? widget.task?.deadline : (_deadline ?? _endTime),
        createdBy: widget.task?.createdBy ?? widget.currentUser.id,
        startTime: isRequest ? (widget.task?.startTime ?? now) : (_startTime ?? now),
        endTime: isRequest ? (widget.task?.endTime ?? now.add(const Duration(hours: 1))) : (_endTime ?? now.add(const Duration(hours: 1))),
        progressPercentage: isRequest ? (widget.task?.progressPercentage ?? 0) : _progressPercentage.round(),
        isAllDay: isRequest ? (widget.task?.isAllDay ?? false) : _isAllDay,
        parentTaskId: widget.task?.parentTaskId ?? widget.parentTaskId, // 使用传入的父任务ID或保持原有
        isRequest: isRequest,
        requestType: widget.task?.requestType,
        requestResponse: widget.task?.requestResponse,
        specialNotes: widget.task?.specialNotes,
        attachments: attachmentPaths,
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
        // 如果是从任务详情页打开编辑的，返回更新后的任务
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
        title: Text(
          widget.task?.isRequest == true 
            ? '编辑邀约内容' 
            : (widget.task == null ? '创建任务' : '编辑任务')
        ),
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
              _buildSectionTitle(widget.task?.isRequest == true ? '邀约内容' : '基本信息'),
              // 邀约任务不显示标题编辑（标题由系统生成）
              if (widget.task?.isRequest != true)
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
              if (widget.task?.isRequest != true) const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: widget.task?.isRequest == true ? '邀约内容' : '任务描述',
                hint: widget.task?.isRequest == true ? '请输入邀约内容' : '请输入任务描述（可选）',
                maxLines: widget.task?.isRequest == true ? 5 : 3,
                validator: widget.task?.isRequest == true ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入邀约内容';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              
              // 图片上传
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '图片',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('从相册选择'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('拍照'),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImages[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
            if (_persistedAttachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _persistedAttachments.length,
                  itemBuilder: (context, index) {
                    final path = _persistedAttachments[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildPersistedAttachment(path),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePersistedAttachment(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 负责人选择（邀约任务不显示）
              if (widget.task?.isRequest != true) ...[
                _buildSectionTitle('负责人'),
                // 创建新任务时必须选择，编辑时如果当前用户是员工则只显示，否则可以修改
                if (widget.task == null || (widget.task != null && widget.currentUser.role != 'employee'))
                  _buildAssigneeSelector()
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.task?.assigneeName ?? '未分配',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
              ],

              // 邀约任务只显示描述，其他字段隐藏
              if (widget.task?.isRequest != true) ...[
                // 优先级和状态（邀约任务不显示）
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

                const SizedBox(height: 24),

                // 进度百分比滑块（邀约任务不显示）
                _buildSectionTitle('任务进度'),
                _buildProgressSlider(),
                
                // 进度百分比显示
                const SizedBox(height: 8),
                _buildProgressDisplay(),

                const SizedBox(height: 24),

                // 时间设置（邀约任务不显示）
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
              ],

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down),
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
              Expanded(
                child: Text(
                  item['label'],
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请选择$label';
        }
        return null;
      },
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
              ? DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal())
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
                    // 自动联动：进度变动自动修正状态
                    if (_progressPercentage == 100) {
                      _status = 'completed';
                    } else if (_progressPercentage >= 1 && _progressPercentage < 100) {
                      _status = 'in_progress';
                    }
                    // 0%时不主动动状态
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

  // 构建负责人选择器
  Widget _buildAssigneeSelector() {
    if (_isLoadingUsers) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availableUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '暂无可用用户，请稍后重试',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return DropdownButtonFormField<User>(
      value: _selectedAssignee,
      decoration: InputDecoration(
        labelText: '负责人 *',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.person),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      isExpanded: true,
      // 允许下拉项自适应高度，避免多行内容溢出产生黄黑提示
      isDense: true,
      itemHeight: null,
      icon: const Icon(Icons.arrow_drop_down),
      // 选中时仅展示单行内容，避免在输入框区域内出现两行导致溢出
      selectedItemBuilder: (context) {
        return _availableUsers.map((user) {
          return Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : 'U',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        }).toList();
      },
      items: _availableUsers.map((user) {
        // 根据用户角色显示不同的标签
        String roleLabel = '';
        switch (user.role) {
          case 'admin':
            roleLabel = '管理员';
            break;
          case 'founder':
            roleLabel = '创始人';
            break;
          case 'department_head':
            roleLabel = '部门老总';
            break;
          case 'team_leader':
            roleLabel = '团队长';
            break;
          case 'employee':
            roleLabel = '员工';
            break;
          default:
            roleLabel = user.role;
        }
        
        return DropdownMenuItem<User>(
          value: user,
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : 'U',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$roleLabel · ${user.department}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (user) {
        setState(() {
          _selectedAssignee = user;
        });
      },
      validator: (value) {
        if (value == null) {
          return '请选择负责人';
        }
        return null;
      },
    );
  }

  // 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  // 删除图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removePersistedAttachment(int index) {
    setState(() {
      _persistedAttachments.removeAt(index);
    });
  }

  Widget _buildPersistedAttachment(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildBrokenAttachment(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }
    return _buildBrokenAttachment();
  }

  Widget _buildBrokenAttachment() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  String _stripImageTag(String text) {
    final pattern = RegExp(r'\[图片:.*?\]', multiLine: true, dotAll: true);
    return text.replaceAll(pattern, '').trim();
  }
}