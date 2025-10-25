// 后端API示例 - 集成DeepSeek API
// 文件位置: backend/ai_routes.js

const express = require('express');
const axios = require('axios');
const router = express.Router();

// DeepSeek API 配置
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || 'your-deepseek-api-key';
const DEEPSEEK_API_URL = 'https://api.deepseek.com/v1/chat/completions';

// 词云分析历史存储（实际项目中应使用数据库）
let wordCloudHistory = [];
let personalityHistory = [];

// 保存词云分析结果
router.post('/save-wordcloud', async (req, res) => {
  try {
    const { analysisDate, keywords, wordFrequencies, description } = req.body;
    
    const analysis = {
      id: Date.now().toString(),
      userId: req.user?.id || 'default_user',
      analysisDate: new Date(analysisDate),
      keywords,
      wordFrequencies,
      createdAt: new Date(),
      description,
    };
    
    wordCloudHistory.unshift(analysis);
    
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 获取词云分析历史
router.get('/wordcloud-history', async (req, res) => {
  try {
    const userId = req.user?.id || 'default_user';
    const userHistory = wordCloudHistory.filter(item => item.userId === userId);
    res.json(userHistory);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 分析今日日志（仅今日）
router.get('/analyze-today-only', async (req, res) => {
  try {
    const { topK = 20 } = req.query;
    const userId = req.user?.id || 'default_user';
    
    // 获取今日日志
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const logs = await getLogsByDateRange(userId, today, tomorrow);
    
    if (logs.length === 0) {
      return res.json({
        keywords: [],
        wordFrequencies: [],
        message: '今日没有日志记录'
      });
    }
    
    // 合并今日所有日志内容
    const allText = logs.map(log => 
      `${log.action} ${log.description} ${log.category}`
    ).join(' ');
    
    // 进行词频分析
    const analysis = await analyzeText(allText, topK);
    
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DeepSeek API 性格分析
router.post('/personality-analysis', async (req, res) => {
  try {
    const { logText, mbtiType, useDeepSeek } = req.body;
    
    let analysisResult;
    
    if (useDeepSeek && DEEPSEEK_API_KEY) {
      // 使用DeepSeek API进行性格分析
      analysisResult = await analyzePersonalityWithDeepSeek(logText, mbtiType);
    } else {
      // 使用本地算法进行性格分析
      analysisResult = await analyzePersonalityLocally(logText, mbtiType);
    }
    
    const analysis = {
      id: Date.now().toString(),
      userId: req.user?.id || 'default_user',
      analysisDate: new Date(),
      personalityTraits: analysisResult.personalityTraits,
      mbtiType: analysisResult.mbtiType,
      workSuggestions: analysisResult.workSuggestions,
      personalityChart: analysisResult.personalityChart,
      createdAt: new Date(),
      description: 'AI性格分析报告',
    };
    
    personalityHistory.unshift(analysis);
    
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 获取性格分析历史
router.get('/personality-history', async (req, res) => {
  try {
    const userId = req.user?.id || 'default_user';
    const userHistory = personalityHistory.filter(item => item.userId === userId);
    res.json(userHistory);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DeepSeek API 性格分析函数
async function analyzePersonalityWithDeepSeek(logText, mbtiType) {
  const prompt = `
请基于以下日志内容进行性格分析：

日志内容：${logText}

${mbtiType ? `已知MBTI类型：${mbtiType}` : ''}

请分析并返回以下格式的JSON数据：
{
  "personalityTraits": {
    "外向性": 0.8,
    "宜人性": 0.6,
    "尽责性": 0.9,
    "神经质": 0.3,
    "开放性": 0.7
  },
  "mbtiType": "ENFP",
  "workSuggestions": {
    "适合职业": ["产品经理", "市场营销", "创意总监"],
    "工作环境": "开放、创新、团队合作",
    "发展建议": "发挥创造力，加强执行力",
    "沟通风格": "热情、富有感染力"
  },
  "personalityChart": {
    "traits": {
      "外向性": 0.8,
      "宜人性": 0.6,
      "尽责性": 0.9,
      "神经质": 0.3,
      "开放性": 0.7
    },
    "dimensions": {
      "领导力": 0.8,
      "创造力": 0.7,
      "沟通能力": 0.9,
      "分析能力": 0.6,
      "团队合作": 0.8
    }
  }
}
`;

  try {
    const response = await axios.post(DEEPSEEK_API_URL, {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'system',
          content: '你是一个专业的性格分析师，擅长基于日志内容进行MBTI性格分析和职业建议。请返回有效的JSON格式数据。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 2000
    }, {
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });

    const content = response.data.choices[0].message.content;
    
    // 尝试解析JSON响应
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
    } catch (parseError) {
      console.error('JSON解析失败:', parseError);
    }
    
    // 如果解析失败，返回默认分析结果
    return getDefaultPersonalityAnalysis();
    
  } catch (error) {
    console.error('DeepSeek API调用失败:', error);
    return getDefaultPersonalityAnalysis();
  }
}

// 本地性格分析函数（备用方案）
async function analyzePersonalityLocally(logText, mbtiType) {
  // 这里可以实现基于关键词的简单性格分析
  // 或者调用其他AI服务
  
  return getDefaultPersonalityAnalysis();
}

// 默认性格分析结果
function getDefaultPersonalityAnalysis() {
  return {
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
      traits: {
        '外向性': 0.8,
        '宜人性': 0.6,
        '尽责性': 0.9,
        '神经质': 0.3,
        '开放性': 0.7,
      },
      dimensions: {
        '领导力': 0.8,
        '创造力': 0.7,
        '沟通能力': 0.9,
        '分析能力': 0.6,
        '团队合作': 0.8,
      },
    },
  };
}

module.exports = router;
