import 'package:flutter/material.dart';
import '../models/important_item.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/time_utils.dart';

class CompanyImportantEditScreen extends StatefulWidget {
  final User user;

  const CompanyImportantEditScreen({super.key, required this.user});

  @override
  State<CompanyImportantEditScreen> createState() => _CompanyImportantEditScreenState();
}

class _CompanyImportantEditScreenState extends State<CompanyImportantEditScreen> {
  List<ImportantItem> _allItems = [];
  List<String> _selectedItemIds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  Future<void> _loadAllItems() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final items = await ApiService.getAllImportantItems();
      setState(() {
        _allItems = items;
        // 初始化已选择的事项
        _selectedItemIds = items
            .where((item) => item.status == 'selected' || item.status == 'in_progress')
            .map((item) => item.id)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else if (_selectedItemIds.length < 10) {
        _selectedItemIds.add(itemId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最多只能选择10个重要事项'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _saveSelection() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ApiService.batchUpdateImportantItemsSelection(_selectedItemIds);
      
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功选择 ${_selectedItemIds.length} 个重要事项'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // 返回true表示保存成功
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑公司重要事项'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
            tooltip: '添加重要事项',
          ),
          TextButton(
            onPressed: _saveSelection,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
              onPressed: _loadAllItems,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 选择状态提示
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '已选择 ${_selectedItemIds.length}/10 个重要事项',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // 事项列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _allItems.length,
            itemBuilder: (context, index) {
              final item = _allItems[index];
              final isSelected = _selectedItemIds.contains(item.id);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 6 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected 
                      ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => _toggleItemSelection(item.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 选择框
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                              width: 2,
                            ),
                            color: isSelected 
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        
                        // 内容
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题和优先级
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected 
                                            ? Theme.of(context).primaryColor
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(item.priority).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getPriorityColor(item.priority),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _getPriorityText(item.priority),
                                      style: TextStyle(
                                        color: _getPriorityColor(item.priority),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // 描述
                              if (item.description.isNotEmpty) ...[
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                              ],
                              
                              // 部门信息和操作按钮
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '部门: ${item.department}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Spacer(),
                                  // 编辑按钮
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showEditItemDialog(item),
                                    tooltip: '编辑事项',
                                    color: Colors.blue,
                                  ),
                                  // 删除按钮
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => _showDeleteConfirmDialog(item),
                                    tooltip: '删除事项',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 显示添加事项对话框
  void _showAddItemDialog() {
    _showItemDialog();
  }

  // 显示编辑事项对话框
  void _showEditItemDialog(ImportantItem item) {
    _showItemDialog(item: item);
  }

  // 显示删除确认对话框
  void _showDeleteConfirmDialog(ImportantItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除"${item.title}"吗？此操作不可撤销！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteItem(item);
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 显示事项编辑对话框
  void _showItemDialog({ImportantItem? item}) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?.title ?? '');
    final descriptionController = TextEditingController(text: item?.description ?? '');
    String selectedPriority = item?.priority ?? 'p1';
    String selectedStatus = item?.status ?? 'pending';
    DateTime? selectedDeadline = item?.deadline;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑重要事项' : '添加重要事项'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '事项标题 *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '事项描述',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(
                        labelText: '优先级',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'p0', child: Text('重要且紧急')),
                        DropdownMenuItem(value: 'p1', child: Text('重要不紧急')),
                        DropdownMenuItem(value: 'p2', child: Text('不重要紧急')),
                        DropdownMenuItem(value: 'p3', child: Text('不重要不紧急')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isEdit) ...[
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: '状态',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('待处理')),
                          DropdownMenuItem(value: 'in_progress', child: Text('进行中')),
                          DropdownMenuItem(value: 'completed', child: Text('已完成')),
                          DropdownMenuItem(value: 'cancelled', child: Text('已取消')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    ListTile(
                      title: Text(selectedDeadline != null 
                          ? '截止时间: ${_formatDateTime(selectedDeadline!)}'
                          : '选择截止时间（可选）'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDeadline ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDeadline ?? DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              selectedDeadline = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    if (selectedDeadline != null)
                      ListTile(
                        title: const Text('清除截止时间'),
                        trailing: const Icon(Icons.clear),
                        onTap: () {
                          setState(() {
                            selectedDeadline = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('请输入事项标题'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    
                    if (isEdit) {
                      await _updateItem(
                        item!,
                        titleController.text.trim(),
                        descriptionController.text.trim(),
                        selectedPriority,
                        selectedStatus,
                        selectedDeadline,
                      );
                    } else {
                      await _addItem(
                        titleController.text.trim(),
                        descriptionController.text.trim(),
                        selectedPriority,
                        selectedDeadline,
                      );
                    }
                  },
                  child: Text(isEdit ? '更新' : '添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 添加事项
  Future<void> _addItem(String title, String description, String priority, DateTime? deadline) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ApiService.createImportantItem(
        title: title,
        description: description,
        priority: priority,
        deadline: deadline,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('重要事项添加成功'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllItems(); // 重新加载数据
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 更新事项
  Future<void> _updateItem(ImportantItem item, String title, String description, String priority, String status, DateTime? deadline) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ApiService.updateImportantItem(
        id: item.id,
        title: title,
        description: description,
        priority: priority,
        status: status,
        deadline: deadline,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('重要事项更新成功'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllItems(); // 重新加载数据
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 删除事项
  Future<void> _deleteItem(ImportantItem item) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ApiService.deleteImportantItem(item.id);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('重要事项删除成功'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllItems(); // 重新加载数据
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return TimeUtils.formatDateTimeWithZone(dateTime);
  }
}
