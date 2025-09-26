import 'package:flutter/material.dart';
import '../models/personal_info.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class PersonalResumeScreen extends StatefulWidget {
  final User user;

  const PersonalResumeScreen({super.key, required this.user});

  @override
  State<PersonalResumeScreen> createState() => _PersonalResumeScreenState();
}

class _PersonalResumeScreenState extends State<PersonalResumeScreen> {
  List<PersonalInfo> _personalInfo = [];
  bool _isLoading = true;
  String? _error;

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
      setState(() {
        _personalInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
    // 按象限分组信息
    final quadrantGroups = <String, List<PersonalInfo>>{};
    for (final info in _personalInfo) {
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
