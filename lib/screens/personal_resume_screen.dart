import 'package:flutter/material.dart';
import '../models/personal_info.dart';
import '../services/api_service.dart';
import '../models/user.dart';
// 移除未使用的 Log 导入
import '../widgets/data_panel.dart';
import '../services/mbti_test_service.dart';
import '../models/mbti_test_result.dart';
import '../models/personal_log.dart';

class PersonalResumeScreen extends StatefulWidget {
  final User user;

  const PersonalResumeScreen({super.key, required this.user});

  @override
  State<PersonalResumeScreen> createState() => _PersonalResumeScreenState();
}

class _PersonalResumeScreenState extends State<PersonalResumeScreen> {
  List<PersonalInfo> _personalInfo = [];
  List<PersonalInfo> _autoPersonalInfo = [];
  bool _isLoading = true;
  String? _error;
  MbtiTestResult? _latestMbti;

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
  }

  Future<void> _loadPersonalInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final info = await ApiService.getPersonalInfo(widget.user.id);
      // 并行获取日志并自动提炼Top10个人信息
      final logs = await ApiService.getPersonalLogs(widget.user.id);
      final autoTop = _extractTopPersonalInfoFromLogs(logs, widget.user.id);
      // 获取最新一次MBTI
      final mbti = await MbtiTestService.getUserLatestMbti();
      setState(() {
        _personalInfo = info;
        _autoPersonalInfo = autoTop;
        _latestMbti = mbti;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // 从日志自动生成个人信息Top10（基于action/category/quadrant的代表性与近期性）
  List<PersonalInfo> _extractTopPersonalInfoFromLogs(List<PersonalLog> personalLogs, String userId) {
    // 仅取近90天
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 90));
    final recent = personalLogs.where((pl) {
      final dt = pl.createdAtDate ?? pl.logDate ?? DateTime.now();
      return dt.isAfter(cutoff);
    }).toList();

    // 以(quad, category, title)为key聚合；PersonalLog无quadrant，使用默认 important_not_urgent
    const String defaultQuadrant = 'important_not_urgent';
    final Map<String, List<PersonalLog>> group = {};
    for (final pl in recent) {
      final String quadrant = defaultQuadrant;
      final String category = (pl.category ?? '').toLowerCase();
      final String title = (pl.title ?? '').toLowerCase();
      final key = quadrant + '|' + category + '|' + title;
      group.putIfAbsent(key, () => []).add(pl);
    }

    final entries = group.entries.map((e) {
      final items = e.value;
      items.sort((a, b) {
        final ad = a.createdAtDate ?? a.logDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAtDate ?? b.logDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      final latest = items.first;
      final completedCount = items.where((x) => x.isCompleted).length;
      final latestDate = latest.createdAtDate ?? latest.logDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return {
        'latest': latest,
        'count': items.length,
        'completed': completedCount,
        'latestDate': latestDate,
      };
    }).toList();

    // 排序策略：完成数优先，其次出现频次，其次最近时间
    entries.sort((a, b) {
      final int c = (b['completed'] as int).compareTo(a['completed'] as int);
      if (c != 0) return c;
      final int d = (b['count'] as int).compareTo(a['count'] as int);
      if (d != 0) return d;
      return (b['latestDate'] as DateTime).compareTo(a['latestDate'] as DateTime);
    });

    final top = entries.take(10).map((m) {
      final PersonalLog latest = m['latest'] as PersonalLog;
      final dt = latest.createdAtDate ?? latest.logDate ?? DateTime.now();
      return PersonalInfo(
        id: latest.id,
        userId: userId,
        title: latest.title ?? '个人日志',
        description: latest.content ?? '',
        category: latest.category ?? '',
        quadrant: defaultQuadrant,
        createdAt: dt,
        updatedAt: dt,
        relatedTaskId: null,
        isCompleted: latest.isCompleted,
      );
    }).toList();
    return top;
  }

  String _getQuadrantText(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return '重要且紧急';
      case 'important_not_urgent':
        return '重要不紧急';
      case 'not_important_urgent':
        return '紧急不重要';
      case 'not_important_not_urgent':
        return '不重要不紧急';
      default:
        return quadrant;
    }
  }

  Color _getQuadrantColor(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return Colors.red;
      case 'important_not_urgent':
        return Colors.orange;
      case 'not_important_urgent':
        return Colors.blue;
      case 'not_important_not_urgent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getQuadrantIcon(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return Icons.priority_high;
      case 'important_not_urgent':
        return Icons.schedule;
      case 'not_important_urgent':
        return Icons.flash_on;
      case 'not_important_not_urgent':
        return Icons.check_circle_outline;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人简历'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditDialog();
            },
            tooltip: '编辑个人信息',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPersonalInfo,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
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
              onPressed: _loadPersonalInfo,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // 个人信息头部
          _buildHeader(),
          
          // 四象限信息展示
          _buildQuadrantSections(),

          // 数据面板（今日/近7日）
          _buildDataPanelSection(),

          // MBTI摘要
          _buildMbtiSummarySection(),
          
          // 技能和成就
          _buildSkillsAndAchievements(),
          
          // 工作经历
          _buildWorkExperience(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 头像
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0] : 'U',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 姓名和职位
            Text(
              widget.user.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              widget.user.position,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            
            Text(
              widget.user.department,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            
            // 角色标签
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.user.role.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrantSections() {
    // 合并：优先展示后端返回，其次自动提炼
    final combined = <PersonalInfo>[];
    combined.addAll(_personalInfo);
    // 避免重复（以title+quadrant为键）
    final seen = <String>{ for (final i in _personalInfo) (i.title + '|' + i.quadrant) };
    for (final i in _autoPersonalInfo) {
      final key = i.title + '|' + i.quadrant;
      if (!seen.contains(key)) combined.add(i);
    }
    // 仅取Top10
    final displayList = combined.take(10).toList();
    // 按象限分组
    final quadrantGroups = <String, List<PersonalInfo>>{};
    for (final info in displayList) {
      quadrantGroups.putIfAbsent(info.quadrant, () => []).add(info);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人重要信息',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 四象限网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildQuadrantCard(
                'important_urgent',
                '重要且紧急',
                Colors.red,
                Icons.priority_high,
                quadrantGroups['important_urgent'] ?? [],
              ),
              _buildQuadrantCard(
                'important_not_urgent',
                '重要不紧急',
                Colors.orange,
                Icons.schedule,
                quadrantGroups['important_not_urgent'] ?? [],
              ),
              _buildQuadrantCard(
                'not_important_urgent',
                '紧急不重要',
                Colors.blue,
                Icons.flash_on,
                quadrantGroups['not_important_urgent'] ?? [],
              ),
              _buildQuadrantCard(
                'not_important_not_urgent',
                '不重要不紧急',
                Colors.green,
                Icons.check_circle_outline,
                quadrantGroups['not_important_not_urgent'] ?? [],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantCard(
    String quadrant,
    String title,
    Color color,
    IconData icon,
    List<PersonalInfo> items,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Text(
                '${items.length} 项',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              
              if (items.isNotEmpty) ...[
                Text(
                  items.first.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataPanelSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            '近期数据面板',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DataPanel(userId: widget.user.id),
        ],
      ),
    );
  }

  Widget _buildMbtiSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MBTI 最近一次测试',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _latestMbti == null
                  ? const Text(
                      '暂无MBTI记录，前往「日志/测试」完成一次评测。',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              _latestMbti!.mbtiType,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _latestMbti!.testDate.toIso8601String().split('T').first,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip('优势', Colors.green),
                            _buildChip('劣势', Colors.red),
                            _buildChip('置信度 ${( (_latestMbti!.confidenceScore * 100).toStringAsFixed(0))}%', Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '特征：' + (_latestMbti!.personalityTraits.values.take(2).join('；')),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildSkillsAndAchievements() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '技能与成就',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSkillItem('任务完成率', 85, Colors.green),
                  const SizedBox(height: 12),
                  _buildSkillItem('团队协作', 90, Colors.blue),
                  const SizedBox(height: 12),
                  _buildSkillItem('学习能力', 88, Colors.orange),
                  const SizedBox(height: 12),
                  _buildSkillItem('创新思维', 82, Colors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillItem(String skill, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              skill,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildWorkExperience() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '工作经历',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildExperienceItem(
                    '当前职位',
                    widget.user.position,
                    widget.user.department,
                    '至今',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildExperienceItem(
                    '入职时间',
                    '${widget.user.createdAt.year}年${widget.user.createdAt.month}月',
                    '加入公司',
                    '${DateTime.now().year - widget.user.createdAt.year}年经验',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceItem(
    String title,
    String position,
    String company,
    String duration,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                position,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                company,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑个人信息'),
        content: const Text('个人信息将根据您的日志自动生成，您也可以在日志页面手动添加重要信息'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
