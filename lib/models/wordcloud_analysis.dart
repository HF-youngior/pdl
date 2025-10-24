class WordCloudAnalysis {
  final String id;
  final String userId;
  final DateTime analysisDate;
  final List<Map<String, dynamic>> keywords;
  final List<Map<String, dynamic>> wordFrequencies;
  final DateTime createdAt;
  final String? description;

  WordCloudAnalysis({
    required this.id,
    required this.userId,
    required this.analysisDate,
    required this.keywords,
    required this.wordFrequencies,
    required this.createdAt,
    this.description,
  });

  factory WordCloudAnalysis.fromJson(Map<String, dynamic> json) {
    return WordCloudAnalysis(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      analysisDate: DateTime.parse(json['analysis_date'] ?? json['analysisDate']),
      keywords: (json['keywords'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      wordFrequencies: (json['word_frequencies'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'analysisDate': analysisDate.toIso8601String(),
      'keywords': keywords,
      'wordFrequencies': wordFrequencies,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      // 后端期望的字段名
      'user_id': userId,
      'analysis_date': analysisDate.toIso8601String(),
      'word_frequencies': wordFrequencies,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
