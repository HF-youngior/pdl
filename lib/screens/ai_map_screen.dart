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
    _tabController = TabController(length: 4, vsync: this);
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
      final wordCloudHistory = await AiService.getWordCloudHistory();
      final personalityHistory = await AiService.getPersonalityHistory();
      setState(() {
        _wordCloudHistory = wordCloudHistory;
        _personalityHistory = personalityHistory;
      });
    } catch (e) {
      // 如果API不可用，使用测试数据
      _loadTestData();
    }
  }
  
  Future<void> _loadTodayLogs() async {
    setState(() {
      _loadingTodayLogs = true;
    });
    
    try {
      final allLogs = await ApiService.getPersonalLogs(widget.user.id);
      final today = DateTime.now();
      
      // 优先使用log_date字段，如果为空则使用created_at
      final todayLogs = allLogs.where((log) {
        // 优先使用logDate字段
        DateTime? logDate = log.logDate;
        
        // 如果logDate为空，使用createdAtDate
        if (logDate == null) {
          logDate = log.createdAtDate;
        }
        
        // 如果仍然为空，跳过这条日志
        if (logDate == null) return false;
        
        // 比较年月日
        return logDate.year == today.year &&
               logDate.month == today.month &&
               logDate.day == today.day;
      }).toList();
      
      setState(() {
        _todayLogs = todayLogs;
        _loadingTodayLogs = false;
      });
    } catch (e) {
      setState(() {
        _loadingTodayLogs = false;
      });
      print('加载今日日志失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载今日日志失败: $e')),
      );
    }
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
        
        // 计算每个MBTI类型的数量
        Map<String, int> counts = {};
        for (var record in allRecords) {
          final type = record['mbti_type']?.toString() ?? '未知';
          counts[type] = (counts[type] ?? 0) + 1;
        }
        
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

  // 清理不完整的MBTI记录
  Future<void> _cleanIncompleteMbtiRecords() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text(
          '将删除以下不完整的MBTI记录：\n'
          '• 缺少MBTI类型的记录\n'
          '• 缺少测试日期的记录\n'
          '• 缺少测试分数的记录\n'
          '• 同一天同一类型的重复记录（保留最新的）\n\n'
          '此操作不可恢复，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('确定清理', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _loading = true; });

    try {
      // 获取所有记录
      final allRecordsResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records'),
        headers: ApiService.getAuthHeaders(),
      );

      if (allRecordsResponse.statusCode != 200) {
        throw Exception('获取记录失败');
      }

      final allData = jsonDecode(allRecordsResponse.body);
      List<Map<String, dynamic>> allRecords = List<Map<String, dynamic>>.from(allData['records'] ?? []);

      // 找出需要删除的记录
      List<String> recordsToDelete = [];
      Map<String, Map<String, dynamic>> dateTypeMap = {}; // 用于去重：日期_MBTI类型 -> 记录

      for (var record in allRecords) {
        final mbtiType = record['mbti_type']?.toString() ?? '';
        final testDate = record['test_date']?.toString() ?? '';
        final testScores = record['test_scores'];
        final id = record['id']?.toString() ?? '';

        // 检查是否不完整
        bool isIncomplete = false;
        if (mbtiType.isEmpty) {
          isIncomplete = true;
        } else if (testDate.isEmpty) {
          isIncomplete = true;
        } else if (testScores == null) {
          isIncomplete = true;
        }

        if (isIncomplete) {
          recordsToDelete.add(id);
          continue;
        }

        // 检查重复：同一天同一类型只保留最新的
        try {
          final dateTime = DateTime.parse(testDate);
          final dateKey = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}_$mbtiType';

          if (!dateTypeMap.containsKey(dateKey)) {
            dateTypeMap[dateKey] = record;
          } else {
            // 比较创建时间，保留最新的
            final existingRecord = dateTypeMap[dateKey]!;
            final existingCreatedAt = existingRecord['created_at']?.toString();
            final currentCreatedAt = record['created_at']?.toString();

            if (currentCreatedAt != null && existingCreatedAt != null) {
              try {
                final existing = DateTime.parse(existingCreatedAt);
                final current = DateTime.parse(currentCreatedAt);
                if (current.isAfter(existing)) {
                  // 当前记录更新，删除旧的
                  recordsToDelete.add(existingRecord['id']?.toString() ?? '');
                  dateTypeMap[dateKey] = record;
                } else {
                  // 旧记录更新，删除当前的
                  recordsToDelete.add(id);
                }
              } catch (e) {
                // 解析失败，比较test_date
                try {
                  final existingTestDate = DateTime.parse(existingRecord['test_date']?.toString() ?? '');
                  final currentTestDate = DateTime.parse(testDate);
                  if (currentTestDate.isAfter(existingTestDate)) {
                    recordsToDelete.add(existingRecord['id']?.toString() ?? '');
                    dateTypeMap[dateKey] = record;
                  } else {
                    recordsToDelete.add(id);
                  }
                } catch (e2) {
                  // 如果都解析失败，保留第一个
                  recordsToDelete.add(id);
                }
              }
            } else {
              // 如果无法比较，保留第一个
              recordsToDelete.add(id);
            }
          }
        } catch (e) {
          // 日期解析失败，标记为不完整
          recordsToDelete.add(id);
        }
      }

      // 删除记录
      int deletedCount = 0;
      int failedCount = 0;

      for (var id in recordsToDelete) {
        if (id.isEmpty) continue;
        try {
          final deleteResponse = await http.delete(
            Uri.parse('${ApiService.baseUrl}/mbti-records/$id'),
            headers: ApiService.getAuthHeaders(),
          );

          if (deleteResponse.statusCode == 200) {
            deletedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
        }
      }

      // 重新加载记录列表
      await _loadMbtiRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletedCount > 0
                  ? '清理完成：已删除 $deletedCount 条记录${failedCount > 0 ? "，$failedCount 条删除失败" : ""}'
                  : '没有需要清理的记录',
            ),
            backgroundColor: deletedCount > 0 ? Colors.green : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清理失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() { _loading = false; });
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
              _buildDetailSection('AI分析', _formatAiAnalysis(_selectedMbtiRecord!['ai_analysis'])),
              _buildDetailSection('工作建议', _formatWorkSuggestions(_selectedMbtiRecord!['work_suggestions'])),
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

  List<String> _formatAiAnalysis(Map<String, dynamic> analysis) {
    List<String> items = [];
    if (analysis['strengths'] != null) {
      items.add('优势: ${analysis['strengths'].join(', ')}');
    }
    if (analysis['weaknesses'] != null) {
      items.add('劣势: ${analysis['weaknesses'].join(', ')}');
    }
    if (analysis['career_suitability'] != null) {
      items.add('适合职业: ${analysis['career_suitability'].join(', ')}');
    }
    return items;
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
  
  Future<void> _analyzeAndSave() async {
    setState(() { _loading = true; });
    try {
      // 先刷新今日日志
      await _loadTodayLogs();
      
      // 调用后端API分析今日日志
      final result = await AiService.analyzeToday(topK: 30);
      
      if (result.wordFrequencies.isEmpty) {
        setState(() {
          _keywords = [];
          _wordFreq = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日没有可分析的日志，请先记录一些日志')),
        );
        return;
      }
      
      setState(() {
        _keywords = result.keywords;
        _wordFreq = result.wordFrequencies;
      });
      
      // 保存分析结果到历史记录
      try {
        final savedAnalysis = await AiService.saveWordCloudAnalysis(
          analysisDate: DateTime.now(),
          keywords: result.keywords,
          wordFrequencies: result.wordFrequencies,
          description: '今日日志分析',
        );
        
        setState(() {
          _wordCloudHistory.insert(0, savedAnalysis);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日日志分析完成并已保存到历史记录')),
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
            _buildHistoryTab(),
          ],
        ),
      ),
    );
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
                onPressed: _loading ? null : _analyzeAndSave,
                icon: const Icon(Icons.today, color: Colors.white),
                label: Text(
                  _loading ? '分析中...' : '一键分析今日日志',
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
                    ..._currentPersonalityAnalysis!.workSuggestions.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (entry.value is List) ...[
                              ...(entry.value as List).map((item) => 
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                                      Expanded(child: Text(item.toString(), style: const TextStyle(color: Color(0xFF6B7280)))),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
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
            // 清理不完整记录按钮
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _cleanIncompleteMbtiRecords,
                icon: const Icon(Icons.cleaning_services, color: Colors.white),
                label: Text(
                  _loading ? '清理中...' : '清理不完整记录',
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
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getMbtiTypeColor(record['mbti_type']),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                record['mbti_type'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
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
  
  Widget _buildHistoryTab() {
    return _buildWordCloudHistory();
  }
  
  Widget _buildWordCloudHistory() {
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
  
  Widget _buildPersonalityHistory() {
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
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Color(0xFF8B5CF6)),
            ),
            title: Text(
              '${analysis.mbtiType} - ${analysis.description ?? '性格分析'}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            subtitle: Text(
              '分析日期: ${analysis.analysisDate.toString().split(' ')[0]}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF8B5CF6)),
            onTap: () => _showPersonalityDetail(analysis),
          ),
        );
      },
    );
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
                        '今日日志',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
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
                    onPressed: _loadTodayLogs,
                    icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
                    tooltip: '刷新今日日志',
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
            _buildLogsList(),
        ],
      ),
    );
  }
  
  // 空日志状态
  Widget _buildEmptyLogsState() {
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
            '今日还没有日志记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始记录今天的工作和生活吧',
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
        await _loadTodayLogs();
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
