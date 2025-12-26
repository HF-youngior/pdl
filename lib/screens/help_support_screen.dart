import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助与支持'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            context,
            title: '常见问题',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. 登录失败怎么办？'),
                SizedBox(height: 4),
                Text('请检查网络与账号密码，或联系管理员重置密码。', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 12),
                Text('2. 数据不同步？'),
                SizedBox(height: 4),
                Text('请在“我的-今日数据”点击右上角刷新按钮，或重启应用重试。', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          _buildCard(
            context,
            title: '联系支持',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('邮箱：23301083@bjtu.edu.cn'),
                SizedBox(height: 8),
                Text('工单：在项目内部“帮助与支持”发起反馈，我们将在1个工作日内响应。', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required Widget child}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}


