import 'package:flutter/material.dart';
import '../services/task_service.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _status = '未测试';
  String _error = '';

  Future<void> _testApi() async {
    setState(() {
      _status = '测试中...';
      _error = '';
    });

    try {
      final tasks = await TaskService.getTasks();
      setState(() {
        _status = '成功！获取到 ${tasks.length} 个任务';
        _error = '';
      });
    } catch (e) {
      setState(() {
        _status = '失败';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'API连接测试',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('状态: $_status'),
            const SizedBox(height: 20),
            if (_error.isNotEmpty) ...[
              const Text('错误信息:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: _testApi,
              child: const Text('测试API连接'),
            ),
          ],
        ),
      ),
    );
  }
}
