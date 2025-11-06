import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/wordcloud_analysis.dart';
import '../models/personality_analysis.dart';

class AiAnalyzeResult {
  final List<Map<String, dynamic>> keywords;
  final List<Map<String, dynamic>> wordFrequencies;

  AiAnalyzeResult({required this.keywords, required this.wordFrequencies});
}

class AiService {
  static Future<AiAnalyzeResult> analyzeLog(String text, {int topK = 20}) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/ai/analyze-log'),
      headers: ApiService.getAuthHeaders(),
      body: jsonEncode({'text': text, 'topK': topK}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final keywords = (data['keywords'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final wordFrequencies = (data['wordFrequencies'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return AiAnalyzeResult(keywords: keywords, wordFrequencies: wordFrequencies);
    }
    throw Exception('AI分析失败，状态码: ${response.statusCode}');
  }

  static Future<AiAnalyzeResult> analyzeToday({int topK = 20}) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/ai/analyze-today?topK=$topK'),
      headers: ApiService.getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final keywords = (data['keywords'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final wordFrequencies = (data['wordFrequencies'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return AiAnalyzeResult(keywords: keywords, wordFrequencies: wordFrequencies);
    }
    throw Exception('AI今日日志分析失败，状态码: ${response.statusCode}');
  }

  // 保存词云分析结果
  static Future<WordCloudAnalysis> saveWordCloudAnalysis({
    required DateTime analysisDate,
    required List<Map<String, dynamic>> keywords,
    required List<Map<String, dynamic>> wordFrequencies,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/ai/save-wordcloud'),
      headers: ApiService.getAuthHeaders(),
      body: jsonEncode({
        'analysisDate': analysisDate.toIso8601String(),
        'keywords': keywords,
        'wordFrequencies': wordFrequencies,
        'description': description,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return WordCloudAnalysis.fromJson(data);
    }
    throw Exception('保存词云分析失败，状态码: ${response.statusCode}');
  }

  // 获取词云分析历史
  static Future<List<WordCloudAnalysis>> getWordCloudHistory() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/ai/wordcloud-history'),
      headers: ApiService.getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => WordCloudAnalysis.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('获取词云历史失败，状态码: ${response.statusCode}');
  }

  // DeepSeek API 性格分析
  static Future<PersonalityAnalysis> analyzePersonalityWithDeepSeek({
    required String logText,
    String? mbtiType,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/ai/personality-analysis'),
      headers: ApiService.getAuthHeaders(),
      body: jsonEncode({
        'logText': logText,
        'mbtiType': mbtiType,
        'useDeepSeek': true,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PersonalityAnalysis.fromJson(data);
    }
    throw Exception('性格分析失败，状态码: ${response.statusCode}');
  }

  // 获取性格分析历史
  static Future<List<PersonalityAnalysis>> getPersonalityHistory() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/ai/personality-history'),
      headers: ApiService.getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => PersonalityAnalysis.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('获取性格分析历史失败，状态码: ${response.statusCode}');
  }

  // 获取用户最新的MBTI记录
  static Future<Map<String, dynamic>?> getUserLatestMbti() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records?limit=1'),
        headers: ApiService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final records = data['records'] as List<dynamic>?;
        if (records != null && records.isNotEmpty) {
          return records[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('获取MBTI记录失败: $e');
      return null;
    }
  }

  // 获取用户日志内容（用于性格分析）
  static Future<String> getUserLogsText({int days = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/personal-logs'),
        headers: ApiService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> logs = jsonDecode(response.body);
        if (logs.isEmpty) {
          return '暂无日志记录，请先记录一些工作日志。';
        }
        
        // 获取最近N天的日志
        final now = DateTime.now();
        final recentLogs = logs.where((log) {
          final logDate = DateTime.parse(log['created_at']);
          return now.difference(logDate).inDays <= days;
        }).toList();
        
        if (recentLogs.isEmpty) {
          return '最近${days}天内暂无日志记录，使用全部日志进行分析。';
        }
        
        // 合并日志内容
        final logTexts = recentLogs.map((log) {
          final title = log['title'] ?? '';
          final content = log['content'] ?? '';
          return '$title $content';
        }).join('\n');
        
        return logTexts.isEmpty ? '日志内容为空' : logTexts;
      }
      return '获取日志失败';
    } catch (e) {
      print('获取用户日志失败: $e');
      return '获取日志失败: $e';
    }
  }
}

Map<String, String> _authHeaders() {
  // 直接复用 ApiService 的 token 头
  // 这里访问不到其私有方法，故简化为仅设置 Content-Type；
  // 若你的后端此接口需要鉴权，请在 ApiService 暴露一个获取鉴权头的方法供复用。
  return {};
}



