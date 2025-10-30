// 测试MBTI测试集成功能
const axios = require('axios');

const API_URL = 'http://localhost:8080';

async function testMBTIIntegration() {
  try {
    console.log('🧪 测试MBTI测试集成功能...\n');

    // 1. admin登录
    console.log('1️⃣ admin登录...');
    const adminLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    const adminToken = adminLogin.data.token;
    console.log('✅ admin登录成功');
    console.log('   Token:', adminToken.substring(0, 20) + '...');

    // 2. 检查MBTI测试页面是否可访问
    console.log('\n2️⃣ 检查MBTI测试页面...');
    try {
      const testPageResponse = await axios.get(`${API_URL}/mbti_test.html`);
      console.log('✅ MBTI测试页面可访问');
      console.log('   页面大小:', testPageResponse.data.length, '字符');
    } catch (error) {
      console.log('❌ MBTI测试页面访问失败:', error.message);
    }

    // 3. 检查MBTI题目数据
    console.log('\n3️⃣ 检查MBTI题目数据...');
    try {
      const questionsResponse = await axios.get(`${API_URL}/mbti_questions.js`);
      console.log('✅ MBTI题目数据可访问');
      console.log('   数据大小:', questionsResponse.data.length, '字符');
    } catch (error) {
      console.log('❌ MBTI题目数据访问失败:', error.message);
    }

    // 4. 测试创建MBTI记录API
    console.log('\n4️⃣ 测试创建MBTI记录API...');
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
      }
    };

    try {
      const createResponse = await axios.post(`${API_URL}/api/mbti-records`, testMBTIData, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      console.log('✅ MBTI记录创建成功');
      console.log('   记录ID:', createResponse.data.id);
    } catch (error) {
      console.log('❌ MBTI记录创建失败:', error.response?.data || error.message);
    }

    // 5. 测试获取MBTI记录
    console.log('\n5️⃣ 测试获取MBTI记录...');
    try {
      const getResponse = await axios.get(`${API_URL}/api/mbti-records?limit=1`, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      console.log('✅ MBTI记录获取成功');
      console.log('   记录数量:', getResponse.data.records.length);
      if (getResponse.data.records.length > 0) {
        console.log('   最新MBTI类型:', getResponse.data.records[0].mbti_type);
      }
    } catch (error) {
      console.log('❌ MBTI记录获取失败:', error.response?.data || error.message);
    }

    // 6. 测试AI性格分析
    console.log('\n6️⃣ 测试AI性格分析...');
    try {
      const analysisResponse = await axios.post(`${API_URL}/ai/personality-analysis`, {
        logText: '今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。',
        mbtiType: 'INFP',
        useDeepSeek: false
      }, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      console.log('✅ AI性格分析成功');
      console.log('   MBTI类型:', analysisResponse.data.mbtiType);
      console.log('   AI分析文本长度:', analysisResponse.data.aiAnalysisText?.length || 0);
    } catch (error) {
      console.log('❌ AI性格分析失败:', error.response?.data || error.message);
    }

    console.log('\n🎉 MBTI测试集成功能测试完成！');
    console.log('\n📋 使用说明:');
    console.log('1. 在Flutter应用中点击"MBTI性格测试"按钮');
    console.log('2. 系统会自动打开浏览器并加载测试页面');
    console.log('3. 完成93道测试题目');
    console.log('4. 系统会自动保存测试结果到数据库');
    console.log('5. 返回Flutter应用，点击"AI性格分析"查看分析结果');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
    if (error.response?.status) {
      console.error('   状态码:', error.response.status);
    }
  }
}

testMBTIIntegration();
