import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/personal_log.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/task_service.dart';
import 'package:testflutterproject/models/log_task_update.dart';

class LogEnhancedScreen extends StatefulWidget {
  final User user;

  const LogEnhancedScreen({super.key, required this.user});

  // 对外暴露：显示“添加日志”对话框（供其他模块调用）
  static void showAddLogDialog({
    required BuildContext context,
    required User user,
    required List<Task> tasks,
    required VoidCallback onLogAdded,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AddLogDialog(
        user: user,
        tasks: tasks,
        onLogAdded: onLogAdded,
      ),
    );
  }

  @override
  State<LogEnhancedScreen> createState() => _LogEnhancedScreenState();
}

class _LogEnhancedScreenState extends State<LogEnhancedScreen> {
  List<PersonalLog> _logs = [];
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _filterCategory = 'all';
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'keyword'; // keyword | date | content

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    List<PersonalLog> list = _logs;
    // 保留原分类过滤（若以后仍有使用）
    if (_filterCategory != 'all') {
      list = list.where((log) => (log.category??'').toLowerCase() == _filterCategory).toList();
    }
    final q = _searchController.text.trim();
    if (q.isEmpty) return list;
    final qLower = q.toLowerCase();
    return list.where((log) {
      if (_searchType == 'keyword') {
        try { return log.keywords.any((k) => k.toLowerCase().contains(qLower)); } catch (_) { return false; }
      } else if (_searchType == 'content') {
        return (log.content ?? '').toLowerCase().contains(qLower);
      } else {
        DateTime? d = log.logDate;
        if (d == null && (log.createdAt??'').isNotEmpty) {
          try { d = DateTime.parse(log.createdAt!); } catch (_) {}
        }
        if (d == null) return false;
        final ds = DateFormat('yyyy-MM-dd').format(d);
        return ds.contains(q);
      }
    }).toList();
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
          // 顶部搜索栏（替换原标签筛选）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: _buildCuteSearchBar(context),
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

