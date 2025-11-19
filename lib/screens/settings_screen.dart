import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/server_config_service.dart';
import '../services/api_service.dart';

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
          _buildSectionTitle('服务器配置'),
          _buildServerConfig(),
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

  Widget _buildServerConfig() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.settings_ethernet, color: Theme.of(context).primaryColor),
        title: const Text('服务器地址'),
        subtitle: FutureBuilder<Map<String, String>>(
          future: ServerConfigService.getConfigInfo(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final config = snapshot.data!;
              return Text('${config['host']}:${config['port']}\n${config['baseUrl']}');
            }
            return const Text('加载中...');
          },
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showServerConfigDialog(),
      ),
    );
  }

  void _showServerConfigDialog() {
    final hostController = TextEditingController();
    final portController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<Map<String, String>>(
            future: ServerConfigService.getConfigInfo(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final config = snapshot.data!;
                hostController.text = config['host'] ?? '';
                portController.text = config['port'] ?? '';
              }

              return AlertDialog(
                title: const Text('服务器配置'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '配置服务器地址以连接后端服务\n\n'
                      '• 模拟器：使用默认值 10.0.2.2:8080\n'
                      '• 真机：输入电脑的IP地址（如 192.168.1.100）\n'
                      '• 确保手机和电脑在同一WiFi网络',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: hostController,
                      decoration: const InputDecoration(
                        labelText: '服务器IP地址',
                        hintText: '例如: 192.168.1.100 或 10.0.2.2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        hintText: '例如: 8080',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setDialogState(() => isLoading = true);
                            final success = await ServerConfigService.resetToDefault();
                            setDialogState(() => isLoading = false);
                            if (success) {
                              await ApiService.refreshBaseUrl();
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已重置为默认配置')),
                                );
                                setState(() {});
                              }
                            }
                          },
                    child: const Text('重置默认'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final host = hostController.text.trim();
                            final port = portController.text.trim();

                            if (host.isEmpty || port.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请输入服务器地址和端口')),
                              );
                              return;
                            }

                            setDialogState(() => isLoading = true);
                            final hostSuccess = await ServerConfigService.setServerHost(host);
                            final portSuccess = await ServerConfigService.setServerPort(port);

                            if (hostSuccess && portSuccess) {
                              await ApiService.refreshBaseUrl();
                              setDialogState(() => isLoading = false);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('配置已保存，请重启应用')),
                                );
                                setState(() {});
                              }
                            } else {
                              setDialogState(() => isLoading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('保存配置失败')),
                                );
                              }
                            }
                          },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}


