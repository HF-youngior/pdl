import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mbti_question.dart';
import '../models/mbti_test_result.dart';
import '../services/api_service.dart';

class MbtiTestService {
  // 计算MBTI测试结果
  static Future<MbtiTestResult> calculateResult(List<MbtiTestAnswer> answers) async {
    // 计算各维度分数
    final scores = <String, int>{
      'E': 0, 'I': 0,
      'S': 0, 'N': 0,
      'T': 0, 'F': 0,
      'J': 0, 'P': 0,
    };

    // 统计各维度的选择
    for (final answer in answers) {
      final dimension = answer.dimension;
      if (answer.selectedOption == 0) {
        scores[dimension[0]] = (scores[dimension[0]] ?? 0) + 1;
      } else {
        scores[dimension[1]] = (scores[dimension[1]] ?? 0) + 1;
      }
    }

    // 确定MBTI类型
    final mbtiType = _determineMbtiType(scores);

    // 计算置信度
    final confidenceScore = _calculateConfidence(scores);

    // 生成性格特征描述
    final personalityTraits = _generatePersonalityTraits(scores);

    // 生成优势和劣势
    final strengths = _generateStrengths(mbtiType);
    final weaknesses = _generateWeaknesses(mbtiType);

    return MbtiTestResult(
      mbtiType: mbtiType,
      scores: scores,
      personalityTraits: personalityTraits,
      testDate: DateTime.now(),
      testVersion: 'v1.0',
      confidenceScore: confidenceScore,
      strengths: strengths,
      weaknesses: weaknesses,
    );
  }

  // 确定MBTI类型
  static String _determineMbtiType(Map<String, int> scores) {
    String mbtiType = '';

    // E vs I
    mbtiType += scores['E']! > scores['I']! ? 'E' : 'I';

    // S vs N
    mbtiType += scores['S']! > scores['N']! ? 'S' : 'N';

    // T vs F
    mbtiType += scores['T']! > scores['F']! ? 'T' : 'F';

    // J vs P
    mbtiType += scores['J']! > scores['P']! ? 'J' : 'P';

    return mbtiType;
  }

  // 计算置信度
  static double _calculateConfidence(Map<String, int> scores) {
    double totalConfidence = 0.0;
    int dimensionCount = 0;

    // 计算每个维度的置信度
    final dimensions = [
      ['E', 'I'],
      ['S', 'N'],
      ['T', 'F'],
      ['J', 'P'],
    ];

    for (final dimension in dimensions) {
      final score1 = scores[dimension[0]]!;
      final score2 = scores[dimension[1]]!;
      final total = score1 + score2;
      
      if (total > 0) {
        final maxScore = score1 > score2 ? score1 : score2;
        final confidence = maxScore / total;
        totalConfidence += confidence;
        dimensionCount++;
      }
    }

    return dimensionCount > 0 ? totalConfidence / dimensionCount : 0.0;
  }

  // 生成性格特征描述
  static Map<String, String> _generatePersonalityTraits(Map<String, int> scores) {
    return {
      'extroversion': scores['E']! > scores['I']! 
          ? '外向型，善于社交和沟通，从与他人互动中获得能量'
          : '内向型，喜欢深度思考，从独处中获得能量',
      'sensing': scores['S']! > scores['N']! 
          ? '感觉型，注重细节和实际，关注当下和具体事实'
          : '直觉型，关注可能性和意义，喜欢探索新的想法',
      'thinking': scores['T']! > scores['F']! 
          ? '思维型，注重逻辑和客观，以事实和原则为导向'
          : '情感型，重视价值观和感受，以人际关系为导向',
      'judging': scores['J']! > scores['P']! 
          ? '判断型，喜欢有序和计划，倾向于快速做决定'
          : '感知型，保持开放和灵活，倾向于收集更多信息',
    };
  }

  // 生成优势
  static List<String> _generateStrengths(String mbtiType) {
    switch (mbtiType) {
      case 'INTJ':
        return ['战略思维', '独立自主', '追求完美', '理性分析', '长远规划'];
      case 'INTP':
        return ['逻辑分析', '创新思维', '客观理性', '深度思考', '理论构建'];
      case 'ENTJ':
        return ['领导能力', '目标导向', '决策果断', '组织能力', '执行力强'];
      case 'ENTP':
        return ['创新思维', '辩论能力', '适应性强', '充满活力', '善于学习'];
      case 'INFJ':
        return ['洞察力强', '理想主义', '富有同情心', '创造力强', '深度理解'];
      case 'INFP':
        return ['价值观强', '富有创造力', '善解人意', '灵活适应', '真诚待人'];
      case 'ENFJ':
        return ['领导魅力', '善于激励', '关心他人', '沟通能力强', '组织协调'];
      case 'ENFP':
        return ['热情洋溢', '富有想象力', '善于激励', '适应性强', '人际关系好'];
      case 'ISTJ':
        return ['可靠负责', '注重细节', '有条理', '坚持原则', '执行力强'];
      case 'ISFJ':
        return ['关心他人', '忠诚可靠', '注重细节', '善解人意', '责任心强'];
      case 'ESTJ':
        return ['组织能力强', '决策果断', '执行力强', '注重效率', '领导能力'];
      case 'ESFJ':
        return ['关心他人', '善于合作', '责任心强', '沟通能力强', '组织协调'];
      case 'ISTP':
        return ['实用主义', '冷静分析', '动手能力强', '灵活适应', '独立自主'];
      case 'ISFP':
        return ['温和友善', '富有创造力', '灵活适应', '善解人意', '价值观强'];
      case 'ESTP':
        return ['行动力强', '充满活力', '善于应对挑战', '实用主义', '适应性强'];
      case 'ESFP':
        return ['热情友好', '善于社交', '乐观积极', '适应性强', '关心他人'];
      default:
        return ['独特优势', '个人特色', '潜在能力'];
    }
  }

