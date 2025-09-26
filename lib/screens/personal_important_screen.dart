import 'package:flutter/material.dart';
import '../models/personal_info.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class PersonalImportantScreen extends StatefulWidget {
  final User user;

  const PersonalImportantScreen({super.key, required this.user});

  @override
  State<PersonalImportantScreen> createState() => _PersonalImportantScreenState();
}

class _PersonalImportantScreenState extends State<PersonalImportantScreen> {
  List<PersonalInfo> _personalInfo = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
  }

  Future<void> _loadPersonalInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final info = await ApiService.getPersonalInfo(widget.user.id);
      setState(() {
        _personalInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

  IconData _getQuadrantIcon(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return Icons.priority_high;
      case 'important_not_urgent':
        return Icons.schedule;
      case 'not_important_urgent':
        return Icons.flash_on;
      case 'not_important_not_urgent':
        return Icons.check_circle_outline;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人十大信息展示'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditDialog();
            },
            tooltip: '编辑个人信息',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPersonalInfo,
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
              onPressed: _loadPersonalInfo,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_personalInfo.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_pin,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无个人信息',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '个人信息将根据您的日志自动生成',
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
      onRefresh: _loadPersonalInfo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _personalInfo.length,
        itemBuilder: (context, index) {
          final info = _personalInfo[index];
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
                  // 标题和象限
                  Row(
                    children: [
                      Icon(
                        _getQuadrantIcon(info.quadrant),
                        color: _getQuadrantColor(info.quadrant),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          info.title,
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
                          color: _getQuadrantColor(info.quadrant).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getQuadrantColor(info.quadrant),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getQuadrantText(info.quadrant),
                          style: TextStyle(
                            color: _getQuadrantColor(info.quadrant),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 描述
                  if (info.description.isNotEmpty) ...[
                    Text(
                      info.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // 创建时间
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '创建时间: ${_formatDateTime(info.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  // 相关任务
                  if (info.relatedTaskId != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.assignment,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '关联任务: ${info.relatedTaskId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑个人信息'),
        content: const Text('个人信息将根据您的日志自动生成，您也可以在日志页面手动添加重要信息'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
