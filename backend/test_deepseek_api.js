// DeepSeek API 测试脚本
const axios = require('axios');
require('dotenv').config();

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const DEEPSEEK_API_URL = process.env.DEEPSEEK_API_URL || 'https://api.deepseek.com/v1/chat/completions';

async function testDeepSeekAPI() {
  console.log('开始测试DeepSeek API...');
  
  if (!DEEPSEEK_API_KEY) {
    console.error('❌ 错误：未找到DEEPSEEK_API_KEY环境变量');
    console.log('请在backend/.env文件中添加：DEEPSEEK_API_KEY=your-api-key-here');
    return;
  }
  
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
          content: '请分析以下日志内容：今天完成了项目会议，与团队成员讨论了新功能的设计方案，大家都很有创意，提出了很多好的想法。'
        }
      ],
      temperature: 0.7,
      max_tokens: 1000
    }, {
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: 30000
    });
    
    console.log('✅ DeepSeek API连接成功！');
    console.log('响应内容：', response.data.choices[0].message.content);
    
  } catch (error) {
    console.error('❌ DeepSeek API调用失败：', error.message);
    if (error.response) {
      console.error('响应状态：', error.response.status);
      console.error('响应数据：', error.response.data);
    }
  }
}

// 测试性格分析函数
async function testPersonalityAnalysis() {
  console.log('\n开始测试性格分析函数...');
  
  // 模拟分析函数
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
        },
        timeout: 30000
      });

      const content = response.data.choices[0].message.content;
      
      // 尝试解析JSON响应
      try {
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const result = JSON.parse(jsonMatch[0]);
          console.log('✅ 性格分析成功！');
          console.log('分析结果：', JSON.stringify(result, null, 2));
          return result;
        }
      } catch (parseError) {
        console.error('❌ JSON解析失败:', parseError);
      }
      
    } catch (error) {
      console.error('❌ 性格分析失败:', error.message);
    }
  }
  
  // 测试分析
  await analyzePersonalityWithDeepSeek(
    '今天完成了项目会议，与团队成员讨论了新功能的设计方案，大家都很有创意，提出了很多好的想法。',
    'ENFP'
  );
}

// 运行测试
async function runTests() {
  console.log('=== DeepSeek API 集成测试 ===\n');
  
  await testDeepSeekAPI();
  await testPersonalityAnalysis();
  
  console.log('\n=== 测试完成 ===');
  console.log('\n如果测试成功，说明DeepSeek API集成正常。');
  console.log('如果测试失败，请检查：');
  console.log('1. API Key是否正确');
  console.log('2. 网络连接是否正常');
  console.log('3. API额度是否充足');
}

runTests().catch(console.error);
