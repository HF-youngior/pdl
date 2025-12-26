import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.task, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PDL 项目',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '项目介绍',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'PDL 是一套任务与日志统一管理的平台，结合四象限方法论与数据分析，提供：\n\n'
              '- 任务派发与进度跟踪\n'
              '- 日志记录与智能生成个人关键信息\n'
              '- 数据面板（今日/近7日）与优先级分布\n'
              '- MBTI 测试记录与摘要展示\n\n'
              '我们致力于用简单、直观的方式提升个人与团队的效率。',
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                '版本 1.0.0',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


