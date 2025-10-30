class MbtiTestResult {
  final String mbtiType;
  final Map<String, int> scores;
  final Map<String, String> personalityTraits;
  final DateTime testDate;
  final String testVersion;
  final double confidenceScore;
  final List<String> strengths;
  final List<String> weaknesses;

  const MbtiTestResult({
    required this.mbtiType,
    required this.scores,
    required this.personalityTraits,
    required this.testDate,
    required this.testVersion,
    required this.confidenceScore,
    required this.strengths,
    required this.weaknesses,
  });

  factory MbtiTestResult.fromJson(Map<String, dynamic> json) {
    return MbtiTestResult(
      mbtiType: json['mbti_type'] ?? json['mbtiType'] ?? '',
      scores: Map<String, int>.from(json['test_scores'] ?? json['scores'] ?? {}),
      personalityTraits: Map<String, String>.from(json['personality_traits'] ?? json['personalityTraits'] ?? {}),
      testDate: DateTime.parse(json['test_date'] ?? json['testDate'] ?? DateTime.now().toIso8601String()),
      testVersion: json['test_version'] ?? json['testVersion'] ?? 'v1.0',
      confidenceScore: (json['confidence_score'] ?? json['confidenceScore'] ?? 0.0).toDouble(),
      strengths: List<String>.from(json['strengths'] ?? []),
      weaknesses: List<String>.from(json['weaknesses'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mbti_type': mbtiType,
      'test_scores': scores,
      'personality_traits': personalityTraits,
      'test_date': testDate.toIso8601String(),
      'test_version': testVersion,
      'confidence_score': confidenceScore,
      'strengths': strengths,
      'weaknesses': weaknesses,
    };
  }

  // 获取主要性格特征
  String get primaryTrait {
    switch (mbtiType) {
      case 'INTJ':
        return '建筑师 - 富有想象力和战略性的思想家';
      case 'INTP':
        return '思想家 - 具有创新精神的发明家';
      case 'ENTJ':
        return '指挥官 - 大胆、富有想象力的意志强大的领导者';
      case 'ENTP':
        return '辩论家 - 聪明好奇的思想家';
      case 'INFJ':
        return '提倡者 - 安静而神秘，鼓舞人心且不知疲倦的理想主义者';
      case 'INFP':
        return '调停者 - 富有诗意、善良且利他主义的人';
      case 'ENFJ':
        return '主人公 - 富有魅力、鼓舞人心的领导者';
      case 'ENFP':
        return '竞选者 - 热情、有创造力、社交能力强的人';
      case 'ISTJ':
        return '物流师 - 实用且注重事实，可靠性无可争议';
      case 'ISFJ':
        return '守护者 - 非常专注和温暖的守护者';
      case 'ESTJ':
        return '总经理 - 出色的管理者，在管理事务或人员方面无与伦比';
      case 'ESFJ':
        return '执政官 - 极有同情心、受欢迎且总是热心的人';
      case 'ISTP':
        return '鉴赏家 - 大胆而实用的实验家';
      case 'ISFP':
        return '探险家 - 灵活有魅力的艺术家';
      case 'ESTP':
        return '企业家 - 聪明、精力充沛、善于感知的人';
      case 'ESFP':
        return '娱乐家 - 自发的、精力充沛且热情的人';
      default:
        return '未知类型';
    }
  }

  // 获取详细描述
  String get description {
    switch (mbtiType) {
      case 'INTJ':
        return 'INTJ是富有想象力和战略性的思想家，一切皆在计划之中。他们以怀疑的眼光看待一切，这使他们能够发现改进系统的方法。';
      case 'INTP':
        return 'INTP是具有创新精神的发明家，对知识有着不可抑制的渴望。他们可能看起来安静、矜持，但内心有着强烈的求知欲。';
      case 'ENTJ':
        return 'ENTJ是大胆、富有想象力的意志强大的领导者，总是能找到或创造解决方法。他们天生具有领导能力。';
      case 'ENTP':
        return 'ENTP是聪明好奇的思想家，不会放弃智力挑战。他们喜欢智力上的挑战，善于发现可能性。';
      case 'INFJ':
        return 'INFJ是安静而神秘，鼓舞人心且不知疲倦的理想主义者。他们具有强烈的价值观和道德感。';
      case 'INFP':
        return 'INFP是富有诗意、善良且利他主义的人，总是热切地想要帮助正当的事业。他们重视真实性和个人成长。';
      case 'ENFJ':
        return 'ENFJ是富有魅力、鼓舞人心的领导者，具有感染他人的能力。他们天生具有领导魅力。';
      case 'ENFP':
        return 'ENFP是热情、有创造力、社交能力强的人，总是能找到微笑的理由。他们充满活力和热情。';
      case 'ISTJ':
        return 'ISTJ是实用且注重事实，可靠性无可争议。他们以负责任和可靠著称。';
      case 'ISFJ':
        return 'ISFJ是非常专注和温暖的守护者，总是准备保护所爱的人。他们具有强烈的保护欲。';
      case 'ESTJ':
        return 'ESTJ是出色的管理者，在管理事务或人员方面无与伦比。他们以高效和组织能力著称。';
      case 'ESFJ':
        return 'ESFJ是极有同情心、受欢迎且总是热心的人。他们以关心他人和社交能力著称。';
      case 'ISTP':
        return 'ISTP是大胆而实用的实验家，擅长使用各种工具。他们以实用性和灵活性著称。';
      case 'ISFP':
        return 'ISFP是灵活有魅力的艺术家，总是准备探索新的可能性。他们以创造力和适应性著称。';
      case 'ESTP':
        return 'ESTP是聪明、精力充沛、善于感知的人，真正享受生活在边缘。他们以活力和冒险精神著称。';
      case 'ESFP':
        return 'ESFP是自发的、精力充沛且热情的人，生活永远不会无聊。他们以乐观和社交能力著称。';
      default:
        return '这是一个独特的性格类型，具有自己的特点和优势。';
    }
  }
}
