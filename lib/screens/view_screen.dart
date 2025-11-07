import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../widgets/calendar_widget.dart';
import '../screens/task_edit_screen.dart';
import '../screens/log_edit_screen.dart';

class ViewScreen extends StatefulWidget {
  final User user;
  
  const ViewScreen({
    super.key,
    required this.user,
  });

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  // 创建任务
  Future<void> _createTask(DateTime? date) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          currentUser: widget.user,
        ),
      ),
    );

    if (result != null && mounted) {
      // 任务创建成功，CalendarWidget会自动刷新
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('任务创建成功'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 编辑任务
  Future<void> _editTask(Task task) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: task,
          currentUser: widget.user,
        ),
      ),
    );

    if (result != null && mounted) {
      // 任务编辑成功
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('任务更新成功'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 添加日志
  Future<void> _addLog(DateTime date) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditScreen(
          user: widget.user,
        ),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('日志创建成功'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视图'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: CalendarWidget(
        tasks: const [], // CalendarWidget内部会加载数据
        currentDate: _currentDate,
        onDateSelected: (date) {
          setState(() {
            _currentDate = date;
          });
        },
        onTaskSelected: _editTask,
        onTaskAdd: _createTask,
        onLogAdd: _addLog,
      ),
    );
  }
}
