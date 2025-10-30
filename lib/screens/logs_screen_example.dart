import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/mock_data.dart';
import 'personal_logs_screen.dart';

/// 日志界面使用示例
/// 展示如何在应用中使用 PersonalLogsScreen
class LogsScreenExample extends StatelessWidget {
  const LogsScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志管理示例'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '日志管理功能演示',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '点击下方按钮体验不同的用户角色',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            
            // 员工角色
            ElevatedButton.icon(
              onPressed: () => _navigateToLogsScreen(
                context, 
                MockData.createMockUser(), 
                '员工角色'
              ),
              icon: const Icon(Icons.person),
              label: const Text('员工角色 - 陈人事专员'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 管理员角色
            ElevatedButton.icon(
              onPressed: () => _navigateToLogsScreen(
                context, 
                MockData.createMockAdmin(), 
                '管理员角色'
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('管理员角色 - 系统管理员'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 创始人角色
            ElevatedButton.icon(
              onPressed: () => _navigateToLogsScreen(
                context, 
                MockData.createMockFounder(), 
                '创始人角色'
              ),
              icon: const Icon(Icons.business),
              label: const Text('创始人角色 - 张创始人'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 功能说明
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '功能特性：',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• 🔍 智能搜索：支持关键词和日期搜索'),
                  const Text('• 🏷️ 多维度筛选：分类和四象限筛选'),
                  const Text('• 📱 响应式设计：适配不同屏幕尺寸'),
                  const Text('• 🎨 现代化UI：Material Design 3风格'),
                  const Text('• ⚡ 实时交互：即时搜索和筛选'),
                  const Text('• 🔐 权限控制：基于用户角色的数据访问'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导航到日志界面
  void _navigateToLogsScreen(BuildContext context, User user, String roleName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalLogsScreen(userId: user.id),
        settings: RouteSettings(name: '/personal-logs-${user.role}'),
      ),
    ).then((_) {
      // 返回时显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已退出 $roleName 的日志管理界面'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
}
