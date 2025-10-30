// 简单测试MBTI记录创建
const axios = require('axios');

const API_URL = 'http://localhost:8080';

async function testMBTISimple() {
  try {
    console.log('🧪 简单测试MBTI记录创建...\n');

    // 1. admin登录
    console.log('1️⃣ admin登录...');
    const adminLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    const adminToken = adminLogin.data.token;
    console.log('✅ admin登录成功');

    // 2. 测试创建MBTI记录
    console.log('\n2️⃣ 测试创建MBTI记录...');
    const testMBTIData = {
      mbti_type: 'INFP',
      test_scores: {
        E: 20,
        I: 80,
        S: 30,
        N: 70,
        T: 25,
        F: 75,
        J: 40,
        P: 60,
        total_score: 400
      },
      personality_traits: {
        extroversion: '内向型，喜欢深度思考',
        sensing: '直觉型，关注可能性和意义',
        thinking: '情感型，重视价值观和感受',
        judging: '感知型，保持开放和灵活'
      },
      personal_info: {
        test_date: new Date().toISOString().split('T')[0],
        test_version: 'v1.0'
      },
      test_version: 'v1.0'
    };

    console.log('发送数据:', JSON.stringify(testMBTIData, null, 2));

    const createResponse = await axios.post(`${API_URL}/api/mbti-records`, testMBTIData, {
      headers: { 
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ MBTI记录创建成功');
    console.log('   响应:', createResponse.data);

  } catch (error) {
    console.error('❌ 测试失败:');
    if (error.response) {
      console.error('   状态码:', error.response.status);
      console.error('   错误信息:', error.response.data);
    } else {
      console.error('   错误:', error.message);
    }
  }
}

testMBTISimple();


