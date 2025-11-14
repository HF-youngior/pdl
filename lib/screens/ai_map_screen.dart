import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/mbti_test_service.dart';
import '../models/wordcloud_analysis.dart';
import '../models/personality_analysis.dart';
import '../models/personal_log.dart';
import '../models/mbti_test_result.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../widgets/enhanced_wordcloud.dart';
import '../widgets/personality_chart.dart';
import '../utils/time_utils.dart';
import 'mbti_test_screen.dart';
import 'log_enhanced_screen.dart';
import 'package:intl/intl.dart';

class AiMapScreen extends StatefulWidget {
  final User user;
  
  const AiMapScreen({super.key, required this.user});

  @override
  State<AiMapScreen> createState() => _AiMapScreenState();
}

class _AiMapScreenState extends State<AiMapScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _wordFreq = [];
  
  // 新增状态
  List<WordCloudAnalysis> _wordCloudHistory = [];
  List<PersonalityAnalysis> _personalityHistory = [];
  PersonalityAnalysis? _currentPersonalityAnalysis;
  late TabController _tabController;
  
  // 词云分析结果相关状态
  Map<String, dynamic>? _wordCloudAnalysis;
  bool _isDeepSeekAnalysis = false;
  String _selectedRange = 'today'; // 'today', 'last7days', 'all'
  DateTime _selectedLogDate = DateTime.now();
  
  // MBTI记录相关状态
  List<Map<String, dynamic>> _mbtiRecords = [];
  bool _loadingMbtiRecords = false;
  Map<String, dynamic>? _selectedMbtiRecord;
  String _searchQuery = '';
  String _selectedMbtiType = '全部';
  Map<String, int> _mbtiTypeCounts = {}; // 每个MBTI类型的记录数量
  // 所有16种MBTI类型
  static const List<String> _allMbtiTypes = [
    '全部',
    'ENFP', 'INTJ', 'ISFJ', 'ISTJ', 'ENFJ', 'INFP', 'ENTJ', 'INTP',
    'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP', 'ENTP', 'INFJ'
  ];
  
  // 今日日志相关状态
  List<PersonalLog> _todayLogs = [];
  bool _loadingTodayLogs = false;
  
  // MBTI测试相关状态
  MbtiTestResult? _latestMbtiResult;
  bool _loadingMbtiResult = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadHistory();
    _loadTodayLogs();
    _loadMbtiRecords();
    _loadLatestMbtiResult();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _loadHistory() async {
    try {
      // 分别加载词云历史和性格分析历史，避免一个失败影响另一个
      try {
        final wordCloudHistory = await AiService.getWordCloudHistory();
        if (mounted) {
          setState(() {
            _wordCloudHistory = wordCloudHistory;
          });
        }
      } catch (e) {
        // 词云历史加载失败，不影响其他功能
        print('加载词云历史失败（不影响使用）: $e');
        if (mounted) {
          setState(() {
            _wordCloudHistory = [];
          });
        }
      }
      
      try {
        final personalityHistory = await AiService.getPersonalityHistory();
        if (mounted) {
          setState(() {
            _personalityHistory = personalityHistory;
          });
        }
      } catch (e) {
        // 性格分析历史加载失败，不影响其他功能
        print('加载性格分析历史失败（不影响使用）: $e');
        if (mounted) {
          setState(() {
            _personalityHistory = [];
          });
        }
      }
      
      // 如果两个都失败，使用测试数据
      if (_wordCloudHistory.isEmpty && _personalityHistory.isEmpty) {
        _loadTestData();
      }
    } catch (e) {
      // 如果API完全不可用，使用测试数据
      print('历史记录加载失败，使用测试数据: $e');
      _loadTestData();
    }
  }
  
  Future<void> _loadTodayLogs({DateTime? targetDate}) async {
    final selectedDate = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day)
        : DateTime.now();
    setState(() {
      _loadingTodayLogs = true;
    });
    
    try {
      final allLogs = await ApiService.getPersonalLogs(widget.user.id);
      
      // 优先使用log_date字段，如果为空则使用created_at
      final filteredLogs = allLogs.where((log) {
        DateTime? logDate = log.logDate;
        if (logDate == null) {
          logDate = log.createdAtDate;
        }
        if (logDate == null) return false;
        return logDate.year == selectedDate.year &&
               logDate.month == selectedDate.month &&
               logDate.day == selectedDate.day;
      }).toList();
      
      setState(() {
        _todayLogs = filteredLogs;
        _selectedLogDate = selectedDate;
        _loadingTodayLogs = false;
      });
    } catch (e) {
      setState(() {
        _loadingTodayLogs = false;
      });
      print('加载指定日期日志失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载日志失败: $e')),
      );
    }
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  Future<void> _pickLogDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
      helpText: '选择要分析的日期',
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      if (_selectedRange != 'today') {
        setState(() {
          _selectedRange = 'today';
        });
      }
      await _loadTodayLogs(targetDate: picked);
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 加载最新的MBTI测试结果
  Future<void> _loadLatestMbtiResult() async {
    setState(() {
      _loadingMbtiResult = true;
    });
    
    try {
      final result = await MbtiTestService.getUserLatestMbti();
      setState(() {
        _latestMbtiResult = result;
        _loadingMbtiResult = false;
      });
      
      // 调试信息：打印加载的MBTI结果
      if (result != null) {
        print('加载到MBTI结果: ${result.mbtiType}');
        print('测试日期: ${result.testDate}');
      } else {
        print('未找到MBTI测试结果');
      }
    } catch (e) {
      setState(() {
        _loadingMbtiResult = false;
      });
      print('加载MBTI测试结果失败: $e');
    }
  }

  // 加载MBTI记录
  Future<void> _loadMbtiRecords() async {
    setState(() { _loadingMbtiRecords = true; });
    try {
      // 先获取所有记录以计算统计信息
      final allRecordsResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records'),
        headers: ApiService.getAuthHeaders(),
      );
      
      if (allRecordsResponse.statusCode == 200) {
        final allData = jsonDecode(allRecordsResponse.body);
        List<Map<String, dynamic>> allRecords = List<Map<String, dynamic>>.from(allData['records'] ?? []);
        
        // 应用类型筛选
        List<Map<String, dynamic>> filteredRecords = allRecords;
        if (_selectedMbtiType != '全部') {
          filteredRecords = allRecords.where((record) {
            return record['mbti_type']?.toString() == _selectedMbtiType;
          }).toList();
        }
        
        // 应用搜索过滤
        if (_searchQuery.isNotEmpty) {
          filteredRecords = filteredRecords.where((record) {
            return record['mbti_type'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   record['test_date'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }
        
        // 去重：基于测试日期和MBTI类型去重，保留最新的记录
        // 使用 "日期_MBTI类型" 作为唯一键
        Map<String, Map<String, dynamic>> uniqueRecords = {};
        for (var record in filteredRecords) {
          final mbtiType = record['mbti_type']?.toString() ?? '';
          final testDate = record['test_date']?.toString() ?? '';
          
          if (mbtiType.isEmpty || testDate.isEmpty) continue;
          
          try {
            // 解析日期，只取日期部分（忽略时间）
            final dateTime = DateTime.parse(testDate);
            final dateKey = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}_$mbtiType';
            
            if (!uniqueRecords.containsKey(dateKey)) {
              uniqueRecords[dateKey] = record;
            } else {
              // 如果同一天有多个相同类型的记录，比较创建时间，保留最新的
              final existingRecord = uniqueRecords[dateKey]!;
              final existingCreatedAt = existingRecord['created_at']?.toString();
              final currentCreatedAt = record['created_at']?.toString();
              
              if (currentCreatedAt != null && existingCreatedAt != null) {
                try {
                  final existing = DateTime.parse(existingCreatedAt);
                  final current = DateTime.parse(currentCreatedAt);
                  if (current.isAfter(existing)) {
                    uniqueRecords[dateKey] = record;
                  }
                } catch (e) {
                  // 如果解析失败，比较test_date
                  final existingTestDate = DateTime.parse(existingRecord['test_date']?.toString() ?? '');
                  final currentTestDate = DateTime.parse(testDate);
                  if (currentTestDate.isAfter(existingTestDate)) {
                    uniqueRecords[dateKey] = record;
                  }
                }
              }
            }
          } catch (e) {
            // 如果日期解析失败，使用ID作为备用去重键
            final id = record['id']?.toString();
            if (id != null && !uniqueRecords.containsKey(id)) {
              uniqueRecords[id] = record;
            }
          }
        }
        
        // 按测试日期降序排序
        List<Map<String, dynamic>> sortedRecords = uniqueRecords.values.toList();
        sortedRecords.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['test_date']?.toString() ?? '');
            final dateB = DateTime.parse(b['test_date']?.toString() ?? '');
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
        
        // 基于去重后的记录计算每个MBTI类型的数量
        Map<String, int> counts = {};
        for (var record in sortedRecords) {
          final type = record['mbti_type']?.toString() ?? '未知';
          counts[type] = (counts[type] ?? 0) + 1;
        }
        
        setState(() { 
          _mbtiRecords = sortedRecords;
          _mbtiTypeCounts = counts;
        });
      } else {
        print('加载MBTI记录失败: ${allRecordsResponse.statusCode}');
      }
    } catch (e) {
      print('加载MBTI记录失败: $e');
    } finally {
      setState(() { _loadingMbtiRecords = false; });
    }
  }

  // 获取MBTI记录详情
  Future<void> _getMbtiRecordDetail(String recordId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records/$recordId'),
        headers: ApiService.getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _selectedMbtiRecord = data; });
        _showMbtiRecordDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取详情失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取详情失败: $e')),
      );
    }
  }

  // 显示MBTI记录详情
  void _showMbtiRecordDetail() {
    if (_selectedMbtiRecord == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('MBTI记录详情 - ${_selectedMbtiRecord!['mbti_type']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('基本信息', [
                'MBTI类型: ${_selectedMbtiRecord!['mbti_type']}',
                '测试日期: ${_formatTestDate(_selectedMbtiRecord!['test_date'])}',
                '置信度: ${_formatConfidenceScore(_selectedMbtiRecord!['confidence_score'])}%',
              ]),
              _buildDetailSection('测试分数', _formatTestScores(_selectedMbtiRecord!['test_scores'])),
              _buildDetailSection('性格特质', _formatPersonalityTraits(_selectedMbtiRecord!['personality_traits'])),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '详细的AI分析报告已迁移至“性格分析历史”板块，可结合日志与MBTI查看完整内容。',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Text('• $item'),
          )),
        ],
      ),
    );
  }

  List<String> _formatTestScores(Map<String, dynamic> scores) {
    return scores.entries.map((e) => '${e.key}: ${e.value}').toList();
  }

  List<String> _formatPersonalityTraits(Map<String, dynamic> traits) {
    return traits.entries.map((e) => '${e.key}: ${e.value}').toList();
  }

  // 构建工作建议Widget（支持新的详细结构）
  List<Widget> _buildWorkSuggestionsWidget(Map<String, dynamic> suggestions) {
    final widgets = <Widget>[];
    
    // 日志分析摘要
    if (suggestions.containsKey('日志分析摘要')) {
      widgets.add(_buildSuggestionSection(
        '📊 日志分析摘要',
        suggestions['日志分析摘要'].toString(),
        icon: Icons.analytics_outlined,
      ));
    }
    
    // 当前工作适配度
    if (suggestions.containsKey('当前工作适配度')) {
      final score = suggestions['当前工作适配度'];
      final scoreValue = score is num 
          ? score.toDouble() 
          : (double.tryParse(score.toString()) ?? 0.0);
      widgets.add(_buildSuggestionSection(
        '🎯 当前工作适配度',
        '${(scoreValue * 100).toStringAsFixed(0)}%',
        subtitle: _getAdaptabilityDescription(scoreValue),
        icon: Icons.gps_fixed,
      ));
    }
    
    // 适合职业（新格式：对象数组）
    if (suggestions.containsKey('适合职业')) {
      final careers = suggestions['适合职业'];
      if (careers is List) {
        widgets.add(_buildSuggestionSection(
          '💼 适合职业',
          null,
          icon: Icons.work_outline,
          children: careers.map((career) {
            if (career is Map) {
              return _buildCareerCard(career);
            } else {
              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                    Expanded(child: Text(career.toString(), style: const TextStyle(color: Color(0xFF6B7280)))),
                  ],
                ),
              );
            }
          }).toList(),
        ));
      } else if (careers is List<String>) {
        // 兼容旧格式
        widgets.add(_buildSuggestionSection(
          '💼 适合职业',
          null,
          icon: Icons.work_outline,
          children: careers.map((career) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                Expanded(child: Text(career, style: const TextStyle(color: Color(0xFF6B7280)))),
              ],
            ),
          )).toList(),
        ));
      }
    }
    
    // 职业发展路径
    if (suggestions.containsKey('职业发展路径')) {
      final path = suggestions['职业发展路径'];
      if (path is Map) {
        widgets.add(_buildSuggestionSection(
          '🚀 职业发展路径',
          null,
          icon: Icons.trending_up,
          children: [
            if (path.containsKey('短期目标'))
              _buildPathItem('短期目标（1-2年）', path['短期目标'].toString()),
            if (path.containsKey('长期目标'))
              _buildPathItem('长期目标（3-5年）', path['长期目标'].toString()),
          ],
        ));
      }
    }
    
    // 能力提升建议
    if (suggestions.containsKey('能力提升建议')) {
      final skills = suggestions['能力提升建议'];
      if (skills is List) {
        widgets.add(_buildSuggestionSection(
          '📈 能力提升建议',
          null,
          icon: Icons.school_outlined,
          children: skills.map((skill) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                Expanded(child: Text(skill.toString(), style: const TextStyle(color: Color(0xFF6B7280)))),
              ],
            ),
          )).toList(),
        ));
      }
    }
    
    // 工作环境建议
    if (suggestions.containsKey('工作环境建议')) {
      final env = suggestions['工作环境建议'];
      if (env is Map) {
        widgets.add(_buildSuggestionSection(
          '🏢 工作环境建议',
          null,
          icon: Icons.business_outlined,
          children: [
            if (env.containsKey('理想工作环境'))
              _buildEnvItem('理想工作环境', env['理想工作环境'].toString()),
            if (env.containsKey('团队文化'))
              _buildEnvItem('团队文化', env['团队文化'].toString()),
            if (env.containsKey('工作方式'))
              _buildEnvItem('工作方式', env['工作方式'].toString()),
          ],
        ));
      }
    }
    
    // 发展建议
    if (suggestions.containsKey('发展建议')) {
      widgets.add(_buildSuggestionSection(
        '💡 综合发展建议',
        suggestions['发展建议'].toString(),
        icon: Icons.lightbulb_outline,
      ));
    }
    
    // 兼容旧格式：遍历其他所有字段
    suggestions.forEach((key, value) {
      if (!['日志分析摘要', '当前工作适配度', '适合职业', '职业发展路径', 
            '能力提升建议', '工作环境建议', '发展建议'].contains(key)) {
        widgets.add(_buildSuggestionSection(
          key,
          value is List ? null : value.toString(),
          children: value is List ? (value as List).map((item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                Expanded(child: Text(item.toString(), style: const TextStyle(color: Color(0xFF6B7280)))),
              ],
            ),
          )).toList() : null,
        ));
      }
    });
    
    return widgets;
  }
  
  Widget _buildSuggestionSection(String title, String? content, {IconData? icon, String? subtitle, List<Widget>? children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (content != null)
            Text(
              content,
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.6),
            ),
          if (children != null) ...children,
        ],
      ),
    );
  }
  
  Widget _buildCareerCard(Map<dynamic, dynamic> career) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            career['职业名称']?.toString() ?? '未知职业',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              fontSize: 15,
            ),
          ),
          if (career.containsKey('匹配原因')) ...[
            const SizedBox(height: 6),
            Text(
              '匹配原因：${career['匹配原因']}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
          if (career.containsKey('发展前景')) ...[
            const SizedBox(height: 4),
            Text(
              '发展前景：${career['发展前景']}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPathItem(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEnvItem(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + '：',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }
  
  String _getAdaptabilityDescription(double score) {
    if (score >= 0.8) return '高度匹配，当前工作非常适合你的性格特点';
    if (score >= 0.6) return '较为匹配，工作内容与性格特点基本契合';
    if (score >= 0.4) return '中等匹配，部分工作内容与性格特点相符';
    return '匹配度较低，建议考虑调整工作内容或方向';
  }

  List<String> _formatWorkSuggestions(Map<String, dynamic> suggestions) {
    List<String> items = [];
    if (suggestions['work_environment'] != null) {
      items.add('工作环境: ${suggestions['work_environment']}');
    }
    if (suggestions['team_role'] != null) {
      items.add('团队角色: ${suggestions['team_role']}');
    }
    if (suggestions['leadership_style'] != null) {
      items.add('领导风格: ${suggestions['leadership_style']}');
    }
    return items;
  }
  
  void _loadTestData() {
    setState(() {
      _wordCloudHistory = _generateTestWordCloudData();
      _personalityHistory = _generateTestPersonalityData();
    });
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; });
    try {
      final result = await AiService.analyzeLog(text);
      setState(() {
        _keywords = result.keywords;
        _wordFreq = result.wordFrequencies;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败: $e')),
      );
    } finally {
      setState(() { _loading = false; });
    }
  }
  
  Future<void> _analyzeAndSave({DateTime? targetDate}) async {
    setState(() { _loading = true; });
    try {
      DateTime? normalizedTargetDate;
      if (targetDate != null) {
        normalizedTargetDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        await _loadTodayLogs(targetDate: normalizedTargetDate);
      } else if (_selectedRange == 'today') {
        await _loadTodayLogs(targetDate: _selectedLogDate);
      }
      
      // 调用后端API分析日志（根据选择的日期范围）
      final result = await AiService.analyzeToday(
        topK: 30,
        range: normalizedTargetDate != null ? 'today' : _selectedRange,
        date: normalizedTargetDate,
      );
      
      if (result.wordFrequencies.isEmpty) {
        setState(() {
          _keywords = [];
          _wordFreq = [];
        });
        final emptyLabel = normalizedTargetDate != null
            ? '${_formatDisplayDate(normalizedTargetDate)}没有可分析的日志'
            : '今日没有可分析的日志，请先记录一些日志';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emptyLabel)),
        );
        return;
      }
      
      setState(() {
        _keywords = result.keywords;
        _wordFreq = result.wordFrequencies;
        _wordCloudAnalysis = result.analysis;
        _isDeepSeekAnalysis = result.isDeepSeek ?? false;
      });
      
      // 保存分析结果到历史记录
      try {
        final description = (() {
          if (normalizedTargetDate != null) {
            final label = _formatDisplayDate(normalizedTargetDate);
            return _isDeepSeekAnalysis
                ? 'DeepSeek AI智能分析 - $label 日志'
                : '$label 日志分析';
          }
          final rangeText = _selectedRange == 'today'
              ? '今日'
              : (_selectedRange == 'last7days' ? '7日内' : '全部历史');
          return _isDeepSeekAnalysis 
              ? 'DeepSeek AI智能分析 - $rangeText日志'
              : '$rangeText日志分析';
        })();
        final savedAnalysis = await AiService.saveWordCloudAnalysis(
          analysisDate: DateTime.now(),
          keywords: result.keywords,
          wordFrequencies: result.wordFrequencies,
          description: description,
        );
        
        setState(() {
          _wordCloudHistory.insert(0, savedAnalysis);
        });
        
        final message = normalizedTargetDate != null
            ? (_isDeepSeekAnalysis
                ? '✨ 已完成${_formatDisplayDate(normalizedTargetDate)}日志的DeepSeek分析'
                : '已完成${_formatDisplayDate(normalizedTargetDate)}日志分析')
            : (_isDeepSeekAnalysis
                ? '✨ DeepSeek AI智能分析完成并已保存到历史记录'
                : '今日日志分析完成并已保存到历史记录');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _isDeepSeekAnalysis ? const Color(0xFF8B5CF6) : null,
          ),
        );
      } catch (saveError) {
        // 保存失败不影响分析结果的显示
        print('保存分析结果失败: $saveError');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析完成，但保存失败: $saveError')),
        );
      }
    } catch (e) {
      print('分析今日日志失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败: $e')),
      );
      // 清空之前的结果
      setState(() {
        _keywords = [];
        _wordFreq = [];
      });
    } finally {
      setState(() { _loading = false; });
    }
  }
    
  Future<void> _analyzePersonality() async {
    // 检查是否有MBTI测试结果
    if (_latestMbtiResult == null) {
      _showMbtiTestRequiredDialog();
      return;
    }
    
    // 检查Widget是否仍然挂载
    if (!mounted) return;
    
    setState(() { _loading = true; });
    
    try {
      // 确保MBTI类型存在且有效
      final mbtiType = _latestMbtiResult?.mbtiType;
      if (mbtiType == null || mbtiType.isEmpty) {
        throw Exception('MBTI类型无效，请先完成MBTI测试');
      }
      
      print('开始性格分析，MBTI类型: $mbtiType');
      
      // 获取用户日志内容
      final logText = await AiService.getUserLogsText(days: 30);
      
      // 再次检查Widget是否仍然挂载
      if (!mounted) return;
      
      print('日志内容长度: ${logText.length} 字符');
      
      // 调用DeepSeek API进行性格分析，使用MBTI测试结果
      final analysis = await AiService.analyzePersonalityWithDeepSeek(
        logText: logText,
        mbtiType: mbtiType,
      );
      
      // 再次检查Widget是否仍然挂载
      if (!mounted) return;
      
      setState(() {
        _currentPersonalityAnalysis = analysis;
        _personalityHistory.insert(0, analysis);
      });
      
      // 调试信息：打印分析结果数据结构
      print('性格分析结果: ${analysis.personalityChart}');
      print('MBTI类型: ${analysis.mbtiType}');
      
      // 检查Widget是否仍然挂载后再显示SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('性格分析完成（MBTI: ${_latestMbtiResult!.mbtiType}）'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('性格分析错误: $e');
      // 检查Widget是否仍然挂载后再显示错误信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('性格分析失败: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 检查Widget是否仍然挂载后再更新状态
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  // 显示需要MBTI测试的对话框
  void _showMbtiTestRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('需要MBTI测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('为了进行AI性格分析，需要先完成MBTI性格测试。'),
            SizedBox(height: 16),
            Text(
              'MBTI测试将帮助我们：',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• 了解你的基本性格类型'),
            Text('• 提供更精准的性格分析'),
            Text('• 生成个性化的建议和洞察'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startMbtiTest();
            },
            child: Text('开始测试'),
          ),
        ],
      ),
    );
  }

  // 开始MBTI测试
  void _startMbtiTest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MbtiTestScreen(
          onTestCompleted: (result) async {
            setState(() {
              _latestMbtiResult = result;
            });
            // 刷新MBTI记录列表
            await _loadMbtiRecords();
            // 重新加载最新的MBTI结果
            await _loadLatestMbtiResult();
            // 测试完成后不自动开始性格分析，让用户手动选择
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('MBTI测试完成！类型：${result.mbtiType}。现在可以进行AI性格分析。'),
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
  }

  // 获取性格分析按钮文本
  String _getPersonalityAnalysisButtonText() {
    if (_loadingMbtiResult) {
      return '加载MBTI结果中...';
    } else if (_latestMbtiResult == null) {
      return 'AI性格分析（需要MBTI测试）';
    } else {
      return 'AI性格分析（${_latestMbtiResult!.mbtiType}）';
    }
  }
  
  // 获取MBTI测试按钮文本
  String _getMbtiTestButtonText() {
    if (_loadingMbtiResult) {
      return '加载中...';
    } else if (_latestMbtiResult == null) {
      return '开始MBTI性格测试';
    } else {
      return '重新测试MBTI（当前：${_latestMbtiResult!.mbtiType}）';
    }
  }
  
  void _generateTestAnalysis() {
    final testWords = [
      {'word': '工作', 'count': 15},
      {'word': '学习', 'count': 12},
      {'word': '项目', 'count': 10},
      {'word': '会议', 'count': 8},
      {'word': '代码', 'count': 7},
      {'word': '设计', 'count': 6},
      {'word': '团队', 'count': 5},
      {'word': '客户', 'count': 4},
      {'word': '产品', 'count': 3},
      {'word': '创新', 'count': 2},
    ];
    
    setState(() {
      _keywords = testWords.map((w) => {'word': w['word']}).toList();
      _wordFreq = testWords;
    });
    
    // 添加到历史记录
    final testAnalysis = WordCloudAnalysis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'test_user',
      analysisDate: DateTime.now(),
      keywords: _keywords,
      wordFrequencies: _wordFreq,
      createdAt: DateTime.now(),
      description: '测试词云分析',
    );
    
    setState(() {
      _wordCloudHistory.insert(0, testAnalysis);
    });
  }
  
  void _generateTestPersonalityAnalysis() {
    final testAnalysis = PersonalityAnalysis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'test_user',
      analysisDate: DateTime.now(),
      personalityTraits: {
        '外向性': 0.8,
        '宜人性': 0.6,
        '尽责性': 0.9,
        '神经质': 0.3,
        '开放性': 0.7,
      },
      mbtiType: 'ENFP',
      workSuggestions: {
        '适合职业': ['产品经理', '市场营销', '创意总监', '培训师'],
        '工作环境': '开放、创新、团队合作',
        '发展建议': '发挥创造力，加强执行力',
        '沟通风格': '热情、富有感染力',
      },
      personalityChart: {
        'traits': {
          '外向性': 0.8,
          '宜人性': 0.6,
          '尽责性': 0.9,
          '神经质': 0.3,
          '开放性': 0.7,
        },
        'dimensions': {
          '领导力': 0.8,
          '创造力': 0.7,
          '沟通能力': 0.9,
          '分析能力': 0.6,
          '团队合作': 0.8,
        },
      },
      createdAt: DateTime.now(),
      description: '测试性格分析',
    );
    
    setState(() {
      _currentPersonalityAnalysis = testAnalysis;
      _personalityHistory.insert(0, testAnalysis);
    });
  }
  
  List<WordCloudAnalysis> _generateTestWordCloudData() {
    final dates = [
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now().subtract(const Duration(days: 3)),
      DateTime.now().subtract(const Duration(days: 7)),
    ];
    
    return dates.map((date) {
      final words = [
        {'word': '工作', 'count': 15},
        {'word': '学习', 'count': 12},
        {'word': '项目', 'count': 10},
        {'word': '会议', 'count': 8},
        {'word': '代码', 'count': 7},
      ];
      
      return WordCloudAnalysis(
        id: date.millisecondsSinceEpoch.toString(),
        userId: 'test_user',
        analysisDate: date,
        keywords: words.map((w) => {'word': w['word']}).toList(),
        wordFrequencies: words,
        createdAt: date,
        description: '${date.month}月${date.day}日日志分析',
      );
    }).toList();
  }
  
  List<PersonalityAnalysis> _generateTestPersonalityData() {
    return [
      PersonalityAnalysis(
        id: '1',
        userId: 'test_user',
        analysisDate: DateTime.now().subtract(const Duration(days: 1)),
        personalityTraits: {
          '外向性': 0.8,
          '宜人性': 0.6,
          '尽责性': 0.9,
          '神经质': 0.3,
          '开放性': 0.7,
        },
        mbtiType: 'ENFP',
        workSuggestions: {
          '适合职业': ['产品经理', '市场营销', '创意总监'],
          '工作环境': '开放、创新、团队合作',
          '发展建议': '发挥创造力，加强执行力',
        },
        personalityChart: {
          'traits': {
            '外向性': 0.8,
            '宜人性': 0.6,
            '尽责性': 0.9,
            '神经质': 0.3,
            '开放性': 0.7,
          },
          'dimensions': {
            '领导力': 0.8,
            '创造力': 0.7,
            '沟通能力': 0.9,
            '分析能力': 0.6,
            '团队合作': 0.8,
          },
        },
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        description: '性格分析报告',
      ),
    ];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI地图'),
        backgroundColor: const Color(0xFF1E3A8A), // 深蓝色
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: '词云分析', icon: Icon(Icons.cloud, size: 20)),
            Tab(text: '性格分析', icon: Icon(Icons.psychology, size: 20)),
            Tab(text: 'MBTI记录', icon: Icon(Icons.assessment, size: 20)),
            Tab(text: '性格分析历史', icon: Icon(Icons.timeline, size: 20)),
            Tab(text: '词云历史', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWordCloudTab(),
            _buildPersonalityTab(),
            _buildMbtiRecordsTab(),
            _buildPersonalityHistoryTab(),
            _buildWordCloudHistoryTab(),
          ],
        ),
      ),
    );
  }
  
  // 构建日期范围选择选项
  Widget _buildRangeOption(String value, String label, IconData icon) {
    final isSelected = _selectedRange == value;
    final isTodayOption = value == 'today';
    const double optionHeight = 130;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRange = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.08)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: SizedBox(
          height: optionHeight,
          child: isTodayOption
              ? _buildTodayRangeContent(isSelected, icon)
              : _buildDefaultRangeContent(isSelected, label, icon),
        ),
      ),
    );
  }

  Widget _buildDefaultRangeContent(bool isSelected, String label, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isSelected
              ? const Color(0xFF3B82F6)
              : Colors.grey[600],
          size: 26,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF1E3A8A)
                : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayRangeContent(bool isSelected, IconData icon) {
    final bool isToday = _isSameDate(_selectedLogDate, DateTime.now());
    final themeColor = isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF374151);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600],
        ),
        const SizedBox(height: 8),
        Text(
          '今日',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeColor,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDateSelectorOverlay() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loadingTodayLogs
            ? null
            : () async {
                if (_selectedRange != 'today') {
                  setState(() {
                    _selectedRange = 'today';
                  });
                }
                await _pickLogDate();
              },
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month,
                size: 20,
                color: const Color(0xFF3B82F6).withOpacity(0.95),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDisplayDate(_selectedLogDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取分析按钮文本
  String _getAnalyzeButtonText() {
    switch (_selectedRange) {
      case 'today':
        final isToday = _isSameDate(_selectedLogDate, DateTime.now());
        return isToday
            ? '一键分析今日日志'
            : '分析${_formatDisplayDate(_selectedLogDate)}日志';
      case 'last7days':
        return '一键分析7日内日志';
      case 'all':
        return '一键分析全部历史';
      default:
        return '一键分析日志';
    }
  }

  Widget _buildWordCloudTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今日日志展示
            _buildTodayLogsSection(),
            const SizedBox(height: 20),
            
            // 日期范围选择器
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择分析范围',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRangeOption('today', '今日', Icons.today),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildRangeOption('last7days', '7日内', Icons.date_range),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildRangeOption('all', '全部', Icons.history),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        left: -6,
                        top: -6,
                        child: _buildDateSelectorOverlay(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 一键分析按钮 - 优化样式
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        if (_selectedRange == 'today') {
                          _analyzeAndSave(targetDate: _selectedLogDate);
                        } else {
                          _analyzeAndSave();
                        }
                      },
                icon: const Icon(Icons.analytics, color: Colors.white),
                label: Text(
                  _loading ? '分析中...' : _getAnalyzeButtonText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // AI分析摘要（如果使用DeepSeek API）
            if (_wordCloudAnalysis != null && _isDeepSeekAnalysis) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'AI智能分析摘要',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'DeepSeek',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_wordCloudAnalysis!['summary'] != null)
                      Text(
                        _wordCloudAnalysis!['summary'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    if (_wordCloudAnalysis!['mainThemes'] != null &&
                        (_wordCloudAnalysis!['mainThemes'] as List).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_wordCloudAnalysis!['mainThemes'] as List)
                            .map((theme) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    theme.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 当前分析结果
              if (_keywords.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '日志关键词',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                      children: _keywords.map((k) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Text(
                          k['word'],
                          style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
              if (_wordFreq.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '词云图',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 12),
                    EnhancedWordCloud(words: _wordFreq),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPersonalityTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MBTI测试按钮
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _startMbtiTest,
                icon: const Icon(Icons.quiz, color: Colors.white),
                label: Text(
                  _getMbtiTestButtonText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 性格分析按钮 - 优化样式
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: (_loading || _loadingMbtiResult) 
                    ? null 
                    : () {
                        // 确保在点击时关闭键盘，避免输入法相关错误
                        FocusScope.of(context).unfocus();
                        _analyzePersonality();
                      },
                icon: const Icon(Icons.psychology, color: Colors.white),
                label: Text(
                  _loading ? '分析中...' : _getPersonalityAnalysisButtonText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // MBTI记录历史显示
            if (_latestMbtiResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'MBTI测试记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '最新测试：${_latestMbtiResult!.mbtiType}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '测试时间：${TimeUtils.formatDate(_latestMbtiResult!.testDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 当前性格分析结果
            if (_currentPersonalityAnalysis != null) ...[
              // AI分析结果展示（小方块）
              if (_currentPersonalityAnalysis!.aiAnalysisText != null && _currentPersonalityAnalysis!.aiAnalysisText!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_currentPersonalityAnalysis!.isDeepSeek == true 
                                ? const Color(0xFF10B981) 
                                : const Color(0xFF3B82F6)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _currentPersonalityAnalysis!.isDeepSeek == true 
                                ? Icons.psychology 
                                : Icons.auto_awesome,
                              color: _currentPersonalityAnalysis!.isDeepSeek == true 
                                ? const Color(0xFF10B981) 
                                : const Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPersonalityAnalysis!.isDeepSeek == true 
                                    ? 'DeepSeek AI 分析结果' 
                                    : '本地算法分析结果',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                if (_currentPersonalityAnalysis!.isDeepSeek == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '由 DeepSeek AI 生成',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (_currentPersonalityAnalysis!.mbtiType != null && _currentPersonalityAnalysis!.mbtiType!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 16,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'MBTI类型: ${_currentPersonalityAnalysis!.mbtiType}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF8B5CF6),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _currentPersonalityAnalysis!.aiAnalysisText!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // 性格图表展示
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: PersonalityChart(
                  personalityData: _currentPersonalityAnalysis!.personalityChart,
                  mbtiType: _currentPersonalityAnalysis!.mbtiType,
                ),
              ),
              const SizedBox(height: 20),
              
              // 工作建议
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '工作建议',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 12),
                    ..._buildWorkSuggestionsWidget(_currentPersonalityAnalysis!.workSuggestions),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // MBTI记录标签页
  Widget _buildMbtiRecordsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索和过滤控件
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 搜索框
                  TextField(
                    decoration: InputDecoration(
                      hintText: '搜索MBTI类型或测试日期...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() { _searchQuery = ''; });
                                _loadMbtiRecords();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF10B981)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() { _searchQuery = value; });
                      _loadMbtiRecords();
                    },
                  ),
                  const SizedBox(height: 12),
                  // MBTI类型过滤器 - 下拉菜单
                  Row(
                    children: [
                      const Text('MBTI类型筛选: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedMbtiType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: _allMbtiTypes.map((type) {
                              // 获取该类型的记录数量
                              int count = 0;
                              if (type == '全部') {
                                count = _mbtiTypeCounts.values.fold(0, (sum, c) => sum + c);
                              } else {
                                count = _mbtiTypeCounts[type] ?? 0;
                              }
                              
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(type),
                                    if (count > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedMbtiType = newValue;
                                });
                                _loadMbtiRecords();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 显示统计信息
                  if (_mbtiTypeCounts.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _allMbtiTypes.where((type) => type != '全部').map((type) {
                        final count = _mbtiTypeCounts[type] ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Chip(
                          label: Text('$type: $count'),
                          labelStyle: const TextStyle(fontSize: 12),
                          backgroundColor: _selectedMbtiType == type
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // MBTI记录列表
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.assessment, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        const Text(
                          'MBTI记录列表',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const Spacer(),
                        if (_loadingMbtiRecords)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_mbtiRecords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.assessment_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无MBTI记录',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '完成MBTI测试后，记录将自动显示在这里',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _mbtiRecords.length,
                      itemBuilder: (context, index) {
                        final record = _mbtiRecords[index];
                        return ListTile(
                          leading: _buildMbtiAvatar(record['mbti_type']),
                          title: Text(
                            'MBTI类型: ${record['mbti_type']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('测试日期: ${_formatTestDate(record['test_date'])}'),
                              Text('置信度: ${_formatConfidenceScore(record['confidence_score'])}%'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _getMbtiRecordDetail(record['id']),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取MBTI类型对应的颜色
  Color _getMbtiTypeColor(String mbtiType) {
    final colors = {
      'ENFP': const Color(0xFF8B5CF6),
      'INTJ': const Color(0xFF3B82F6),
      'ISFJ': const Color(0xFF10B981),
      'ISTJ': const Color(0xFFF59E0B),
      'ENFJ': const Color(0xFFEF4444),
    };
    return colors[mbtiType] ?? const Color(0xFF6B7280);
  }

  // 构建MBTI小人头像
  Widget _buildMbtiAvatar(dynamic mbtiType) {
    // 确保转换为字符串
    final String mbtiTypeStr = mbtiType?.toString() ?? '';
    final imagePath = _getMbtiImagePath(mbtiTypeStr);
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imagePath != null
            ? Image.asset(
                imagePath,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 如果图片加载失败，打印错误信息并显示文本标签作为后备
                  print('MBTI图片加载失败: $imagePath, 错误: $error');
                  return Container(
                    decoration: BoxDecoration(
                      color: _getMbtiTypeColor(mbtiTypeStr),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        mbtiTypeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  color: _getMbtiTypeColor(mbtiTypeStr),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    mbtiTypeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // 获取MBTI类型对应的图片路径
  String? _getMbtiImagePath(String mbtiType) {
    if (mbtiType == null || mbtiType.isEmpty) {
      print('MBTI类型为空: $mbtiType');
      return null;
    }
    
    // 所有16种MBTI类型
    const validTypes = [
      'INTJ', 'INTP', 'ENTJ', 'ENTP',
      'INFJ', 'INFP', 'ENFJ', 'ENFP',
      'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
      'ISTP', 'ISFP', 'ESTP', 'ESFP'
    ];
    
    final upperType = mbtiType.toUpperCase().trim();
    if (!validTypes.contains(upperType)) {
      print('MBTI类型无效: $mbtiType (转换为: $upperType)');
      return null;
    }
    
    final imagePath = 'assets/images/mbti/$upperType.png';
    print('MBTI图片路径: $imagePath');
    return imagePath;
  }

  // 格式化测试日期
  String _formatTestDate(dynamic dateValue) {
    if (dateValue == null) return '未知';
    
    try {
      DateTime dateTime;
      if (dateValue is DateTime) {
        dateTime = dateValue;
      } else if (dateValue is String) {
        // 尝试解析字符串日期
        dateTime = DateTime.parse(dateValue);
      } else {
        return dateValue.toString();
      }
      return TimeUtils.formatDate(dateTime);
    } catch (e) {
      // 如果解析失败，尝试提取日期部分
      final dateStr = dateValue.toString();
      if (dateStr.contains(' ')) {
        return dateStr.split(' ')[0];
      }
      return dateStr;
    }
  }

  // 格式化置信度分数
  String _formatConfidenceScore(dynamic scoreValue) {
    if (scoreValue == null) return '0.0';
    
    try {
      double score;
      if (scoreValue is double) {
        score = scoreValue;
      } else if (scoreValue is int) {
        score = scoreValue.toDouble();
      } else if (scoreValue is String) {
        score = double.tryParse(scoreValue) ?? 0.0;
      } else {
        return '0.0';
      }
      
      // 确保分数在0-1范围内，然后转换为百分比
      if (score > 1.0) {
        // 如果已经是百分比形式（0-100），直接使用
        return score.toStringAsFixed(1);
      } else {
        // 如果是0-1的小数，转换为百分比
        return (score * 100).toStringAsFixed(1);
      }
    } catch (e) {
      return '0.0';
    }
  }
  
  Widget _buildWordCloudHistoryTab() {
    if (_wordCloudHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无词云分析历史',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _wordCloudHistory.length,
      itemBuilder: (context, index) {
        final analysis = _wordCloudHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud, color: Color(0xFF3B82F6)),
            ),
            title: Text(
              analysis.description ?? '词云分析',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            subtitle: Text(
              '分析日期: ${analysis.analysisDate.toString().split(' ')[0]}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF3B82F6)),
            onTap: () => _showWordCloudDetail(analysis),
          ),
        );
      },
    );
  }
  
  Widget _buildPersonalityHistoryTab() {
    if (_personalityHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无性格分析历史',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _personalityHistory.length,
      itemBuilder: (context, index) {
        final analysis = _personalityHistory[index];
        final traitEntries = analysis.personalityTraits.entries.toList();
        final workSuggestionEntries = analysis.workSuggestions.entries.toList();
        final summaryText = analysis.workSuggestions['日志分析摘要']?.toString()
            ?? analysis.description
            ?? analysis.aiAnalysisText
            ?? 'AI已结合日志与MBTI生成综合分析。';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMbtiAvatar(analysis.mbtiType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${analysis.mbtiType} 性格分析',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '分析时间：${TimeUtils.formatDateTime(analysis.analysisDate.toLocal())}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (analysis.isDeepSeek == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DeepSeek',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildHistoryInfoRow(
                icon: Icons.notes_outlined,
                title: '日志&MBTI综合摘要',
                content: _truncateText(summaryText),
              ),
              if (traitEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '核心性格特质',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: traitEntries.take(6).map((entry) {
                    return _buildTraitChip(
                      entry.key,
                      entry.value.toString(),
                    );
                  }).toList(),
                ),
              ],
              if (workSuggestionEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'AI分析数据',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                ...workSuggestionEntries.take(3).map((entry) {
                  return _buildHistoryInfoRow(
                    icon: Icons.data_usage_outlined,
                    title: entry.key,
                    content: _truncateText(_formatHistoryValue(entry.value)),
                  );
                }),
              ],
              if ((analysis.aiAnalysisText ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildHistoryInfoRow(
                  icon: Icons.insights_outlined,
                  title: 'AI深度分析',
                  content: _truncateText(analysis.aiAnalysisText!),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showPersonalityDetail(analysis),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('查看完整报告'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryInfoRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4338CA),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4C1D95),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateText(String text, {int maxLength = 160}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _formatHistoryValue(dynamic value) {
    if (value == null) return '暂无数据';
    if (value is List) {
      return value.map((e) => e.toString()).join('、');
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join('；');
    }
    return value.toString();
  }
  
  void _showWordCloudDetail(WordCloudAnalysis analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(analysis.description ?? '词云分析详情'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('分析日期: ${analysis.analysisDate.toString().split(' ')[0]}'),
              const SizedBox(height: 16),
              EnhancedWordCloud(words: analysis.wordFrequencies),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  void _showPersonalityDetail(PersonalityAnalysis analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              analysis.isDeepSeek == true ? Icons.psychology : Icons.auto_awesome,
              color: analysis.isDeepSeek == true 
                ? const Color(0xFF10B981) 
                : const Color(0xFF3B82F6),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${analysis.mbtiType} - 性格分析详情'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('分析日期: ${analysis.analysisDate.toString().split(' ')[0]}'),
                    const SizedBox(width: 12),
                    if (analysis.isDeepSeek == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DeepSeek AI',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '本地算法',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (analysis.aiAnalysisText != null && analysis.aiAnalysisText!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (analysis.isDeepSeek == true 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFF3B82F6)).withOpacity(0.3),
                      ),
                    ),
                    child: SelectableText(
                      analysis.aiAnalysisText!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PersonalityChart(
                  personalityData: analysis.personalityChart,
                  mbtiType: analysis.mbtiType,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  // 今日日志展示组件
  Widget _buildTodayLogsSection() {
    final bool isTodaySelected = _isSameDate(_selectedLogDate, DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '日期日志',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前选择：${_formatDisplayDate(_selectedLogDate)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingTodayLogs)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: () => _loadTodayLogs(targetDate: _selectedLogDate),
                    icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
                    tooltip: '刷新当前日期日志',
                  ),
              ],
            ),
          ),
          // 日志内容
          if (_loadingTodayLogs)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_todayLogs.isEmpty)
            _buildEmptyLogsState()
          else
            Column(
              children: [
                _buildSelectedDateSummary(),
                _buildLogsList(),
              ],
            ),
        ],
      ),
    );
  }
  
  // 空日志状态
  Widget _buildEmptyLogsState() {
    final selectedLabel = _formatDisplayDate(_selectedLogDate);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '$selectedLabel 暂无日志记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '可以选择其他日期或记录这一天的内容',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          // 添加跳转按钮
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddLog(),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
              label: const Text(
                '去添加日志',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 跳转到添加日志页面 - 使用与日志模块相同的对话框
  Future<void> _navigateToAddLog() async {
    // 加载任务列表
    List<Task> tasks = [];
    try {
      tasks = await ApiService.getTasks();
    } catch (e) {
      print('加载任务列表失败: $e');
    }
    
    // 使用LogEnhancedScreen的公共静态方法显示添加日志对话框
    // 这与日志模块使用的对话框完全相同
    LogEnhancedScreen.showAddLogDialog(
      context: context,
      user: widget.user,
      tasks: tasks,
      onLogAdded: () async {
        // 日志添加成功后，刷新今日日志列表
        await _loadTodayLogs(targetDate: _selectedLogDate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('日志添加成功！'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
  
  // 日志列表
  Widget _buildLogsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _todayLogs.take(3).map((log) => _buildLogCard(log)).toList()
          ..addAll([
            if (_todayLogs.length > 3) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '还有 ${_todayLogs.length - 3} 条日志...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ]),
      ),
    );
  }

  Widget _buildSelectedDateSummary() {
    final previewLogs = _todayLogs.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Text(
                  '日志速览',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_todayLogs.length} 条',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...previewLogs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.logTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.category_outlined,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  log.category ?? '未分类',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  log.logDate != null
                                      ? '${log.logDate!.hour.toString().padLeft(2, '0')}:${log.logDate!.minute.toString().padLeft(2, '0')}'
                                      : log.createdAtDate != null
                                          ? '${log.createdAtDate!.hour.toString().padLeft(2, '0')}:${log.createdAtDate!.minute.toString().padLeft(2, '0')}'
                                          : '--:--',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
  
  // 单个日志卡片
  Widget _buildLogCard(PersonalLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日志标题和分类
          Row(
            children: [
              Expanded(
                child: Text(
                  log.logTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.category ?? '未分类',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          // 日志内容预览
          if (log.content != null && log.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.content!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // 底部信息
          const SizedBox(height: 12),
          Row(
            children: [
              // 天气图标
              if (log.weather != null && log.weather!.isNotEmpty) ...[
                Icon(
                  _getWeatherIcon(log.weather!),
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  log.weather!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              
              // 时间
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                log.logDate != null 
                  ? '${log.logDate!.hour.toString().padLeft(2, '0')}:${log.logDate!.minute.toString().padLeft(2, '0')}'
                  : log.createdAtDate != null
                    ? '${log.createdAtDate!.hour.toString().padLeft(2, '0')}:${log.createdAtDate!.minute.toString().padLeft(2, '0')}'
                    : '--:--',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              
              const Spacer(),
              
              // 关键词标签
              if (log.keywords.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.keywords.first,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  // 获取象限颜色
  Color _getQuadrantColor(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return Colors.red;
      case 'important_not_urgent':
        return Colors.blue;
      case 'not_important_urgent':
        return Colors.orange;
      case 'not_important_not_urgent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  // 获取象限标签
  String _getQuadrantLabel(String quadrant) {
    switch (quadrant) {
      case 'important_urgent':
        return '重要紧急';
      case 'important_not_urgent':
        return '重要不紧急';
      case 'not_important_urgent':
        return '不重要紧急';
      case 'not_important_not_urgent':
        return '不重要不紧急';
      default:
        return '未分类';
    }
  }
  
  // 获取天气图标
  IconData _getWeatherIcon(String weather) {
    switch (weather.toLowerCase()) {
      case 'sunny':
      case '晴天':
        return Icons.wb_sunny;
      case 'cloudy':
      case '多云':
        return Icons.cloud;
      case 'rainy':
      case '雨天':
        return Icons.grain;
      case 'snowy':
      case '雪天':
        return Icons.ac_unit;
      default:
        return Icons.wb_sunny;
    }
  }
}
