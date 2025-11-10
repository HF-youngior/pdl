import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class RequestScreen extends StatefulWidget {
  final User currentUser;
  final Task? task; // 如果传入task，则为编辑模式

  const RequestScreen({
    super.key,
    required this.currentUser,
    this.task,
  });

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  String? _selectedRequestType;
  String? _selectedAssigneeId;
  DateTime? _selectedDeadline;
  String? _selectedRelatedTaskId;
  
  List<User> _availableUsers = [];
  List<Map<String, dynamic>> _availableTasks = [];
  bool _isLoadingUsers = false;
  bool _isLoadingTasks = false;
  bool _isSubmitting = false;

  // 请求类型选项
  final List<String> _requestTypes = [
    '修改任务',
    '删除任务',
    '请假',
    '重新安排任务',
    '请来办公室',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    
    // 如果是编辑模式，初始化表单数据
    if (widget.task != null) {
      _selectedRequestType = widget.task!.requestType;
      _selectedAssigneeId = widget.task!.assigneeId;
      _descriptionController.text = widget.task!.description;
      _selectedDeadline = widget.task!.deadline;
      // related_task_id 需要从API返回的JSON中获取，Task模型中没有这个字段
      // 暂时设为null，后续可以通过API获取
      _selectedRelatedTaskId = null;
    }
    
    _loadUsers();
    _loadTasks();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // 角色等级函数
  int _roleRank(String role) {
    switch (role) {
      case 'founder':
      case 'admin':
        return 5;
      case 'department_head':
        return 4;
      case 'team_leader':
        return 3;
      case 'employee':
      default:
        return 1;
    }
  }

  // 加载可用用户列表（只显示同级或上级）
  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await ApiService.getUsers();
      final currentUserRank = _roleRank(widget.currentUser.role);
      
      // 筛选同级或上级用户
      final filteredUsers = users.where((user) {
        // 排除自己
        if (user.id == widget.currentUser.id) {
          return false;
        }
        // 只显示同级或上级（角色等级 >= 当前用户等级）
        final userRank = _roleRank(user.role);
        return userRank >= currentUserRank;
      }).toList();
      
      setState(() {
        _availableUsers = filteredUsers;
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('加载用户列表失败: $e');
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  // 加载任务列表（用于关联任务）
  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
    });

    try {
      final tasks = await ApiService.getTasks();
      setState(() {
        // 只显示非邀约任务
        _availableTasks = tasks.where((task) => !task.isRequest).map((task) => {
          'id': task.id,
          'title': task.title,
          'assigneeName': task.assigneeName,
        }).toList();
        _isLoadingTasks = false;
      });
      
      // 如果是编辑模式，尝试从API获取related_task_id
      if (widget.task != null && _selectedRelatedTaskId == null) {
        _loadRelatedTaskId();
      }
    } catch (e) {
      print('加载任务列表失败: $e');
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  // 从API获取related_task_id
  Future<void> _loadRelatedTaskId() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/${widget.task!.id}'),
        headers: ApiService.getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['related_task_id'] != null) {
          setState(() {
            _selectedRelatedTaskId = data['related_task_id'];
          });
        }
      }
    } catch (e) {
      print('获取关联任务ID失败: $e');
    }
  }

  // 选择截止时间
  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  // 提交邀约请求
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_selectedRequestType!.isNotEmpty || _selectedAssigneeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择请求类型和接收人'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 对于需要关联任务的请求类型，验证是否选择了关联任务
    const requiresRelatedTask = ['修改任务', '删除任务', '重新安排任务'];
    if (requiresRelatedTask.contains(_selectedRequestType) && _selectedRelatedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedRequestType}类型的邀约请求必须关联一个任务'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 格式化deadline
      String? deadlineStr;
      if (_selectedDeadline != null) {
        deadlineStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDeadline!);
      }

      // 如果是编辑模式，调用更新接口
      if (widget.task != null) {
        await ApiService.updateRequest(
          taskId: widget.task!.id,
          requestType: _selectedRequestType!,
          assigneeId: _selectedAssigneeId!,
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          relatedTaskId: _selectedRelatedTaskId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('邀约请求更新成功！'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // 创建模式
        await ApiService.createRequest(
          requestType: _selectedRequestType!,
          assigneeId: _selectedAssigneeId!,
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          relatedTaskId: _selectedRelatedTaskId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('邀约请求发送成功！'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.task != null ? '更新邀约失败: $e' : '发送邀约失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? '编辑邀约' : '向上邀约'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 请求类型
              _buildSectionTitle('请求类型'),
              DropdownButtonFormField<String>(
                value: _selectedRequestType,
                decoration: const InputDecoration(
                  labelText: '请求类型 *',
                  border: OutlineInputBorder(),
                ),
                items: _requestTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRequestType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择请求类型';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 接收人
              _buildSectionTitle('接收人'),
              _isLoadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedAssigneeId,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: '接收人 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: _availableUsers.map((user) {
                        final deptDisp = user.department ?? '未知部门';
                        return DropdownMenuItem<String>(
                          value: user.id,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 40,
                              maxHeight: 48,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  '$deptDisp · ${user.role}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _availableUsers.map((user) {
                          final deptDisp = user.department ?? '未知部门';
                          return Text(
                            '${user.name} · $deptDisp · ${user.role}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        setState(() {
                          _selectedAssigneeId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请选择接收人';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 24),

              // 请求详情
              _buildSectionTitle('请求详情'),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '请求详情 *',
                  hintText: '请详细描述您的请求内容...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入请求详情';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 期望回复时间
              _buildSectionTitle('期望回复时间'),
              InkWell(
                onTap: _selectDeadline,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '期望回复时间（可选）',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDeadline != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDeadline!.add(const Duration(hours: 8)))
                        : '点击选择（默认3天后）',
                    style: TextStyle(
                      color: _selectedDeadline != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 关联任务（可选）
              _buildSectionTitle('关联任务（可选）'),
              _isLoadingTasks
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedRelatedTaskId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '关联任务',
                        border: OutlineInputBorder(),
                        hintText: '如果请求与某个任务相关，请选择',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('无关联任务'),
                        ),
                        ..._availableTasks.map((task) {
                          return DropdownMenuItem<String>(
                            value: task['id'],
                            child: Text(
                              '${task['title']} (${task['assigneeName']})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRelatedTaskId = value;
                        });
                      },
                    ),
              const SizedBox(height: 32),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.task != null ? '更新邀约' : '发送邀约',
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
}

