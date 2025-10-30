// lib/screens/personal_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:testflutterproject/models/personal_log.dart';
import 'package:testflutterproject/services/api_service.dart';
import 'package:testflutterproject/screens/personal_log_edit_screen.dart';
import 'package:intl/intl.dart';

class PersonalLogsScreen extends StatefulWidget {
  final String userId;
  const PersonalLogsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PersonalLogsScreenState createState() => _PersonalLogsScreenState();
}

class _PersonalLogsScreenState extends State<PersonalLogsScreen> {
  late Future<List<PersonalLog>> _logsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logsFuture = ApiService.getPersonalLogs(widget.userId);
    });
  }

  void _navigateToAddLog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalLogEditScreen(userId: widget.userId),
      ),
    );
    if (result == true) {
      _loadLogs();
    }
  }

  void _navigateToEditLog(PersonalLog log) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalLogEditScreen(
          userId: widget.userId,
          logToEdit: log,
        ),
      ),
    );
    if (result == true) {
      _loadLogs();
    }
  }

  Future<void> _deleteLog(String logId) async {
    try {
      await ApiService.deletePersonalLog(logId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已删除'), backgroundColor: Colors.green),
      );
      _loadLogs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(String logId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('确定要删除这条日志吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('删除', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteLog(logId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('个人日志'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _navigateToAddLog,
            tooltip: '添加新日志',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadLogs(),
        child: FutureBuilder<List<PersonalLog>>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('加载失败: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text('没有日志记录，点击右上角 "+" 添加。', style: TextStyle(fontSize: 16, color: Colors.grey)),
              );
            } else {
              final logs = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    elevation: 0, // 极简无阴影
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 圆角更大更现代
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8), // 更紧凑的内边距
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顶部一行（日期 + 关键词）
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(DateTime.parse(log.createdAt ?? '')),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: log.keywords.isNotEmpty
                                      ? Wrap(
                                          spacing: 5, runSpacing: 4, alignment: WrapAlignment.end,
                                          children: log.keywords.map((kw) => Container(
                                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            margin: EdgeInsets.only(left: 3, top: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.13),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.orange.withOpacity(0.6)),
                                            ),
                                            child: Text(kw, style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w500)),)).toList(),
                                        )
                                      : Text('无关键词', style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          // 内容区
                          Text(
                            log.content ?? '（无内容）',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: Colors.grey[800]), // 内容用浅灰色
                          ),
                          // 任务标签区（如果有）
                          if (log.taskUpdates.isNotEmpty) ...[
                            SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              children: log.taskUpdates.map((update) => Chip(
                                avatar: Icon(Icons.task_alt, size: 14,
                                  color: update.task_status == 'completed' || update.progress_percentage == 100 
                                        ? Colors.green[700]
                                        : Theme.of(context).primaryColor),
                                label: Text(update.taskName ?? '任务 #'+update.taskId, style: TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            )
                          ],
                          // 右下角操作按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showDeleteConfirmation(log.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[400],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  elevation: 0,
                                ),
                                icon: Icon(Icons.delete_outline, size: 18),
                                label: Text('删除', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}