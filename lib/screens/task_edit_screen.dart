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
  DateTime? _previousStartTime;
  DateTime? _previousEndTime;
  bool _isAllDay = false;
  bool _isLoading = false;
  double _progressPercentage = 0.0;
  
  // 负责人选择
  List<User> _availableUsers = [];
  User? _selectedAssignee;
  bool _isLoadingUsers = false;
  bool _multiAssignEnabled = false;
  final Set<String> _selectedAssigneeIds = {};
  
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
          _selectedAssigneeIds
            ..clear()
            ..add(widget.task!.assigneeId);
        } else {
          // 创建新任务时，默认选择当前用户（如果有权限派发）
          if (widget.currentUser.role != 'employee') {
            _selectedAssignee = _availableUsers.firstWhere(
              (u) => u.id == widget.currentUser.id,
              orElse: () => _availableUsers.isNotEmpty ? _availableUsers.first : null!,
            );
            if (_selectedAssignee != null) {
              _selectedAssigneeIds
                ..clear()
                ..add(_selectedAssignee!.id);
            }
          } else {
            _selectedAssignee = _availableUsers.isNotEmpty ? _availableUsers.first : null;
            if (_selectedAssignee != null) {
              _selectedAssigneeIds
                ..clear()
                ..add(_selectedAssignee!.id);
            }
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
      _status = widget.task!.status == 'cancelled' ? 'completed' : widget.task!.status;
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

  bool _isAllDayStartTime(DateTime dateTime) => dateTime.hour == 0 && dateTime.minute == 0;

  bool _isAllDayEndTime(DateTime dateTime) => dateTime.hour == 23 && dateTime.minute == 59;

  Future<bool> _confirmCancelAllDay() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('是否取消“全天任务”？'),
        content: const Text('您正在设置具体的时间段，是否取消“全天任务”并使用新的时间？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保持全天'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取消全天'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _exitAllDayMode() {
    _isAllDay = false;
    _previousStartTime = null;
    _previousEndTime = null;
  }

  Future<void> _handleStartTimeSelected(DateTime dateTime) async {
    bool exitAllDay = false;
    if (_isAllDay && !_isAllDayStartTime(dateTime)) {
      exitAllDay = await _confirmCancelAllDay();
      if (!exitAllDay) {
        return;
      }
    }

    setState(() {
      if (exitAllDay) {
        _exitAllDayMode();
      }
      _startTime = dateTime;
      if (_endTime == null || _endTime!.isBefore(dateTime)) {
        _endTime = dateTime.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _handleEndTimeSelected(DateTime dateTime) async {
    if (_startTime != null && dateTime.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('结束时间不能早于开始时间'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool exitAllDay = false;
    if (_isAllDay && !_isAllDayEndTime(dateTime)) {
      exitAllDay = await _confirmCancelAllDay();
      if (!exitAllDay) {
        return;
      }
    }

    setState(() {
      if (exitAllDay) {
        _exitAllDayMode();
      }
      _endTime = dateTime;
    });
  }

  // 保存任务
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startTime != null &&
        _endTime != null &&
        _endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('结束时间不能早于开始时间'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 校验负责人选择（新建任务必须至少选择一名负责人）
    if (widget.task == null && _selectedAssigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一名负责人'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 新建任务时，在保存前弹出确认负责人弹窗
    if (widget.task == null && widget.task?.isRequest != true) {
      final selectedUsers = _availableUsers
          .where((u) => _selectedAssigneeIds.contains(u.id))
          .toList();
    
      if (selectedUsers.isEmpty) {
        // 理论上不会走到这里，上面的校验已经处理
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请至少选择一名负责人'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    
      final isSingle = selectedUsers.length == 1;
      final titleWord = isSingle ? '这名' : '这些';
      final namesText = selectedUsers
          .map((u) {
            final dept = (u.department?.isNotEmpty == true)
                ? u.department
                : '未分配部门';
            return '${u.name}（$dept）';
          })
          .join('\n');
    
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认负责人'),
          content: Text('确认选择$titleWord员工为负责人？\n\n$namesText'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
    
      if (confirmed != true) {
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 先上传新选择的图片
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在上传图片...'), duration: Duration(seconds: 1)),
        );
        
        final urls = await ApiService.uploadImages(_selectedImages);
        if (urls.length != _selectedImages.length) {
          throw Exception('部分图片上传失败，请重试');
        }
        uploadedImageUrls = urls;
      }

      // 合并已存在的图片URL和新上传的图片URL
      final allAttachmentUrls = [
        ..._persistedAttachments, // 这些已经是URL了
        ...uploadedImageUrls, // 新上传的URL
      ];

      final now = DateTime.now();
      
      // 判断是否为邀约任务（邀约任务不支持多选派发）
      final isRequest = widget.task?.isRequest ?? false;
      
      // 如果是新建任务且启用多选且选择了多名员工，则一次为多名员工创建任务
      if (!isRequest &&
          widget.task == null &&
          _selectedAssigneeIds.length > 1) {
        final createdTasks = <Task>[];

        for (final user in _availableUsers.where((u) => _selectedAssigneeIds.contains(u.id))) {
          // 获取责任人的 department_id（优先使用departmentId，如果没有则使用department作为后备）
          String? departmentId = user.departmentId;
          
          if (departmentId == null || departmentId.isEmpty) {
            departmentId = user.department;
          }
          
          if (departmentId == null || departmentId.isEmpty) {
            throw Exception('用户 \'${user.name}\' 缺少部门信息，无法创建任务。');
          }

          final task = Task(
            id: const Uuid().v4(),
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            assigneeId: user.id,
            assigneeName: user.name,
            department: departmentId,
            priority: _priority,
            status: _status,
            createdAt: now,
            deadline: _deadline ?? _endTime,
            createdBy: widget.currentUser.id,
            startTime: _startTime ?? now,
            endTime: _endTime ?? now.add(const Duration(hours: 1)),
            progressPercentage: _progressPercentage.round(),
            isAllDay: _isAllDay,
            parentTaskId: widget.parentTaskId,
            isRequest: false,
            requestType: null,
            requestResponse: null,
            specialNotes: null,
            attachments: allAttachmentUrls,
          );

          final saved = await TaskService.createTask(task);
          createdTasks.add(saved);
        }

        if (createdTasks.isNotEmpty) {
          widget.onSave?.call(createdTasks.first);
        }
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已为 ${_selectedAssigneeIds.length} 名员工创建任务'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // 单任务保存逻辑（兼容邀约/编辑等场景）
      // 确定责任人
      final assignee = _selectedAssignee ?? (widget.task?.assigneeId != null 
          ? _availableUsers.firstWhere(
              (u) => u.id == widget.task!.assigneeId,
              orElse: () => widget.currentUser,
            )
          : widget.currentUser);
      
      // 获取责任人的 department_id（优先使用departmentId，如果没有则使用department作为后备）
      String? departmentId = assignee.departmentId;
      
      if (departmentId == null || departmentId.isEmpty) {
        departmentId = assignee.department;
      }
      
      // 最终验证：确保有部门信息
      if (departmentId == null || departmentId.isEmpty) {
        throw Exception('用户缺少部门信息，无法创建任务。请确保该用户已分配部门。');
      }
      
      // 如果是邀约任务，只更新描述，其他字段保持不变
      final taskIsRequest = widget.task?.isRequest ?? false;
      
      final task = Task(
        id: widget.task?.id ?? const Uuid().v4(),
        title: taskIsRequest ? (widget.task?.title ?? _titleController.text.trim()) : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assigneeId: taskIsRequest ? (widget.task?.assigneeId ?? assignee.id) : assignee.id,
        assigneeName: taskIsRequest ? (widget.task?.assigneeName ?? assignee.name) : assignee.name,
        department: taskIsRequest ? (widget.task?.department ?? departmentId) : departmentId,
        priority: taskIsRequest ? (widget.task?.priority ?? 'p0') : _priority,
        status: taskIsRequest ? (widget.task?.status ?? 'pending') : _status,
        createdAt: widget.task?.createdAt ?? now,
        deadline: taskIsRequest ? widget.task?.deadline : (_deadline ?? _endTime),
        createdBy: widget.task?.createdBy ?? widget.currentUser.id,
        startTime: taskIsRequest ? (widget.task?.startTime ?? now) : (_startTime ?? now),
        endTime: taskIsRequest ? (widget.task?.endTime ?? now.add(const Duration(hours: 1))) : (_endTime ?? now.add(const Duration(hours: 1))),
        progressPercentage: taskIsRequest ? (widget.task?.progressPercentage ?? 0) : _progressPercentage.round(),
        isAllDay: taskIsRequest ? (widget.task?.isAllDay ?? false) : _isAllDay,
        parentTaskId: widget.task?.parentTaskId ?? widget.parentTaskId, // 使用传入的父任务ID或保持原有
        isRequest: taskIsRequest,
        requestType: widget.task?.requestType,
        requestResponse: widget.task?.requestResponse,
        specialNotes: widget.task?.specialNotes,
        attachments: allAttachmentUrls,
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

  Future<void> _confirmDeleteTask() async {
    if (widget.task == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('删除后将无法恢复，确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await TaskService.deleteTask(widget.task!.id);
      if (!mounted) return;
      Navigator.of(context).pop({'deleted': true});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除任务失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          else ...[
            if (widget.task != null &&
                widget.task?.isRequest != true &&
                widget.task?.createdBy == widget.currentUser.id)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除任务',
                onPressed: _confirmDeleteTask,
              ),
            TextButton(
              onPressed: _saveTask,
              child: const Text(
                '保存',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
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
                            // 状态变更时自动同步进度
                            if (_status == 'pending') {
                              _progressPercentage = 0;
                            } else if (_status == 'in_progress') {
                              _progressPercentage = 50;
                            } else if (_status == 'completed') {
                              _progressPercentage = 100;
                            }
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
                    onDateSelected: (dateTime) => _handleStartTimeSelected(dateTime),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDateTimeField(
                  label: '结束时间',
                  value: _endTime,
                  onTap: () => _selectDateTime(
                    initialDate: _endTime,
                    title: '选择结束时间',
                    onDateSelected: (dateTime) => _handleEndTimeSelected(dateTime),
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
                      if (value) {
                        // 记录切换前的时间，便于取消全天时恢复
                        _previousStartTime = _startTime;
                        _previousEndTime = _endTime;

                        // 将时间调整为当天 00:00 和 23:59，保留原日期
                        final baseStart = _startTime ?? _endTime ?? DateTime.now();
                        final startDate = DateTime(
                          baseStart.year,
                          baseStart.month,
                          baseStart.day,
                        );
                        _startTime = DateTime(
                          startDate.year,
                          startDate.month,
                          startDate.day,
                          0,
                          0,
                        );

                        final baseEnd = _endTime ?? _startTime ?? DateTime.now();
                        final endDate = DateTime(
                          baseEnd.year,
                          baseEnd.month,
                          baseEnd.day,
                        );
                        _endTime = DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                          23,
                          59,
                        );
                      } else {
                        // 取消全天任务，恢复之前设定的时间
                        _startTime = _previousStartTime ?? _startTime;
                        _endTime = _previousEndTime ??
                            (_startTime != null ? _startTime!.add(const Duration(hours: 1)) : null);
                        _previousStartTime = null;
                        _previousEndTime = null;
                      }
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
                    if (_progressPercentage == 0) {
                      _status = 'pending';
                    } else if (_progressPercentage == 100) {
                      _status = 'completed';
                    } else if (_progressPercentage >= 1 && _progressPercentage < 100) {
                      _status = 'in_progress';
                    }
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
  
    final isNewTask = widget.task == null;
  
    // 新建任务：直接使用可勾选的多选列表
    if (isNewTask) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '可勾选一名或多名员工作为负责人，保存时会为每名员工各创建一条任务。',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildMultiAssigneeList(),
        ],
      );
    }
  
    // 编辑任务：保持单选下拉的形式
    return _buildSingleAssigneeDropdown();
  }
  
  Widget _buildSingleAssigneeDropdown() {
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
      isDense: true,
      itemHeight: null,
      icon: const Icon(Icons.arrow_drop_down),
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
        final roleLabel = _getRoleLabel(user);
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
          _selectedAssigneeIds.clear();
          if (user != null) {
            _selectedAssigneeIds.add(user.id);
          }
        });
      },
      validator: (value) {
        if (!_multiAssignEnabled && value == null) {
          return '请选择负责人';
        }
        return null;
      },
    );
  }

  Widget _buildMultiAssigneeList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: Scrollbar(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _availableUsers.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (context, index) {
            final user = _availableUsers[index];
            final isSelected = _selectedAssigneeIds.contains(user.id);
            final roleLabel = _getRoleLabel(user);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAssigneeIds.remove(user.id);
                  } else {
                    _selectedAssigneeIds.add(user.id);
                  }
                });
              },
              child: Container(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.08)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.2),
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
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$roleLabel · ${user.department}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedAssigneeIds.add(user.id);
                          } else {
                            _selectedAssigneeIds.remove(user.id);
                          }
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getRoleLabel(User user) {
    switch (user.role) {
      case 'admin':
        return '管理员';
      case 'founder':
        return '创始人';
      case 'department_head':
        return '部门老总';
      case 'team_leader':
        return '团队长';
      case 'employee':
        return '员工';
      default:
        return user.role;
    }
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