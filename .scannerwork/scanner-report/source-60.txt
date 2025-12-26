// 测试MBTI保存功能
const axios = require('axios');

const API_URL = 'http://localhost:8080';

async function testMbtiSave() {
  try {
    console.log('🧪 测试MBTI保存功能...\n');

    // 1. 登录获取token
    console.log('1️⃣ 用户登录...');
    const loginResponse = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    const token = loginResponse.data.token;
    console.log('✅ 登录成功');

    // 2. 测试保存MBTI记录
    console.log('\n2️⃣ 测试保存MBTI记录...');
    const testData = {
      mbti_type: 'ENFP',
      test_scores: {
        E: 75,
        I: 25,
        S: 30,
        N: 70,
        T: 40,
        F: 60,
        J: 35,
        P: 65,
        total_score: 400
      },
      personality_traits: {
        extroversion: '外向型，善于社交和沟通',
        intuition: '直觉型，喜欢探索新可能性',
        feeling: '情感型，重视人际关系和价值观',
        perceiving: '感知型，灵活适应环境变化'
      },
      test_version: 'v1.0',
      personal_info: {
        test_date: new Date().toISOString().split('T')[0],
      }
    };

    console.log('发送数据:', JSON.stringify(testData, null, 2));

    const saveResponse = await axios.post(`${API_URL}/api/mbti-records`, testData, {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ MBTI记录保存成功');
    console.log('   响应:', saveResponse.data);

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

testMbtiSave();
