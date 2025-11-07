import 'package:flutter/material.dart';
import '../models/important_item.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'company_important_edit_screen.dart';

class CompanyImportantScreen extends StatefulWidget {
  final User user;

  const CompanyImportantScreen({super.key, required this.user});

  @override
  State<CompanyImportantScreen> createState() => _CompanyImportantScreenState();
}

class _CompanyImportantScreenState extends State<CompanyImportantScreen> {
  List<ImportantItem> _importantItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImportantItems();
  }

  Future<void> _loadImportantItems() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final items = await ApiService.getImportantItems();
      setState(() {
        _importantItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
        title: const Text('公司十大重要事项'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // 只有管理员和创始人可以编辑
          if (widget.user.role == 'admin' || widget.user.role == 'founder')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditDialog();
              },
              tooltip: '编辑重要事项',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImportantItems,
            tooltip: '刷新',
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
              onPressed: _loadImportantItems,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_importantItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无重要事项',
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
      onRefresh: _loadImportantItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _importantItems.length,
        itemBuilder: (context, index) {
          final item = _importantItems[index];
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
                          item.title,
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
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // 状态和截止时间
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(item.status),
                          style: TextStyle(
                            color: _getStatusColor(item.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (item.deadline != null)
                        Text(
                          '截止: ${_formatDateTime(item.deadline!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  void _showEditDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompanyImportantEditScreen(user: widget.user),
      ),
    ).then((result) {
      // 编辑完成后刷新数据
      if (result == true) {
        _loadImportantItems();
      }
    });
  }
}