  Widget _buildCuteSearchBar(BuildContext context) {
    final hint = _searchType == 'date'
        ? '按日期搜索，如 2025-10-31'
        : _searchType == 'keyword'
        ? '按关键词搜索'
        : '按内容搜索';

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.25)),
            ),
            child: PopupMenuButton<String>(
              tooltip: '选择搜索类型',
              onSelected: (v) {
                setState(() {
                  _searchType = v;
                  _searchController.clear();
                });
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'date', child: _menuItem('日期')),
                PopupMenuItem(value: 'keyword', child: _menuItem('关键词')),
                PopupMenuItem(value: 'content', child: _menuItem('内容')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  Icon(
                    _searchType == 'date'
                        ? Icons.calendar_today
                        : _searchType == 'keyword'
                        ? Icons.tag
                        : Icons.notes,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _searchType == 'date' ? '日期' : _searchType == 'keyword' ? '关键词' : '内容',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600),
                  )
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.withOpacity(0.2)),
                ),
                suffixIcon: _searchType == 'date'
                    ? IconButton(
                  tooltip: '选择日期',
                  icon: const Icon(Icons.event, size: 18),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) {
                      final s = DateFormat('yyyy-MM-dd').format(picked);
                      setState(() {
                        _searchController.text = s;
                      });
                    }
                  },
                )
                    : const Icon(Icons.search, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
          )
        ],
      ),
    );
  }

  Widget _menuItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    return GestureDetector(
        onTap: () => _showLogDetailDialog(log),
        child: Card(
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
                if (log.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: log.images.length,
                      itemBuilder: (context, index) {
                        final path = log.images[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImagePreview(path),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (log.locationName != null && log.locationName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          log.locationName!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
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
                      '${widget.user.name} • '
                      // 检查 logDate 是否为 null。如果不为 null，则格式化日期。
                          '${log.logDate != null ? DateFormat('yyyy-MM-dd').format(log.logDate!) : '-'}',
                      style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold),
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
                            '关联任务: ${linkage.taskName ?? _getTaskTitle(linkage.taskId)}',
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

                // 右下角操作区：编辑 & 删除
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionIcon(
                      icon: Icons.edit_rounded,
                      color: Colors.blueAccent,
                      tooltip: '编辑',
                      onTap: () => _showEditLogDialog(log),
                    ),
                    const SizedBox(width: 8),
                    _buildActionIcon(
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      tooltip: '删除',
                      onTap: () => _confirmDeleteLog(log),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
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

  Task? _getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
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

  Widget _buildImagePreview(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 100,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 100,
        height: 80,
        fit: BoxFit.cover,
      );
    }
    return _brokenImage();
  }

  Widget _brokenImage() {
    return Container(
      width: 100,
      height: 80,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  void _showLogDetailDialog(PersonalLog log) {
    showDialog(
      context: context,
      builder: (ctx) {
        final date = log.logDate ?? log.createdAtDate;
        final dateText = date != null ? DateFormat('yyyy-MM-dd').format(date) : '日期待补充';
        final timeText = date != null ? DateFormat('HH:mm').format(date) : '--:--';
        final weatherEmoji = _getWeatherEmoji(log.weather ?? 'sunny');
        final categoryColor = _getCategoryColor(log.category ?? '');
        final categoryLabel = _getCategoryText(log.category ?? '');
        final categoryIcon = _getCategoryIcon(log.category ?? '');
        final size = MediaQuery.of(ctx).size;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8, top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(weatherEmoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(timeText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: categoryColor.withOpacity(0.15),
                        child: Icon(categoryIcon, color: categoryColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (log.logTitle.isNotEmpty ? log.logTitle : (log.title ?? '无标题')),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildInfoTag(categoryLabel, categoryColor, icon: Icons.category),
                                _buildInfoTag(widget.user.name, Colors.teal, icon: Icons.person),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSectionTitle(Icons.tag, '关键词'),
                        const SizedBox(height: 8),
                        if (log.keywords.isEmpty)
                          _buildEmptyHint('还没有添加关键词，快来补充三个小词语吧～')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: log.keywords
                                .map((keyword) => Chip(
                                      backgroundColor: Colors.orange.withOpacity(0.12),
                                      labelStyle: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                      label: Text(keyword),
                                    ))
                                .toList(),
                          ),
                        const SizedBox(height: 18),
                        _buildDetailSectionTitle(Icons.notes, '详细描述'),
                        const SizedBox(height: 8),
                        _buildCuteCard(
                          Text(
                            (log.content?.trim().isNotEmpty ?? false)
                                ? log.content!.trim()
                                : '这篇日志还没有详细描述，留白也别有趣味～',
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                        if (log.images.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildDetailSectionTitle(Icons.photo, '图文并茂'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: log.images.length,
                              itemBuilder: (context, index) {
                                final path = log.images[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImagePreview(path),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _buildDetailSectionTitle(Icons.location_on, '记录位置'),
                        const SizedBox(height: 8),
                        if ((log.locationName ?? '').isEmpty)
                          _buildEmptyHint('未记录具体位置～')
                        else
                          _buildCuteCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.place, size: 18, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        log.locationName!,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                if (log.latitude != null && log.longitude != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '(${log.latitude!.toStringAsFixed(4)}, ${log.longitude!.toStringAsFixed(4)})',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),
                        _buildDetailSectionTitle(Icons.assignment, '关联任务'),
                        const SizedBox(height: 8),
                        if (log.linkages.isEmpty)
                          _buildEmptyHint('暂未关联任务')
                        else
                          Column(
                            children: log.linkages.map(_buildDetailTaskCard).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('关闭'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showEditLogDialog(log);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('去编辑'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.blue[700]),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildCuteCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _buildEmptyHint(String text) {
    return _buildCuteCard(
      Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTaskCard(LogTaskLinkage linkage) {
    final task = _getTaskById(linkage.taskId);
    final taskName = (linkage.taskName?.trim().isNotEmpty ?? false)
        ? linkage.taskName!.trim()
        : (task?.title ?? _getTaskTitle(linkage.taskId));
    final priorityLabel = task?.getPriorityLabel() ?? task?.priority.toUpperCase() ?? 'P?';
    final priorityColor = task?.getPriorityColor() ?? Colors.deepPurple;
    final statusText = task?.getStatusText() ?? (linkage.taskStatus ?? '未标记');
    final statusColor = task?.getStatusColor() ?? Colors.blueGrey;
    final deadlineText = task?.deadline != null
        ? DateFormat('yyyy-MM-dd').format(task!.deadline!)
        : '未设置';
    final progressValue = linkage.progressPercentage.clamp(0, 100);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _buildInfoTag('优先级 $priorityLabel', priorityColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: Colors.grey),
              const SizedBox(width: 4),
              Text('截止: $deadlineText', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progressValue / 100,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('进度 $progressValue%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              _buildInfoTag(statusText, statusColor),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddLogDialog() {
    LogEnhancedScreen.showAddLogDialog(
      context: context,
      user: widget.user,
      tasks: _tasks,
      onLogAdded: () {
        _loadData();
      },
    );
  }

  void _showEditLogDialog(PersonalLog log) {
    showDialog(
      context: context,
      builder: (context) => _EditLogDialog(
        user: widget.user,
        tasks: _tasks,
        originLog: log,
        onLogUpdated: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _confirmDeleteLog(PersonalLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条日志吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletePersonalLog(log.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red));
    }
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
  final _actionController = TextEditingController(text: '个人日志');
  final _categoryInputController = TextEditingController(text: 'work');
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

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
    _categoryInputController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (_isSaving) return;
    // 1) 校验必填：标题与正文
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        uploadedImageUrls = await ApiService.uploadImages(_selectedImages);
      }

      final logPayload = {
        'log_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'title': _actionController.text.trim().isEmpty
            ? '个人日志'
            : _actionController.text.trim(),
        'content': _descriptionController.text.trim(),
        'category': _categoryInputController.text.trim().isEmpty
            ? 'work'
            : _categoryInputController.text.trim(),
        'weather': _selectedWeather,
        'keywords': _keywords,
        'images': uploadedImageUrls,
      };

      if (_locationName != null) {
        logPayload['location'] = {
          'name': _locationName,
          'latitude': _latitude,
          'longitude': _longitude,
        };
      }

      final requestBody = {
        'log': logPayload,
        'linkages': _selectedTaskEdits.values
            .map((edit) => {
          'task_id': edit.taskId,
          'progress_percentage': edit.progress ?? 0,
          'task_status': edit.status,
        })
            .toList(),
      };

      // 2) 调用 API
      await ApiService.createPersonalLog(requestBody);

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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      } else {
        _isSaving = false;
      }
    }
  }

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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被永久拒绝，请前往系统设置开启')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e')),
      );
    }
  }

  void _clearLocation() {
    setState(() {
      _locationName = null;
      _latitude = null;
      _longitude = null;
    });
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

                      // 标题与分类输入（在关键词上方，左右两个小文本框）
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _actionController,
                              decoration: const InputDecoration(
                                labelText: '标题(title)',
                                hintText: '个人日志',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 13),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return '请输入标题';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _categoryInputController,
                              decoration: const InputDecoration(
                                labelText: '分类(category)',
                                hintText: 'work/learning/...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return '请输入分类';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

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
                      _buildImagePickerSection(),
                      const SizedBox(height: 16),
                      _buildLocationSection(),
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
                    onPressed: _isSaving ? null : _saveLog,
                    child: Text(_isSaving ? '保存中...' : '保存'),
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

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.photo, size: 18),
            SizedBox(width: 6),
            Text('图片附件'),
          ],
        ),
        const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, size: 18),
            SizedBox(width: 6),
            Text('地理位置'),
          ],
        ),
        const SizedBox(height: 8),
        if (_locationName != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.place, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationName!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: _clearLocation,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            icon: _isLoadingLocation
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.my_location),
            label: Text(_isLoadingLocation ? '定位中…' : '获取当前位置'),
          ),
      ],
    );
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

class _EditLogDialog extends StatefulWidget {
  final User user;
  final List<Task> tasks;
  final PersonalLog originLog;
  final VoidCallback onLogUpdated;

  const _EditLogDialog({
    required this.user,
    required this.tasks,
    required this.originLog,
    required this.onLogUpdated,
  });

  @override
  State<_EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<_EditLogDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String _selectedWeather;
  final Map<String, _AssociatedTaskEdit> _selectedTaskEdits = {};
  final TextEditingController _keywordInputController = TextEditingController();
  List<String> _keywords = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];
  final List<String> _persistedImages = [];
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    final log = widget.originLog;
    _titleController = TextEditingController(text: log.title ?? (log.logTitle ?? '个人日志'));
    _categoryController = TextEditingController(text: (log.category ?? 'work'));
    _descriptionController = TextEditingController(text: log.content ?? '');
    _selectedDate = log.logDate ?? DateTime.now();
    _selectedWeather = log.weather ?? 'sunny';
    _keywords = List<String>.from(log.keywords);
    _persistedImages.addAll(log.images);
    _locationName = log.locationName;
    _latitude = log.latitude;
    _longitude = log.longitude;

    for (final l in log.linkages) {
      _selectedTaskEdits[l.taskId] = _AssociatedTaskEdit(
        taskId: l.taskId,
        title: l.taskName ?? '',
        priority: 'p1',
        deadline: null,
        progress: l.progressPercentage,
        status: l.taskStatus ?? 'in_progress',
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final body = {
        'log': {
          'title': _titleController.text.trim().isEmpty ? '个人日志' : _titleController.text.trim(),
          'content': _descriptionController.text.trim(),
          'category': _categoryController.text.trim().isEmpty ? 'work' : _categoryController.text.trim(),
          'log_date': _selectedDate.toIso8601String(),
          'weather': _selectedWeather,
          'keywords': _keywords,
          'images': [
            ..._persistedImages,
            ..._selectedImages.map((img) => img.path),
          ],
          if (_locationName != null)
            'location': {
              'name': _locationName,
              'latitude': _latitude,
              'longitude': _longitude,
            },
        },
        'linkages': _selectedTaskEdits.values.map((e) => {
          'task_id': e.taskId,
          'progress_percentage': e.progress ?? 0,
          'task_status': e.status,
        }).toList(),
      };

      await ApiService.updatePersonalLog(widget.originLog.id, body);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onLogUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已更新'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removePersistedImage(int index) {
    setState(() {
      _persistedImages.removeAt(index);
    });
  }

  Widget _buildPersistedImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 100,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 100,
        height: 90,
        fit: BoxFit.cover,
      );
    }
    return _brokenImage();
  }

  Widget _brokenImage() {
    return Container(
      width: 100,
      height: 90,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被永久拒绝，请前往系统设置开启')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e')),
      );
    }
  }

  void _clearLocation() {
    setState(() {
      _locationName = null;
      _latitude = null;
      _longitude = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('编辑日志', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker()),
                          const SizedBox(width: 12),
                          _buildWeatherPicker(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(labelText: '标题(title)', isDense: true, border: OutlineInputBorder()),
                              style: const TextStyle(fontSize: 13),
                              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _categoryController,
                              decoration: const InputDecoration(labelText: '分类(category)', isDense: true, border: OutlineInputBorder()),
                              style: const TextStyle(fontSize: 12),
                              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入分类' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildKeywordsInputArea(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: '详细描述', border: OutlineInputBorder()),
                        maxLines: 3,
                        validator: (v) => (v == null || v.isEmpty) ? '请输入详细描述' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('相册'),
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
                          height: 90,
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
                                        height: 90,
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
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                      if (_persistedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _persistedImages.length,
                            itemBuilder: (context, index) {
                              final path = _persistedImages[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildPersistedImage(path),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removePersistedImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black45,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('地理位置', style: TextStyle(fontWeight: FontWeight.bold)),
                                  if (_locationName != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearLocation,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_locationName != null)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _locationName!,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                                  icon: _isLoadingLocation
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.my_location),
                                  label: Text(_isLoadingLocation ? '定位中...' : '获取当前位置'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 关联任务区域：新增添加按钮 + 已关联列表
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('关联任务', style: Theme.of(context).textTheme.titleMedium),
                          TextButton.icon(
                            onPressed: _showAddTaskToEdit,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('添加任务'),
                          ),
                        ],
                      ),
                      _buildAssociatedTaskList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                  const SizedBox(width: 16),
                  ElevatedButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (picked != null) {
          setState(() { _selectedDate = picked; });
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
            Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherPicker() {
    return InkWell(
      onTap: () async {
        final value = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _weatherTile(ctx, 'sunny', '晴朗', '☀️'),
                _weatherTile(ctx, 'cloudy', '多云', '⛅'),
                _weatherTile(ctx, 'light_rain', '小雨', '🌧️'),
                _weatherTile(ctx, 'heavy_rain', '大雨', '⛈️'),
                _weatherTile(ctx, 'snow', '下雪', '❄️'),
                _weatherTile(ctx, 'storm', '雷暴', '⚡'),
                _weatherTile(ctx, 'fog', '多雾', '🌫️'),
              ],
            ),
          ),
        );
        if (value != null) {
          setState(() { _selectedWeather = value; });
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
            Text(_weatherEmoji(_selectedWeather), style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  ListTile _weatherTile(BuildContext ctx, String value, String label, String emoji) {
    return ListTile(leading: Text(emoji, style: const TextStyle(fontSize: 18)), title: Text(label), onTap: () => Navigator.of(ctx).pop(value));
  }

  Widget _buildKeywordsInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordInputController,
                decoration: const InputDecoration(labelText: '添加关键词', border: OutlineInputBorder()),
                onSubmitted: (_) => _addKeyword(),
                enabled: _keywords.length < 3,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addKeyword, child: const Text('添加')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _keywords
              .map((k) => Chip(label: Text(k), onDeleted: () { setState(() { _keywords.remove(k); }); }))
              .toList(),
        ),
      ],
    );
  }

  void _addKeyword() {
    final value = _keywordInputController.text.trim();
    if (value.isEmpty) return;
    if (_keywords.length >= 3) return;
    if (_keywords.contains(value)) return;
    setState(() { _keywords.add(value); _keywordInputController.clear(); });
  }

  void _showAddTaskToEdit() {
    final existing = _selectedTaskEdits.keys.toSet();
    // 放宽筛选条件：当前用户相关(被指派或创建者为当前用户)，并排除已选择
    final candidates = widget.tasks
        .where((t) =>
    !existing.contains(t.id) &&
        (
            t.assigneeId == widget.user.id ||
                t.createdBy == widget.user.id ||
                t.assigneeName == widget.user.name
        ))
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可添加的任务')),
      );
      return;
    }
    Task? selected;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择要关联的任务'),
          content: DropdownButtonFormField<Task>(
            isExpanded: true,
            items: candidates.map((t) => DropdownMenuItem<Task>(value: t, child: Text(t.title, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) { selected = v; },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            TextButton(
              onPressed: () {
                if (selected != null) {
                  setState(() {
                    _selectedTaskEdits[selected!.id] = _AssociatedTaskEdit(
                      taskId: selected!.id,
                      title: selected!.title,
                      priority: selected!.priority,
                      deadline: selected!.deadline,
                      progress: 0,
                      status: 'in_progress',
                    );
                  });
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  // ==== Copied helpers to fix undefined methods ====
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
