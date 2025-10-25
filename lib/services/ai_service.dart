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
      Uri.parse('${ApiService.baseUrl}/ai/analyze-log'),
      headers: {'Content-Type': 'application/json'},
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
      Uri.parse('${ApiService.baseUrl}/ai/analyze-today-only?topK=$topK'),
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
      Uri.parse('${ApiService.baseUrl}/ai/save-wordcloud'),
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
      Uri.parse('${ApiService.baseUrl}/ai/wordcloud-history'),
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
      Uri.parse('${ApiService.baseUrl}/ai/personality-analysis'),
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
      Uri.parse('${ApiService.baseUrl}/ai/personality-history'),
      headers: ApiService.getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => PersonalityAnalysis.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('获取性格分析历史失败，状态码: ${response.statusCode}');
  }
}

Map<String, String> _authHeaders() {
  // 直接复用 ApiService 的 token 头
  // 这里访问不到其私有方法，故简化为仅设置 Content-Type；
  // 若你的后端此接口需要鉴权，请在 ApiService 暴露一个获取鉴权头的方法供复用。
  return {};
}



