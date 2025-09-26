import 'package:flutter/material.dart';
import '../models/log.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class PersonalLogsScreen extends StatefulWidget {
  final User user;

  const PersonalLogsScreen({super.key, required this.user});

  @override
  State<PersonalLogsScreen> createState() => _PersonalLogsScreenState();
}

class _PersonalLogsScreenState extends State<PersonalLogsScreen> {
  List<Log> _logs = [];
  bool _isLoading = true;
  String? _error;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final logs = await ApiService.getLogs();
      setState(() {
        _logs = logs;
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
            onPressed: _loadLogs,
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
              onPressed: _loadLogs,
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
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) {
          final log = _filteredLogs[index];
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAddLogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加日志'),
        content: const Text('此功能需要在日志页面进行添加'),
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
