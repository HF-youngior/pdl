import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../models/wordcloud_analysis.dart';
import '../models/personality_analysis.dart';
import '../widgets/enhanced_wordcloud.dart';
import '../widgets/personality_chart.dart';

class AiMapScreen extends StatefulWidget {
  const AiMapScreen({super.key});

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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
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
                      final result = await AiService.analyzeToday(topK: 30);
                      setState(() {
                        _keywords = result.keywords;
                        _wordFreq = result.wordFrequencies;
                      });
      
      if (_wordFreq.isNotEmpty) {
        // 保存分析结果
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
          const SnackBar(content: Text('今日日志分析完成并已保存')),
        );
      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日没有可分析的日志')),
                        );
                      }
                    } catch (e) {
      // 如果API不可用，使用测试数据
      _generateTestAnalysis();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('使用测试数据进行分析')),
      );
    } finally {
      setState(() { _loading = false; });
    }
  }
  
  Future<void> _analyzePersonality() async {
    setState(() { _loading = true; });
    try {
      final analysis = await AiService.analyzePersonalityWithDeepSeek(
        logText: '基于用户日志进行性格分析',
        mbtiType: 'ENFP', // 可以从用户设置中获取
      );
      
      setState(() {
        _currentPersonalityAnalysis = analysis;
        _personalityHistory.insert(0, analysis);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('性格分析完成')),
      );
    } catch (e) {
      // 使用测试数据
      _generateTestPersonalityAnalysis();
                      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('使用测试数据进行性格分析')),
                      );
                    } finally {
                      setState(() { _loading = false; });
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
            Tab(text: '历史记录', icon: Icon(Icons.history, size: 20)),
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
                onPressed: _loading ? null : _analyzePersonality,
                icon: const Icon(Icons.psychology, color: Colors.white),
                label: Text(
                  _loading ? '分析中...' : 'AI性格分析（DeepSeek）',
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
            
            // 当前性格分析结果
            if (_currentPersonalityAnalysis != null) ...[
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
  
  Widget _buildHistoryTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: [
                  Tab(text: '词云历史', icon: Icon(Icons.cloud, size: 18)),
                  Tab(text: '性格历史', icon: Icon(Icons.psychology, size: 18)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildWordCloudHistory(),
                  _buildPersonalityHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        title: Text('${analysis.mbtiType} - 性格分析详情'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('分析日期: ${analysis.analysisDate.toString().split(' ')[0]}'),
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
}