  // 生成劣势
  static List<String> _generateWeaknesses(String mbtiType) {
    switch (mbtiType) {
      case 'INTJ':
        return ['过于独立', '缺乏耐心', '忽视细节', '过于理性', '难以妥协'];
      case 'INTP':
        return ['缺乏执行力', '过于理论化', '忽视情感', '难以决策', '社交困难'];
      case 'ENTJ':
        return ['过于强势', '缺乏耐心', '忽视他人感受', '过于控制', '压力过大'];
      case 'ENTP':
        return ['缺乏专注', '难以坚持', '过于辩论', '忽视细节', '难以完成'];
      case 'INFJ':
        return ['过于理想化', '难以拒绝', '过于敏感', '缺乏实际', '压力过大'];
      case 'INFP':
        return ['过于敏感', '难以决策', '缺乏实际', '过于理想化', '难以拒绝'];
      case 'ENFJ':
        return ['过于关心他人', '难以拒绝', '压力过大', '过于理想化', '忽视自己'];
      case 'ENFP':
        return ['缺乏专注', '难以坚持', '过于敏感', '难以决策', '压力过大'];
      case 'ISTJ':
        return ['过于保守', '缺乏灵活性', '难以适应变化', '过于严格', '缺乏创新'];
      case 'ISFJ':
        return ['过于关心他人', '难以拒绝', '缺乏自信', '过于保守', '忽视自己'];
      case 'ESTJ':
        return ['过于严格', '缺乏灵活性', '难以妥协', '过于控制', '忽视他人感受'];
      case 'ESFJ':
        return ['过于关心他人', '难以拒绝', '缺乏自信', '过于传统', '忽视自己'];
      case 'ISTP':
        return ['缺乏计划', '难以承诺', '过于独立', '缺乏情感表达', '难以合作'];
      case 'ISFP':
        return ['过于敏感', '难以拒绝', '缺乏自信', '过于理想化', '难以决策'];
      case 'ESTP':
        return ['缺乏计划', '难以专注', '过于冲动', '缺乏耐心', '难以坚持'];
      case 'ESFP':
        return ['缺乏专注', '难以坚持', '过于敏感', '难以决策', '缺乏计划'];
      default:
        return ['需要改进的方面', '发展空间', '潜在挑战'];
    }
  }

  // 保存测试结果到后端
  static Future<void> saveTestResult(MbtiTestResult result) async {
    try {
      // 准备符合后端API格式的数据
      final requestData = {
        'mbti_type': result.mbtiType,
        'test_scores': {
          'E': result.scores['E'] ?? 0,
          'I': result.scores['I'] ?? 0,
          'S': result.scores['S'] ?? 0,
          'N': result.scores['N'] ?? 0,
          'T': result.scores['T'] ?? 0,
          'F': result.scores['F'] ?? 0,
          'J': result.scores['J'] ?? 0,
          'P': result.scores['P'] ?? 0,
          'total_score': result.scores['total_score'] ?? 
            ((result.scores['E'] ?? 0) + (result.scores['I'] ?? 0) +
             (result.scores['S'] ?? 0) + (result.scores['N'] ?? 0) +
             (result.scores['T'] ?? 0) + (result.scores['F'] ?? 0) +
             (result.scores['J'] ?? 0) + (result.scores['P'] ?? 0)),
        },
        'personality_traits': result.personalityTraits,
        'test_version': result.testVersion,
        'personal_info': {
          'test_date': result.testDate.toIso8601String().split('T')[0],
        },
      };

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/mbti-records'),
        headers: ApiService.getAuthHeaders(),
        body: jsonEncode(requestData),
      );

      if (response.statusCode != 201) {
        final errorBody = response.body;
        throw Exception('保存测试结果失败: $errorBody');
      }
    } catch (e) {
      throw Exception('保存测试结果时发生错误: $e');
    }
  }

  // 获取用户最新的MBTI测试结果
  static Future<MbtiTestResult?> getUserLatestMbti() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records/latest'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return MbtiTestResult.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('获取MBTI测试结果失败: $e');
      return null;
    }
  }

  // 获取用户的MBTI测试历史
  static Future<List<MbtiTestResult>> getUserMbtiHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/mbti-records'),
        headers: ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MbtiTestResult.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('获取MBTI测试历史失败: $e');
      return [];
    }
  }

  // 验证测试结果
  static bool validateTestResult(MbtiTestResult result) {
    // 检查MBTI类型格式
    if (!RegExp(r'^[EI][SN][TF][JP]$').hasMatch(result.mbtiType)) {
      return false;
    }

    // 检查分数是否合理
    final totalScore = result.scores.values.fold(0, (sum, score) => sum + score);
    if (totalScore < 10 || totalScore > 100) {
      return false;
    }

    // 检查置信度
    if (result.confidenceScore < 0.0 || result.confidenceScore > 1.0) {
      return false;
    }

    return true;
  }
}
