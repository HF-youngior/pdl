import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/personal_log.dart';
import '../services/api_service.dart';

class OverviewScreen extends StatefulWidget {
  final User user;

  const OverviewScreen({super.key, required this.user});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _rolePriority = {
    'admin': 0,
    'founder': 1,
    'department_head': 2,
    'team_leader': 3,
    'employee': 4,
  };

  List<User> _allUsers = [];
  List<User> _displayUsers = [];
  bool _initialUsersLoading = true;
  bool _isSearching = false;

  User? _selectedUser;
  bool _detailLoading = false;

  // 员工数据
  Map<String, dynamic>? _userStatistics;
  String _statisticsPeriod = 'today'; // today, week, all, custom
  DateTime? _customSelectedDate;
  bool _loadingStatistics = false;

  // 日志数据
  List<PersonalLog> _userLogs = [];
  DateTime _selectedLogDate = DateTime.now();
  bool _loadingLogs = false;

  // MBTI数据
  List<Map<String, dynamic>> _mbtiHistory = [];
  bool _loadingMbti = false;

  // 公司任务数据
  List<Task> _companyTasks = [];
  DateTime? _selectedTaskDate;
  bool _loadingTasks = false;

  Task? _selectedTask;
  Map<String, dynamic>? _taskTree;
  bool _loadingTaskTree = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadInitialUsers();
    _loadCompanyTasks();
    ApiService.trackAction('admin_overview_access', category: 'admin_action');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<User> _sortUsers(List<User> users) {
    final sorted = [...users];
    sorted.sort((a, b) {
      final roleA = _rolePriority[a.role] ?? 99;
      final roleB = _rolePriority[b.role] ?? 99;
      if (roleA != roleB) return roleA.compareTo(roleB);
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _initialUsersLoading = true;
    });
    try {
      final users = await ApiService.searchUsers('');
      setState(() {
        _allUsers = _sortUsers(users);
        _displayUsers = _allUsers;
        _initialUsersLoading = false;
      });
    } catch (e) {
      setState(() {
        _initialUsersLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载员工列表失败: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _displayUsers = _allUsers;
      });
      return;
    }
    _searchUsers(keyword);
  }

  Future<void> _searchUsers(String keyword) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ApiService.searchUsers(keyword);
      setState(() {
        _displayUsers = _sortUsers(results);
        _isSearching = false;
      });
      ApiService.trackAction(
        'admin_search_users',
        category: 'admin_action',
        metadata: {'keyword': keyword, 'result_count': results.length},
      );
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  Future<void> _openEmployeeDetail(User user) async {
    setState(() {
      _selectedUser = user;
      _searchController.text = user.name;
      _detailLoading = true;
      _loadingStatistics = true;
      _loadingLogs = true;
      _loadingMbti = true;
    });

    ApiService.trackAction(
      'admin_select_user',
      category: 'admin_action',
      metadata: {'user_id': user.id, 'user_name': user.name},
    );

    await Future.wait([
      _loadUserStatistics(silent: true),
      _loadUserLogs(silent: true),
      _loadMbtiHistory(silent: true),
    ]);

    if (!mounted) return;

    setState(() {
      _detailLoading = false;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: _detailLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEmployeeDetailContent(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadUserStatistics({bool silent = false, bool forceRefresh = false}) async {
    if (_selectedUser == null) return;
    
    print('DEBUG: Starting to load user statistics for userId=${_selectedUser!.id}, period=$_statisticsPeriod, forceRefresh=$forceRefresh');
    
    if (!silent) {
      setState(() {
        _loadingStatistics = true;
      });
    }
    
    try {
      // 如果是强制刷新，先清除当前数据
      if (forceRefresh && _userStatistics != null) {
        setState(() {
          _userStatistics = null;
        });
        
        // 等待一帧，确保UI更新
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      final stats = await ApiService.getUserStatistics(
        _selectedUser!.id,
        _statisticsPeriod,
      );
      print('DEBUG: Received statistics: $stats');
      
      // 强制更新UI
      if (mounted) {
        setState(() {
          _userStatistics = stats;
          print('DEBUG: UI updated with new statistics');
        });
      }
    } catch (e) {
      print('DEBUG: Error loading user statistics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载统计数据失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStatistics = false;
        });
      }
    }
  }

  Future<void> _loadUserLogs({bool silent = false}) async {
    if (_selectedUser == null) return;
    
    if (!silent) {
      setState(() {
        _loadingLogs = true;
      });
    }
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedLogDate);
      final logs = await ApiService.getUserLogs(_selectedUser!.id, date: dateStr);
      setState(() {
        _userLogs = logs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
        });
      }
    }
  }

