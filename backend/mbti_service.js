// MBTI记录服务模块
// 提供MBTI记录的业务逻辑处理

const { v4: uuidv4 } = require('uuid');

class MbtiService {
  /**
   * 创建MBTI记录
   * @param {Object} recordData - MBTI记录数据
   * @param {string} userId - 用户ID
   * @returns {Object} 创建的记录
   */
  static async createRecord(recordData, userId) {
    const {
      mbti_type,
      test_scores,
      personality_traits,
      ai_analysis,
      work_suggestions,
      improvement_advice,
      personal_info,
      test_version = 'v1.0',
      confidence_score = 0.0
    } = recordData;

    // 验证必填字段
    if (!mbti_type || !test_scores || !personality_traits || !ai_analysis || !work_suggestions) {
      throw new Error('缺少必填字段');
    }

    // 验证MBTI类型格式
    if (!/^[EI][NS][TF][JP]$/.test(mbti_type)) {
      throw new Error('MBTI类型格式不正确');
    }

    // 验证置信度分数
    if (confidence_score < 0 || confidence_score > 1) {
      throw new Error('置信度分数必须在0-1之间');
    }

    const id = `mbti-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    return {
      id,
      user_id: userId,
      mbti_type,
      test_scores: JSON.stringify(test_scores),
      personality_traits: JSON.stringify(personality_traits),
      ai_analysis: JSON.stringify(ai_analysis),
      work_suggestions: JSON.stringify(work_suggestions),
      improvement_advice: improvement_advice ? JSON.stringify(improvement_advice) : null,
      personal_info: personal_info ? JSON.stringify(personal_info) : null,
      test_version,
      confidence_score,
      created_at: new Date()
    };
  }

  /**
   * 验证MBTI测试数据
   * @param {Object} testData - 测试数据
   * @returns {Object} 验证结果
   */
  static validateTestData(testData) {
    const errors = [];

    // 验证MBTI类型
    if (!testData.mbti_type || !/^[EI][NS][TF][JP]$/.test(testData.mbti_type)) {
      errors.push('MBTI类型格式不正确');
    }

    // 验证测试分数
    if (!testData.test_scores || typeof testData.test_scores !== 'object') {
      errors.push('测试分数数据格式不正确');
    } else {
      const requiredScores = ['E', 'N', 'F', 'P'];
      for (const score of requiredScores) {
        if (typeof testData.test_scores[score] !== 'number' || 
            testData.test_scores[score] < 0 || 
            testData.test_scores[score] > 100) {
          errors.push(`${score}维度分数必须在0-100之间`);
        }
      }
    }

    // 验证性格特质
    if (!testData.personality_traits || typeof testData.personality_traits !== 'object') {
      errors.push('性格特质数据格式不正确');
    }

    // 验证AI分析
    if (!testData.ai_analysis || typeof testData.ai_analysis !== 'object') {
      errors.push('AI分析数据格式不正确');
    }

    // 验证工作建议
    if (!testData.work_suggestions || typeof testData.work_suggestions !== 'object') {
      errors.push('工作建议数据格式不正确');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  /**
   * 生成AI分析建议
   * @param {string} mbtiType - MBTI类型
   * @param {Object} testScores - 测试分数
   * @param {Object} personalityTraits - 性格特质
   * @returns {Object} AI分析结果
   */
  static generateAiAnalysis(mbtiType, testScores, personalityTraits) {
    // 基于MBTI类型的AI分析逻辑
    const analysisTemplates = {
      'ENFP': {
        strengths: ['创新思维', '团队合作', '沟通能力', '适应性强'],
        weaknesses: ['细节处理', '时间管理', '决策果断性'],
        career_suitability: ['市场营销', '人力资源', '创意设计', '教育培训'],
        leadership_style: '民主型领导，善于激励团队',
        work_environment: '适合开放、灵活的工作环境',
        team_role: '团队协调者和创新推动者'
      },
      'INTJ': {
        strengths: ['战略思维', '独立性强', '逻辑分析', '执行力强'],
        weaknesses: ['人际交往', '情感表达', '灵活性'],
        career_suitability: ['战略规划', '技术研发', '管理咨询', '投资分析'],
        leadership_style: '愿景型领导，注重长远规划',
        work_environment: '适合独立、安静的工作环境',
        team_role: '战略规划者和技术专家'
      },
      'ISFJ': {
        strengths: ['责任心强', '细心周到', '团队合作', '稳定性'],
        weaknesses: ['创新思维', '决策果断性', '自我表达'],
        career_suitability: ['行政管理', '客户服务', '医疗护理', '教育培训'],
        leadership_style: '服务型领导，注重团队和谐',
        work_environment: '适合稳定、有序的工作环境',
        team_role: '支持者和协调者'
      }
      // 可以添加更多MBTI类型的分析模板
    };

    const template = analysisTemplates[mbtiType] || analysisTemplates['ENFP'];
    
    return {
      strengths: template.strengths,
      weaknesses: template.weaknesses,
      career_suitability: template.career_suitability,
      leadership_style: template.leadership_style,
      work_environment: template.work_environment,
      team_role: template.team_role,
      development_focus: [
        '提高专注力',
        '加强时间规划',
        '培养决策能力'
      ],
      learning_suggestions: [
        '学习项目管理',
        '培养批判性思维',
        '提升执行力'
      ],
      career_advice: `基于您的${mbtiType}性格类型，建议考虑从事需要${template.strengths[0]}和${template.strengths[1]}的工作`
    };
  }

  /**
   * 计算测试置信度
   * @param {Object} testScores - 测试分数
   * @returns {number} 置信度分数(0-1)
   */
  static calculateConfidenceScore(testScores) {
    const scores = Object.values(testScores).filter(score => typeof score === 'number');
    if (scores.length === 0) return 0;

    // 计算分数分布的方差，方差越小置信度越高
    const mean = scores.reduce((sum, score) => sum + score, 0) / scores.length;
    const variance = scores.reduce((sum, score) => sum + Math.pow(score - mean, 2), 0) / scores.length;
    
    // 将方差转换为置信度分数
    const maxVariance = 2500; // 假设最大方差为2500
    const confidence = Math.max(0, Math.min(1, 1 - (variance / maxVariance)));
    
    return Math.round(confidence * 100) / 100;
  }

  /**
   * 格式化MBTI记录用于显示
   * @param {Object} record - 原始记录
   * @returns {Object} 格式化后的记录
   */
  static formatRecordForDisplay(record) {
    const formatted = { ...record };
    
    // 解析JSON字段
    if (typeof formatted.test_scores === 'string') {
      formatted.test_scores = JSON.parse(formatted.test_scores);
    }
    if (typeof formatted.personality_traits === 'string') {
      formatted.personality_traits = JSON.parse(formatted.personality_traits);
    }
    if (typeof formatted.ai_analysis === 'string') {
      formatted.ai_analysis = JSON.parse(formatted.ai_analysis);
    }
    if (typeof formatted.work_suggestions === 'string') {
      formatted.work_suggestions = JSON.parse(formatted.work_suggestions);
    }
    if (formatted.improvement_advice && typeof formatted.improvement_advice === 'string') {
      formatted.improvement_advice = JSON.parse(formatted.improvement_advice);
    }
    if (formatted.personal_info && typeof formatted.personal_info === 'string') {
      formatted.personal_info = JSON.parse(formatted.personal_info);
    }

    return formatted;
  }
}

module.exports = MbtiService;
