class PersonalityAnalysis {
  final String id;
  final String userId;
  final DateTime analysisDate;
  final Map<String, dynamic> personalityTraits;
  final String mbtiType;
  final Map<String, dynamic> workSuggestions;
  final Map<String, dynamic> personalityChart;
  final DateTime createdAt;
  final String? description;
  final String? aiAnalysisText; // DeepSeek API返回的原始分析文本
  final bool? isDeepSeek; // 标识是否使用DeepSeek API分析

  PersonalityAnalysis({
    required this.id,
    required this.userId,
    required this.analysisDate,
    required this.personalityTraits,
    required this.mbtiType,
    required this.workSuggestions,
    required this.personalityChart,
    required this.createdAt,
    this.description,
    this.aiAnalysisText,
    this.isDeepSeek,
  });

  factory PersonalityAnalysis.fromJson(Map<String, dynamic> json) {
    return PersonalityAnalysis(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      analysisDate: DateTime.parse(json['analysis_date'] ?? json['analysisDate']),
      personalityTraits: Map<String, dynamic>.from(json['personality_traits'] ?? json['personalityTraits'] ?? {}),
      mbtiType: json['mbti_type'] ?? json['mbtiType'] ?? '',
      workSuggestions: Map<String, dynamic>.from(json['work_suggestions'] ?? json['workSuggestions'] ?? {}),
      personalityChart: Map<String, dynamic>.from(json['personality_chart'] ?? json['personalityChart'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      description: json['description'],
      aiAnalysisText: json['ai_analysis_text'] ?? json['aiAnalysisText'],
      isDeepSeek: json['isDeepSeek'] ?? json['is_deep_seek'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'analysisDate': analysisDate.toIso8601String(),
      'personalityTraits': personalityTraits,
      'mbtiType': mbtiType,
      'workSuggestions': workSuggestions,
      'personalityChart': personalityChart,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      // 后端期望的字段名
      'user_id': userId,
      'analysis_date': analysisDate.toIso8601String(),
      'personality_traits': personalityTraits,
      'mbti_type': mbtiType,
      'work_suggestions': workSuggestions,
      'personality_chart': personalityChart,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