  Future<void> _loadMbtiHistory({bool silent = false}) async {
    if (_selectedUser == null) return;
    
    if (!silent) {
      setState(() {
        _loadingMbti = true;
      });
    }
    
    try {
      final history = await ApiService.getUserMbtiHistory(_selectedUser!.id);
      setState(() {
        _mbtiHistory = history;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载MBTI历史失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingMbti = false;
        });
      }
    }
  }

  Future<void> _loadCompanyTasks() async {
    setState(() {
      _loadingTasks = true;
    });
    
    try {
      String? dateStr;
      if (_selectedTaskDate != null) {
        dateStr = DateFormat('yyyy-MM-dd').format(_selectedTaskDate!);
      }
      final tasks = await ApiService.getAllCompanyTasks(date: dateStr);
      setState(() {
        _companyTasks = tasks;
        _loadingTasks = false;
      });
      
      // 记录查看任务埋点
      ApiService.trackAction('admin_view_company_tasks', 
        category: 'admin_action',
        metadata: {'date': dateStr, 'task_count': tasks.length});
    } catch (e) {
      setState(() {
        _loadingTasks = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务失败: $e')),
        );
      }
    }
  }

  Future<void> _loadTaskTree(String taskId, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingTaskTree = true;
      });
    }
    
    try {
      final tree = await ApiService.getTaskTree(taskId);
      setState(() {
        _taskTree = tree;
      });
      
      // 记录查看任务树埋点
      ApiService.trackAction('admin_view_task_tree', 
        category: 'admin_action',
        metadata: {'task_id': taskId});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务树失败: $e')),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _loadingTaskTree = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('总览'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '员工搜索', icon: Icon(Icons.search)),
            Tab(text: '公司任务', icon: Icon(Icons.assignment)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserSearchTab(),
          _buildCompanyTasksTab(),
        ],
      ),
    );
  }

  Widget _buildUserSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索员工（姓名、部门、职位）',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _initialUsersLoading
              ? const Center(child: CircularProgressIndicator())
              : _displayUsers.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? '暂无员工数据'
                            : '未找到匹配的员工',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _displayUsers.length,
                      itemBuilder: (context, index) {
                        final user = _displayUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                          ),
                          title: Text(user.name),
                          subtitle: Text('${user.position} · ${user.department}'),
                          trailing: Text(
                            _getRoleDisplay(user.role),
                            style: TextStyle(
                              color: _getRoleColor(user.role),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _openEmployeeDetail(user),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _statisticsPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statisticsPeriod = period;
        });
        _loadUserStatistics(forceRefresh: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectionButton() {
    final isSelected = _statisticsPeriod == 'custom';
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _customSelectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _statisticsPeriod = 'custom';
            _customSelectedDate = picked;
          });
          _loadUserStatistics(forceRefresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _customSelectedDate != null ? 
            '${_customSelectedDate!.month}/${_customSelectedDate!.day}' : 
            '选定日期',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _navigateToTaskList(String taskType) {
    if (_selectedUser == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserTaskListScreen(
          userId: _selectedUser!.id,
          userName: _selectedUser!.name,
          taskType: taskType,
          period: _statisticsPeriod,
          customDate: _customSelectedDate,
        ),
      ),
    );
  }

  Widget _buildCompanyTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedTaskDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedTaskDate!)
                        : '选择日期（可选）',
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedTaskDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedTaskDate = date;
                      });
                      _loadCompanyTasks();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedTaskDate = null;
                  });
                  _loadCompanyTasks();
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : _companyTasks.isEmpty
                  ? const Center(child: Text('暂无任务'))
                  : ListView.builder(
                      itemCount: _companyTasks.length,
                      itemBuilder: (context, index) {
                        final task = _companyTasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text(task.title),
                            subtitle: Text(
                              '${task.assigneeName} · ${task.department}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  task.getStatusText(),
                                  style: TextStyle(
                                    color: task.getStatusColor(),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task.getPriorityLabel(),
                                  style: TextStyle(
                                    color: task.getPriorityColor(),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _openTaskDetail(task),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTaskTreeNode(Map<String, dynamic> node) {
    final hasSubtasks =
        node['subtasks'] != null && (node['subtasks'] as List).isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(node['status']),
          child: const Icon(Icons.task, color: Colors.white, size: 20),
        ),
        title: Text(node['title'] ?? '无标题'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('负责人: ${node['assignee_name'] ?? 'N/A'}'),
            Text('部门: ${node['department_name'] ?? 'N/A'}'),
            Text('状态: ${_getStatusText(node['status'])}'),
          ],
        ),
        children: hasSubtasks
            ? (node['subtasks'] as List)
                .map<Widget>(
                  (subtask) => Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _buildTaskTreeNode(subtask),
                  ),
                )
                .toList()
            : [],
      ),
    );
  }

  Widget _buildEmployeeDetailContent() {
    if (_selectedUser == null) {
      return const Center(child: Text('请选择员工'));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1,
      minChildSize: 0.8,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    child: Text(_selectedUser!.name.isNotEmpty ? _selectedUser!.name[0] : '?'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedUser!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('${_selectedUser!.position} · ${_selectedUser!.department}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '任务完成情况',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  print('DEBUG: Refresh button pressed');
                                  // 强制刷新统计数据
                                  _loadUserStatistics(forceRefresh: true);
                                },
                                icon: const Icon(Icons.refresh),
                                tooltip: '刷新数据',
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 120,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _statisticsPeriod,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'today', child: Text('今日')),
                                        DropdownMenuItem(value: 'week', child: Text('近七天')),
                                        DropdownMenuItem(value: 'all', child: Text('全部')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          print('DEBUG: Dropdown changed to $value');
                                          setState(() {
                                            _statisticsPeriod = value;
                                            print('DEBUG: State updated, _statisticsPeriod=$_statisticsPeriod');
                                          });
                                          
                                          // 使用Future.microtask确保setState完成后再调用_loadUserStatistics
                                          Future.microtask(() {
                                            _loadUserStatistics(forceRefresh: true);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _loadingStatistics
                          ? const Center(child: CircularProgressIndicator())
                          : _buildStatisticsContent(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '日志查看',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildLogCalendar(),
                      const SizedBox(height: 16),
                      _buildLogList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MBTI测试结果变化',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _loadingMbti
                          ? const Center(child: CircularProgressIndicator())
                          : _buildMbtiTimeline(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsContent() {
    final stats = _userStatistics ?? {};
    print('DEBUG: Building statistics content with data: $stats');
    print('DEBUG: totalTasks: ${stats['totalTasks']}, inProgressTasks: ${stats['inProgressTasks']}, completedTasks: ${stats['completedTasks']}, completionRate: ${stats['completionRate']}');
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '总任务数',
                _formatInt(stats['totalTasks']),
                Icons.assignment,
                Colors.blue,
                onTap: () => _navigateToTaskList('all'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '进行中',
                _formatInt(stats['inProgressTasks']),
                Icons.hourglass_empty,
                Colors.orange,
                onTap: () => _navigateToTaskList('in_progress'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '已完成',
                _formatInt(stats['completedTasks']),
                Icons.check_circle,
                Colors.green,
                onTap: () => _navigateToTaskList('completed'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '完成率',
                '${_formatPercentage(stats['completionRate'])}',
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, color: color, size: 12),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCalendar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _selectedLogDate = _selectedLogDate.subtract(const Duration(days: 1));
                });
                _loadUserLogs();
              },
            ),
            Text(
              DateFormat('yyyy年MM月dd日').format(_selectedLogDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _selectedLogDate = _selectedLogDate.add(const Duration(days: 1));
                });
                _loadUserLogs();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: const Text('选择日期'),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedLogDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _selectedLogDate = date;
              });
              _loadUserLogs();
            }
          },
        ),
      ],
    );
  }

  Widget _buildLogList() {
    if (_loadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userLogs.isEmpty) {
      return const Center(child: Text('该日期暂无日志'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userLogs.length,
      itemBuilder: (context, index) {
        final log = _userLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(log.title ?? '无标题'),
            subtitle: Text(log.content ?? ''),
            trailing: Text(
              log.category ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMbtiTimeline() {
    if (_mbtiHistory.isEmpty) {
      return const Center(child: Text('暂无MBTI测试记录'));
    }

    final sorted = [..._mbtiHistory];
    sorted.sort((a, b) {
      final dateA = _parseDate(a['test_date']);
      final dateB = _parseDate(b['test_date']);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    if (sorted.length == 1) {
      return _buildMbtiCard(sorted.first);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(sorted.length, (index) {
          final record = sorted[index];
          return Row(
            children: [
              _buildTimelineNode(record),
              if (index < sorted.length - 1)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  width: 40,
                  height: 2,
                  color: Colors.indigo.shade200,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTimelineNode(Map<String, dynamic> record) {
    final date = _parseDate(record['test_date']);
    final dateLabel =
        date != null ? DateFormat('yyyy-MM-dd').format(date) : '未知日期';
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Container(
          width: 140,
          margin: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        _buildMbtiCard(record),
      ],
    );
  }

  Widget _buildMbtiCard(Map<String, dynamic> record) {
    final confidence = _parseDouble(record['confidence_score']);
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record['mbti_type'] ?? 'N/A',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '置信度: ${confidence.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _openTaskDetail(Task task) async {
    setState(() {
      _selectedTask = task;
      _taskTree = null;
      _loadingTaskTree = true;
    });

    await _loadTaskTree(task.id, silent: true);

    if (!mounted) return;

    setState(() {
      _loadingTaskTree = false;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: _buildTaskDetailContent(task),
          ),
        );
      },
    );
  }

  Widget _buildTaskDetailContent(Task task) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1,
      minChildSize: 0.8,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(task.description),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('负责人: ${task.assigneeName}'),
                      Text('部门: ${task.department}'),
                      Text('状态: ${task.getStatusText()}'),
                      Text('优先级: ${task.getPriorityLabel()}'),
                      Text('开始时间: ${_formatDateTime(task.startTime)}'),
                      Text('结束时间: ${_formatDateTime(task.endTime)}'),
                      if (task.deadline != null)
                        Text('截止时间: ${_formatDateTime(task.deadline!)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingTaskTree)
                const Center(child: CircularProgressIndicator())
              else if (_taskTree == null)
                const Text('暂无任务树数据')
              else
                _buildTaskTreeNode(_taskTree!),
            ],
          ),
        );
      },
    );
  }

  String _formatInt(dynamic value) {
    if (value is int) return value.toString();
    if (value is double) return value.toInt().toString();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed.toString();
      final parsedDouble = double.tryParse(value);
      if (parsedDouble != null) return parsedDouble.toInt().toString();
      return value;
    }
    return '0';
  }

  String _formatPercentage(dynamic value) {
    final number = _parseDouble(value);
    return '${number.toStringAsFixed(1)}%';
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'founder':
        return '创始人';
      case 'department_head':
        return '部门总监';
      case 'team_leader':
        return '团队长';
      case 'employee':
        return '员工';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'founder':
        return Colors.purple;
      case 'department_head':
        return Colors.blue;
      case 'team_leader':
        return Colors.green;
      case 'employee':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.grey;
      case 'cancelled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String? status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'in_progress':
        return '进行中';
      case 'pending':
        return '待处理';
      case 'cancelled':
        return '已完成';
      default:
        return status ?? '未知';
    }
  }
}

// 用户任务列表页面
class UserTaskListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String taskType; // all, completed, in_progress
  final String period; // today, week, all, custom
  final DateTime? customDate;

  const UserTaskListScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.taskType,
    required this.period,
    this.customDate,
  });

  @override
  State<UserTaskListScreen> createState() => _UserTaskListScreenState();
}

