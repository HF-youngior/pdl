import '../models/mbti_question.dart';

class MbtiQuestionsData {
  static const List<MbtiQuestion> questions = [
    // E/I 维度题目 (23题)
    MbtiQuestion(
      questionNumber: 1,
      question: "在聚会中，你更倾向于：",
      options: ["主动与陌生人交谈", "与熟悉的朋友深入交流"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 2,
      question: "你更喜欢的工作方式是：",
      options: ["团队合作，集思广益", "独立工作，专注思考"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 3,
      question: "在社交场合，你通常：",
      options: ["主动发起对话", "等待别人主动交谈"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 4,
      question: "你更愿意：",
      options: ["参加大型聚会", "与几个亲密朋友聚会"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 5,
      question: "在团队中，你更倾向于：",
      options: ["成为焦点和领导者", "在幕后提供支持"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 6,
      question: "你更喜欢的学习方式是：",
      options: ["小组讨论和互动", "独自阅读和思考"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 7,
      question: "在压力下，你更愿意：",
      options: ["与他人讨论问题", "独自思考解决方案"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 8,
      question: "你更享受：",
      options: ["充满活力的环境", "安静平和的环境"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 9,
      question: "在会议中，你通常：",
      options: ["积极发言和参与", "仔细倾听和观察"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 10,
      question: "你更喜欢：",
      options: ["快速做出决定", "深思熟虑后决定"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 11,
      question: "在假期中，你更愿意：",
      options: ["参加各种活动", "在家休息和放松"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 12,
      question: "你更倾向于：",
      options: ["表达自己的想法", "倾听他人的想法"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 13,
      question: "在解决问题时，你更喜欢：",
      options: ["与他人讨论", "独自思考"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 14,
      question: "你更愿意：",
      options: ["成为众人关注的焦点", "保持低调"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 15,
      question: "在社交活动中，你通常：",
      options: ["主动认识新朋友", "与熟悉的人交流"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 16,
      question: "你更喜欢：",
      options: ["外向的活动", "内向的活动"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 17,
      question: "在团队项目中，你更愿意：",
      options: ["担任领导角色", "担任支持角色"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 18,
      question: "你更倾向于：",
      options: ["主动分享经验", "等待被询问"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 19,
      question: "在社交场合，你更愿意：",
      options: ["成为话题的中心", "观察和倾听"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 20,
      question: "你更喜欢：",
      options: ["与他人一起工作", "独立完成工作"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 21,
      question: "在压力下，你更愿意：",
      options: ["寻求他人的支持", "独自处理"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 22,
      question: "你更倾向于：",
      options: ["主动发起活动", "参与他人组织的活动"],
      dimension: "EI",
    ),
    MbtiQuestion(
      questionNumber: 23,
      question: "在社交网络中，你更愿意：",
      options: ["扩大社交圈", "维持深度友谊"],
      dimension: "EI",
    ),

    // S/N 维度题目 (23题)
    MbtiQuestion(
      questionNumber: 24,
      question: "你更关注：",
      options: ["具体的事实和细节", "可能性和概念"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 25,
      question: "你更喜欢：",
      options: ["按部就班地工作", "灵活地适应变化"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 26,
      question: "在解决问题时，你更倾向于：",
      options: ["使用已知的方法", "寻找新的解决方案"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 27,
      question: "你更重视：",
      options: ["实际经验", "理论理解"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 28,
      question: "你更喜欢：",
      options: ["明确具体的指示", "开放性的指导"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 29,
      question: "在规划时，你更愿意：",
      options: ["制定详细的计划", "保持大致的想法"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 30,
      question: "你更倾向于：",
      options: ["关注当下", "思考未来"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 31,
      question: "你更喜欢：",
      options: ["具体的数据", "抽象的概念"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 32,
      question: "在决策时，你更依赖：",
      options: ["过去的经验", "直觉和灵感"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 33,
      question: "你更愿意：",
      options: ["遵循既定的程序", "创造新的方法"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 34,
      question: "你更关注：",
      options: ["现实情况", "潜在可能性"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 35,
      question: "你更喜欢：",
      options: ["稳定的环境", "变化的环境"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 36,
      question: "在解决问题时，你更愿意：",
      options: ["使用传统方法", "尝试创新方法"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 37,
      question: "你更重视：",
      options: ["实用性", "创新性"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 38,
      question: "你更喜欢：",
      options: ["具体的事实", "抽象的理论"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 39,
      question: "在规划时，你更愿意：",
      options: ["关注细节", "关注大局"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 40,
      question: "你更倾向于：",
      options: ["按部就班", "随机应变"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 41,
      question: "你更喜欢：",
      options: ["确定的结果", "开放的可能性"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 42,
      question: "在决策时，你更依赖：",
      options: ["具体信息", "直觉感受"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 43,
      question: "你更愿意：",
      options: ["遵循规则", "打破常规"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 44,
      question: "你更关注：",
      options: ["现在的情况", "未来的发展"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 45,
      question: "你更喜欢：",
      options: ["实际的应用", "理论的研究"],
      dimension: "SN",
    ),
    MbtiQuestion(
      questionNumber: 46,
      question: "在解决问题时，你更愿意：",
      options: ["使用现有资源", "寻找新资源"],
      dimension: "SN",
    ),

    // T/F 维度题目 (23题)
    MbtiQuestion(
      questionNumber: 47,
      question: "在决策时，你更重视：",
      options: ["逻辑和客观分析", "价值观和人际关系"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 48,
      question: "你更倾向于：",
      options: ["公正和公平", "和谐和理解"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 49,
      question: "在批评时，你更愿意：",
      options: ["直接指出问题", "温和地提出建议"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 50,
      question: "你更重视：",
      options: ["真理和准确性", "和谐和关系"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 51,
      question: "在团队中，你更愿意：",
      options: ["保持客观", "考虑他人感受"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 52,
      question: "你更喜欢：",
      options: ["逻辑推理", "情感共鸣"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 53,
      question: "在解决问题时，你更愿意：",
      options: ["分析事实", "考虑影响"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 54,
      question: "你更倾向于：",
      options: ["客观判断", "主观理解"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 55,
      question: "在决策时，你更依赖：",
      options: ["数据和证据", "直觉和感受"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 56,
      question: "你更愿意：",
      options: ["坚持原则", "灵活变通"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 57,
      question: "在冲突中，你更愿意：",
      options: ["理性分析", "情感理解"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 58,
      question: "你更重视：",
      options: ["效率和结果", "过程和关系"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 59,
      question: "在评价时，你更愿意：",
      options: ["客观标准", "个人感受"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 60,
      question: "你更喜欢：",
      options: ["逻辑思维", "情感思维"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 61,
      question: "在决策时，你更愿意：",
      options: ["分析利弊", "考虑感受"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 62,
      question: "你更倾向于：",
      options: ["公正无私", "同情理解"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 63,
      question: "在解决问题时，你更愿意：",
      options: ["寻找最佳方案", "考虑各方感受"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 64,
      question: "你在判断时更看重：",
      options: ["事实真相", "人际关系"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 65,
      question: "在团队中，你更愿意：",
      options: ["保持距离", "建立联系"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 66,
      question: "你更喜欢：",
      options: ["理性分析", "情感表达"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 67,
      question: "在决策时，你更依赖：",
      options: ["客观标准", "主观价值"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 68,
      question: "你更愿意：",
      options: ["坚持立场", "妥协让步"],
      dimension: "TF",
    ),
    MbtiQuestion(
      questionNumber: 69,
      question: "在评价时，你更愿意：",
      options: ["客观公正", "主观理解"],
      dimension: "TF",
    ),

    // J/P 维度题目 (24题)
    MbtiQuestion(
      questionNumber: 70,
      question: "你更喜欢：",
      options: ["有计划的安排", "灵活的安排"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 71,
      question: "在决策时，你更愿意：",
      options: ["快速决定", "保持开放"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 72,
      question: "你更倾向于：",
      options: ["按计划行事", "随机应变"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 73,
      question: "你更喜欢：",
      options: ["确定的结果", "开放的可能性"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 74,
      question: "在规划时，你更愿意：",
      options: ["制定详细计划", "保持大致想法"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 75,
      question: "你更倾向于：",
      options: ["控制过程", "享受过程"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 76,
      question: "你更喜欢：",
      options: ["有明确的目标", "保持开放的心态"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 77,
      question: "在规划时，你更愿意：",
      options: ["制定详细的计划", "保持大致的想法"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 78,
      question: "你更倾向于：",
      options: ["按部就班", "随机应变"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 79,
      question: "你更喜欢：",
      options: ["有明确的结果", "保持可能性"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 80,
      question: "在决策时，你更愿意：",
      options: ["做出最终决定", "保持选择开放"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 81,
      question: "你更倾向于：",
      options: ["控制过程", "享受过程"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 82,
      question: "你更喜欢：",
      options: ["有明确的目标", "保持开放的心态"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 83,
      question: "在规划时，你更愿意：",
      options: ["制定详细的计划", "保持大致的想法"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 84,
      question: "你更倾向于：",
      options: ["按部就班", "随机应变"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 85,
      question: "你更喜欢：",
      options: ["有明确的结果", "保持可能性"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 86,
      question: "在决策时，你更愿意：",
      options: ["做出最终决定", "保持选择开放"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 87,
      question: "你更倾向于：",
      options: ["控制过程", "享受过程"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 88,
      question: "你更喜欢：",
      options: ["有明确的目标", "保持开放的心态"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 89,
      question: "在规划时，你更愿意：",
      options: ["制定详细的计划", "保持大致的想法"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 90,
      question: "你更倾向于：",
      options: ["按部就班", "随机应变"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 91,
      question: "你更喜欢：",
      options: ["有明确的结果", "保持可能性"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 92,
      question: "在决策时，你更愿意：",
      options: ["做出最终决定", "保持选择开放"],
      dimension: "JP",
    ),
    MbtiQuestion(
      questionNumber: 93,
      question: "你更倾向于：",
      options: ["控制过程", "享受过程"],
      dimension: "JP",
    ),
  ];

  // 获取特定维度的题目
  static List<MbtiQuestion> getQuestionsByDimension(String dimension) {
    return questions.where((q) => q.dimension == dimension).toList();
  }

  // 获取特定题目的索引
  static int getQuestionIndex(int questionNumber) {
    return questions.indexWhere((q) => q.questionNumber == questionNumber);
  }

  // 获取题目总数
  static int get totalQuestions => questions.length;

  // 获取各维度的题目数量
  static Map<String, int> get dimensionCounts {
    final counts = <String, int>{};
    for (final question in questions) {
      counts[question.dimension] = (counts[question.dimension] ?? 0) + 1;
    }
    return counts;
  }
}
