import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('通用'),
          _buildSwitch(
            icon: Icons.notifications_active,
            title: '开启通知',
            value: _settings.notificationsEnabled,
            onChanged: (v) => setState(() => _settings.setNotificationsEnabled(v)),
          ),
          _buildSwitch(
            icon: Icons.dark_mode,
            title: '深色模式',
            value: _settings.darkMode,
            onChanged: (v) => setState(() => _settings.setDarkMode(v)),
          ),
          _buildLanguage(),
          const SizedBox(height: 16),
          _buildSectionTitle('数据与隐私'),
          _buildNav(
            icon: Icons.security,
            title: '隐私政策',
            subtitle: '查看与管理个人数据使用说明',
            onTap: () {},
          ),
          _buildNav(
            icon: Icons.backup,
            title: '数据备份与恢复',
            subtitle: '即将推出',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  Widget _buildLanguage() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.language, color: Theme.of(context).primaryColor),
        title: const Text('语言'),
        subtitle: Text(_settings.language == 'zh' ? '简体中文' : 'English'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('简体中文'),
                  onTap: () {
                    setState(() => _settings.setLanguage('zh'));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('English'),
                  onTap: () {
                    setState(() => _settings.setLanguage('en'));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNav({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}


