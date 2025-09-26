import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TestDataGenerator {
  static Future<void> generateSampleTasks() async {
    try {
      final now = DateTime.now();
      final tasks = <Task>[];

      // 生成一些示例任务
      for (int i = 0; i < 10; i++) {
        final startDate = now.add(Duration(days: i));
        final endDate = startDate.add(Duration(hours: 2));
        
        final colors = ['#4CAF50', '#2196F3', '#F44336', '#FF9800', '#9C27B0', '#E91E63'];
        final titles = [
          '晨会',
          '项目筹划', 
          '客户拜访',
          '视频剪辑',
          '年中总结',
          '团队建设',
          '产品评审',
          '市场调研',
          '财务报告',
          '技术培训'
        ];
        
        final locations = [
          '会议室A',
          '客户办公室',
          '制作室',
          '培训中心',
          '咖啡厅',
          null
        ];

        final task = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: titles[i % titles.length],
          description: '这是${titles[i % titles.length]}的详细描述',
          assigneeId: 'guest',
          assigneeName: '访客用户',
          department: '访客',
          priority: i % 3 == 0 ? 'high' : (i % 3 == 1 ? 'medium' : 'low'),
          status: 'pending',
          createdAt: now,
          deadline: endDate,
          createdBy: 'guest',
          startTime: startDate,
          endTime: endDate,
          color: colors[i % colors.length],
          location: locations[i % locations.length],
          isAllDay: i % 4 == 0,
        );

        tasks.add(task);
      }

      // 批量创建任务
      for (final task in tasks) {
        try {
          await TaskService.createTask(task);
        } catch (e) {
          // 忽略重复创建的错误
          print('任务可能已存在: ${task.title}');
        }
      }

      print('示例任务生成完成！');
    } catch (e) {
      print('生成示例任务失败: $e');
    }
  }

  static void showGenerateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成测试数据'),
        content: const Text('是否要生成一些示例任务用于测试？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await generateSampleTasks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('测试数据生成完成！'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }
}
