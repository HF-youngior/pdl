import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/log_service.dart';
import '../widgets/log_list_item.dart';

class PersonalLogsScreen extends StatefulWidget {
  final User user;

  const PersonalLogsScreen({
    super.key,
    required this.user,
  });

  @override
  State<PersonalLogsScreen> createState() => _PersonalLogsScreenState();
}

class _PersonalLogsScreenState extends State<PersonalLogsScreen> {
  // --- 模拟数据和状态 ---
  // 实际项目中应从状态管理或认证模块获取
  final String _mockToken = 'MOCK_USER_TOKEN';
  
  // --- 状态变量 ---
  List<Log> _logs = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  // --- 筛选选项 ---
  String _selectedCategory = 'all';
  String _selectedFilter = 'all'; // 状态筛选：all, pending, completed
  
  // 用于 UI 显示的状态筛选名称
  final Map<String, String> _filterOptions = {
    'all': '全部日志',
    'pending': '待处理',
    'completed': '已完成',
  };

  // 分类选项
  final Map<String, String> _categories = {
    'all': '全部分类',
    'work': '工作',
    'learning': '学习',
    'personal': '个人',
    'meeting': '会议',
    'system': '系统',
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- 业务逻辑：获取日志列表 ---
  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 设置认证token（在实际项目中应该从认证模块获取）
      LogService.setAuthToken(_mockToken);
      
      // 检查搜索关键字是否是有效日期，如果是，则可以在后端添加日期筛选逻辑
      // 此处简化，统一使用 search_keyword
      final fetchedLogs = await LogService.fetchLogs(
        searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
        category: _selectedCategory != 'all' ? _selectedCategory : null,
        status: _selectedFilter != 'all' ? _selectedFilter : null,
      );
      
      setState(() {
        _logs = fetchedLogs;
        _isLoading = false;
      });
    } catch (e) {
      // 实际应该显示 PDD 中定义的错误提示 (G-001, G-002)
      print('获取日志失败: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _logs = []; // 清空数据
      });
    }
  }

  // --- 交互逻辑 ---
  void _onSearchChanged() {
    // 延迟搜索，避免输入时频繁触发 API 请求
    // 生产环境中应使用 Debounce 技术
    setState(() {
      _searchKeyword = _searchController.text;
    });
    // 立即调用 fetchLogs，用户输入完毕即可触发
    _fetchLogs(); 
  }
  
  void _openLogCreateDialog() {
    // TODO: 实现添加日志对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('添加日志功能待实现')),
    );
  }

  void _handleLogTap(Log log) {
    // 处理日志条目点击，例如显示日志详情
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看日志详情: ${log.action}')),
    );
  }

  // 分类筛选
  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category ?? 'all';
    });
    _fetchLogs();
  }

  // 状态筛选
  void _onFilterChanged(String? filter) {
    setState(() {
      _selectedFilter = filter ?? 'all';
    });
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人日志'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openLogCreateDialog,
            tooltip: '添加日志',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 搜索栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索关键词或具体日期...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),
          
          // 2. 筛选 (分类和状态)
          _buildFilterSection(),
          
          // 3. 日志列表展示
          Expanded(
            child: _buildLogsList(),
          ),
        ],
      ),
    );
  }

  // 构建筛选区域
  Widget _buildFilterSection() {
    return Column(
      children: [
        // 分类筛选
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: _categories.entries.map((entry) {
              final isSelected = _selectedCategory == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    _onCategoryChanged(selected ? entry.key : 'all');
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 状态筛选
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: _filterOptions.entries.map((entry) {
              final isSelected = _selectedFilter == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    _onFilterChanged(selected ? entry.key : 'all');
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 构建日志列表
  Widget _buildLogsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _logs.isEmpty) {
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
              onPressed: _fetchLogs,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Text(_searchKeyword.isEmpty ? '暂无个人日志，点击 + 创建' : '未找到相关日志'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return LogListItem(
            log: log,
            onTap: () => _handleLogTap(log),
          );
        },
      ),
    );
  }

}