class _UserTaskListScreenState extends State<UserTaskListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  String _sortOption = 'date'; // date, priority, status

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        return task.title.toLowerCase().contains(query) ||
               (task.description?.toLowerCase().contains(query) ?? false) ||
               (task.status?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Task> tasks;
      
      // 根据时间范围获取任务
      switch (widget.period) {
        case 'today':
          tasks = await _getTodayTasks();
          break;
        case 'week':
          tasks = await _getWeekTasks();
          break;
        case 'custom':
          tasks = await _getCustomDateTasks(widget.customDate!);
          break;
        case 'all':
        default:
          tasks = await _getAllTasks();
          break;
      }

      // 根据任务类型过滤
      if (widget.taskType != 'all') {
        tasks = tasks.where((task) => task.status == widget.taskType).toList();
      }

      setState(() {
        _allTasks = tasks;
        _filteredTasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务失败: $e')),
        );
      }
    }
  }

  Future<List<Task>> _getAllTasks() async {
    // 获取用户的所有任务
    final allTasks = await ApiService.getTasks();
    return allTasks.where((task) => task.assigneeId == widget.userId).toList();
  }

  Future<List<Task>> _getTodayTasks() async {
    final allTasks = await _getAllTasks();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return allTasks.where((task) {
      if (task.createdAt == null) return false;
      final createdAt = task.createdAt;
      return createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd);
    }).toList();
  }

  Future<List<Task>> _getWeekTasks() async {
    final allTasks = await _getAllTasks();
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    
    return allTasks.where((task) {
      if (task.createdAt == null) return false;
      final createdAt = task.createdAt;
      return createdAt.isAfter(weekStart);
    }).toList();
  }

  Future<List<Task>> _getCustomDateTasks(DateTime date) async {
    final allTasks = await _getAllTasks();
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    
    return allTasks.where((task) {
      if (task.createdAt == null) return false;
      final createdAt = task.createdAt;
      return createdAt.isAfter(dateStart) && createdAt.isBefore(dateEnd);
    }).toList();
  }

  void _sortTasks(String option) {
    setState(() {
      _sortOption = option;
      
      switch (option) {
        case 'date':
          _filteredTasks.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt.compareTo(a.createdAt);
          });
          break;
        case 'priority':
          _filteredTasks.sort((a, b) {
            final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
            final aPriority = priorityOrder[a.priority] ?? 3;
            final bPriority = priorityOrder[b.priority] ?? 3;
            return aPriority.compareTo(bPriority);
          });
          break;
        case 'status':
          _filteredTasks.sort((a, b) {
            final statusOrder = {'pending': 0, 'in_progress': 1, 'completed': 2, 'cancelled': 3};
            final aStatus = statusOrder[a.status] ?? 4;
            final bStatus = statusOrder[b.status] ?? 4;
            return aStatus.compareTo(bStatus);
          });
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}的任务'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索任务...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _sortTasks,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date',
                child: Text('按日期排序'),
              ),
              const PopupMenuItem(
                value: 'priority',
                child: Text('按优先级排序'),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Text('按状态排序'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTasks.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isNotEmpty
                        ? '没有找到匹配的任务'
                        : '暂无任务',
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = _filteredTasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskDetailScreen(task: task),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// 任务卡片组件
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = {
      'high': Colors.red,
      'medium': Colors.orange,
      'low': Colors.green,
    }[task.priority] ?? Colors.grey;

    final statusColor = {
      'pending': Colors.grey,
      'in_progress': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.red,
    }[task.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priorityColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatPriority(task.priority),
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.description != null && task.description!.isNotEmpty)
                Text(
                  task.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatStatus(task.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (task.createdAt != null)
                    Text(
                      _formatDateTime(task.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPriority(String? priority) {
    switch (priority) {
      case 'high':
        return '高优先级';
      case 'medium':
        return '中优先级';
      case 'low':
        return '低优先级';
      default:
        return priority ?? '未设置';
    }
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'in_progress':
        return '进行中';
      case 'pending':
        return '待处理';
      case 'cancelled':
        return '已取消';
      default:
        return status ?? '未知';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
}

// 任务详情页面
class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final priorityColor = {
      'high': Colors.red,
      'medium': Colors.orange,
      'low': Colors.green,
    }[task.priority] ?? Colors.grey;

    final statusColor = {
      'pending': Colors.grey,
      'in_progress': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.red,
    }[task.status] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _formatPriority(task.priority),
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _formatStatus(task.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const Text(
                '任务描述',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
            ],
            _buildDetailRow('创建时间', task.createdAt != null 
                ? DateFormat('yyyy-MM-dd HH:mm').format(task.createdAt)
                : '未知'),
            _buildDetailRow('截止时间', task.deadline != null 
                ? DateFormat('yyyy-MM-dd').format(task.deadline!)
                : '未设置'),
            _buildDetailRow('创建者', task.assigneeName ?? '未知'),
            _buildDetailRow('负责人', task.assigneeName),
            // 更新时间字段不存在于Task模型中，暂时注释掉
            // if (task.updatedAt != null)
            //   _buildDetailRow('更新时间', 
            //       DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(task.updatedAt!))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriority(String? priority) {
    switch (priority) {
      case 'high':
        return '高优先级';
      case 'medium':
        return '中优先级';
      case 'low':
        return '低优先级';
      default:
        return priority ?? '未设置';
    }
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'in_progress':
        return '进行中';
      case 'pending':
        return '待处理';
      case 'cancelled':
        return '已取消';
      default:
        return status ?? '未知';
    }
  }
}

