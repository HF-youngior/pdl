// MBTI测试题目数据 - 93道标准题目
const mbtiQuestions = [
    // E/I 维度题目 (23题)
    {
        question: "在聚会中，你更倾向于：",
        options: ["主动与陌生人交谈", "与熟悉的朋友深入交流"],
        dimension: "EI"
    },
    {
        question: "你更喜欢的工作方式是：",
        options: ["团队合作，集思广益", "独立工作，专注思考"],
        dimension: "EI"
    },
    {
        question: "在社交场合，你通常：",
        options: ["主动发起对话", "等待别人主动交谈"],
        dimension: "EI"
    },
    {
        question: "你更愿意：",
        options: ["参加大型聚会", "与几个亲密朋友聚会"],
        dimension: "EI"
    },
    {
        question: "在团队中，你更倾向于：",
        options: ["成为焦点和领导者", "在幕后提供支持"],
        dimension: "EI"
    },
    {
        question: "你更喜欢的学习方式是：",
        options: ["小组讨论和互动", "独自阅读和思考"],
        dimension: "EI"
    },
    {
        question: "在压力下，你更愿意：",
        options: ["与他人讨论问题", "独自思考解决方案"],
        dimension: "EI"
    },
    {
        question: "你更享受：",
        options: ["充满活力的环境", "安静平和的环境"],
        dimension: "EI"
    },
    {
        question: "在会议中，你通常：",
        options: ["积极发言和参与", "仔细倾听和观察"],
        dimension: "EI"
    },
    {
        question: "你更喜欢：",
        options: ["快速做出决定", "深思熟虑后决定"],
        dimension: "EI"
    },
    {
        question: "在假期中，你更愿意：",
        options: ["参加各种活动", "在家休息和放松"],
        dimension: "EI"
    },
    {
        question: "你更倾向于：",
        options: ["表达自己的想法", "倾听他人的观点"],
        dimension: "EI"
    },
    {
        question: "在解决问题时，你更喜欢：",
        options: ["与他人讨论", "独自分析"],
        dimension: "EI"
    },
    {
        question: "你更愿意：",
        options: ["成为关注的中心", "保持低调"],
        dimension: "EI"
    },
    {
        question: "在社交网络中，你通常：",
        options: ["主动联系朋友", "等待朋友联系你"],
        dimension: "EI"
    },
    {
        question: "你更喜欢的工作环境是：",
        options: ["开放式的办公空间", "私人的独立空间"],
        dimension: "EI"
    },
    {
        question: "在团队项目中，你更愿意：",
        options: ["领导整个项目", "负责具体的技术工作"],
        dimension: "EI"
    },
    {
        question: "你更倾向于：",
        options: ["快速行动", "仔细规划"],
        dimension: "EI"
    },
    {
        question: "在社交活动中，你通常：",
        options: ["认识很多新朋友", "与少数朋友深入交流"],
        dimension: "EI"
    },
    {
        question: "你更喜欢：",
        options: ["即兴发挥", "提前准备"],
        dimension: "EI"
    },
    {
        question: "在团队讨论中，你通常：",
        options: ["第一个发言", "最后总结发言"],
        dimension: "EI"
    },
    {
        question: "你更愿意：",
        options: ["在公众面前演讲", "在幕后策划"],
        dimension: "EI"
    },
    {
        question: "在社交场合，你更倾向于：",
        options: ["主动介绍自己", "等待别人介绍"],
        dimension: "EI"
    },

    // S/N 维度题目 (23题)
    {
        question: "在解决问题时，你更倾向于：",
        options: ["先行动，在实践中学习", "先分析，制定详细计划"],
        dimension: "SN"
    },
    {
        question: "你更关注：",
        options: ["具体的事实和细节", "可能性和潜在意义"],
        dimension: "SN"
    },
    {
        question: "你更喜欢：",
        options: ["按部就班的工作", "创新和变化的工作"],
        dimension: "SN"
    },
    {
        question: "在制定计划时，你更注重：",
        options: ["具体的步骤和时间表", "总体目标和愿景"],
        dimension: "SN"
    },
    {
        question: "你更愿意：",
        options: ["遵循既定的程序", "创造新的方法"],
        dimension: "SN"
    },
    {
        question: "在阅读时，你更喜欢：",
        options: ["实用性的内容", "理论性的内容"],
        dimension: "SN"
    },
    {
        question: "你更关注：",
        options: ["现在和过去", "未来和可能性"],
        dimension: "SN"
    },
    {
        question: "在决策时，你更依赖：",
        options: ["经验和事实", "直觉和灵感"],
        dimension: "SN"
    },
    {
        question: "你更喜欢：",
        options: ["具体明确的指示", "灵活自由的空间"],
        dimension: "SN"
    },
    {
        question: "在学习新技能时，你更愿意：",
        options: ["通过实践练习", "通过理论学习"],
        dimension: "SN"
    },
    {
        question: "你更关注：",
        options: ["现实和实际", "理想和想象"],
        dimension: "SN"
    },
    {
        question: "在描述事物时，你更倾向于：",
        options: ["具体和详细", "抽象和概括"],
        dimension: "SN"
    },
    {
        question: "你更喜欢：",
        options: ["稳定的环境", "变化的环境"],
        dimension: "SN"
    },
    {
        question: "在解决问题时，你更愿意：",
        options: ["使用已知的方法", "尝试新的方法"],
        dimension: "SN"
    },
    {
        question: "你更关注：",
        options: ["细节和具体", "整体和概念"],
        dimension: "SN"
    },
    {
        question: "在规划时，你更注重：",
        options: ["具体的实施步骤", "总体目标和方向"],
        dimension: "SN"
    },
    {
        question: "你更喜欢：",
        options: ["传统的方法", "创新的方法"],
        dimension: "SN"
    },
    {
        question: "在描述经历时，你更倾向于：",
        options: ["具体的事实", "感受和意义"],
        dimension: "SN"
    },
    {
        question: "你更愿意：",
        options: ["按照既定规则", "创造新的规则"],
        dimension: "SN"
    },
    {
        question: "在思考时，你更关注：",
        options: ["具体的情况", "抽象的概念"],
        dimension: "SN"
    },
    {
        question: "你更喜欢：",
        options: ["实际的应用", "理论的研究"],
        dimension: "SN"
    },
    {
        question: "在描述问题时，你更倾向于：",
        options: ["具体的事实", "潜在的原因"],
        dimension: "SN"
    },
    {
        question: "你更愿意：",
        options: ["维护现状", "推动变革"],
        dimension: "SN"
    },
    {
        question: "在分析时，你更关注：",
        options: ["具体的细节", "整体的模式"],
        dimension: "SN"
    },

    // T/F 维度题目 (23题)
    {
        question: "做决定时，你更依赖：",
        options: ["逻辑分析和客观标准", "个人价值观和他人感受"],
        dimension: "TF"
    },
    {
        question: "你更重视：",
        options: ["公平和公正", "和谐和理解"],
        dimension: "TF"
    },
    {
        question: "在评价他人时，你更注重：",
        options: ["能力和表现", "动机和努力"],
        dimension: "TF"
    },
    {
        question: "你更愿意：",
        options: ["直接指出问题", "委婉地表达意见"],
        dimension: "TF"
    },
    {
        question: "在团队中，你更关注：",
        options: ["任务完成情况", "团队关系和谐"],
        dimension: "TF"
    },
    {
        question: "你更倾向于：",
        options: ["客观分析", "主观感受"],
        dimension: "TF"
    },
    {
        question: "在批评时，你更愿意：",
        options: ["直接指出错误", "鼓励改进"],
        dimension: "TF"
    },
    {
        question: "你更重视：",
        options: ["真理和事实", "关系和和谐"],
        dimension: "TF"
    },
    {
        question: "在决策时，你更考虑：",
        options: ["逻辑和效率", "影响和感受"],
        dimension: "TF"
    },
    {
        question: "你更愿意：",
        options: ["坚持原则", "照顾他人感受"],
        dimension: "TF"
    },
    {
        question: "在评价工作时，你更注重：",
        options: ["结果和效率", "过程和努力"],
        dimension: "TF"
    },
    {
        question: "你更倾向于：",
        options: ["理性思考", "感性理解"],
        dimension: "TF"
    },
    {
        question: "在冲突中，你更愿意：",
        options: ["分析对错", "寻求理解"],
        dimension: "TF"
    },
    {
        question: "你更重视：",
        options: ["客观标准", "主观价值"],
        dimension: "TF"
    },
    {
        question: "在评价方案时，你更注重：",
        options: ["逻辑性和可行性", "影响和感受"],
        dimension: "TF"
    },
    {
        question: "你更愿意：",
        options: ["追求真理", "维护关系"],
        dimension: "TF"
    },
    {
        question: "在团队中，你更关注：",
        options: ["任务目标", "人际关系"],
        dimension: "TF"
    },
    {
        question: "你更倾向于：",
        options: ["客观判断", "主观理解"],
        dimension: "TF"
    },
    {
        question: "在评价他人时，你更注重：",
        options: ["能力和表现", "品格和动机"],
        dimension: "TF"
    },
    {
        question: "你更愿意：",
        options: ["坚持立场", "寻求妥协"],
        dimension: "TF"
    },
    {
        question: "在决策时，你更考虑：",
        options: ["逻辑分析", "情感因素"],
        dimension: "TF"
    },
    {
        question: "你更重视：",
        options: ["公正和公平", "关怀和理解"],
        dimension: "TF"
    },
    {
        question: "在评价问题时，你更注重：",
        options: ["客观事实", "主观感受"],
        dimension: "TF"
    },

    // J/P 维度题目 (24题)
    {
        question: "你更喜欢的生活方式是：",
        options: ["有计划、有秩序", "灵活、随性"],
        dimension: "JP"
    },
    {
        question: "面对截止日期，你通常：",
        options: ["提前完成，留有余地", "在最后期限前完成"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["确定性和可预测性", "灵活性和自发性"],
        dimension: "JP"
    },
    {
        question: "在制定计划时，你更愿意：",
        options: ["详细规划每个步骤", "保持大致的框架"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["按计划执行", "根据情况调整"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有明确目标", "保持开放态度"],
        dimension: "JP"
    },
    {
        question: "在旅行时，你更愿意：",
        options: ["提前预订和规划", "随性而行"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["完成一件事再做下一件", "同时处理多件事"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有规律的生活", "变化的生活"],
        dimension: "JP"
    },
    {
        question: "在决策时，你更愿意：",
        options: ["快速做出决定", "保持开放态度"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["控制局面", "适应环境"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有明确的时间表", "灵活的时间安排"],
        dimension: "JP"
    },
    {
        question: "在项目中，你更愿意：",
        options: ["按计划推进", "根据灵感调整"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["提前准备", "即兴发挥"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有明确的结果", "保持可能性"],
        dimension: "JP"
    },
    {
        question: "在安排时间时，你更愿意：",
        options: ["制定详细的日程", "保持灵活的安排"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["完成和结束", "开始和探索"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有秩序的环境", "自由的环境"],
        dimension: "JP"
    },
    {
        question: "在决策时，你更愿意：",
        options: ["做出最终决定", "保持选择开放"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["控制过程", "享受过程"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有明确的目标", "保持开放的心态"],
        dimension: "JP"
    },
    {
        question: "在规划时，你更愿意：",
        options: ["制定详细的计划", "保持大致的想法"],
        dimension: "JP"
    },
    {
        question: "你更倾向于：",
        options: ["按部就班", "随机应变"],
        dimension: "JP"
    },
    {
        question: "你更喜欢：",
        options: ["有明确的结果", "保持可能性"],
        dimension: "JP"
    }
];

// 导出数据
if (typeof module !== 'undefined' && module.exports) {
    module.exports = mbtiQuestions;
}
