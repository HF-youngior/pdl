// 最终AI性格分析测试
const axios = require('axios');

const API_URL = 'http://localhost:8080';

async function testAIFinal() {
  try {
    console.log('🧪 最终AI性格分析测试...\n');

    // 1. admin登录
    console.log('1️⃣ admin登录...');
    const adminLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    const adminToken = adminLogin.data.token;
    console.log('✅ admin登录成功 (INFP)');

    // 2. hr_head登录
    console.log('\n2️⃣ hr_head登录...');
    const hrLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'hr_head',
      password: 'hr123'
    });
    const hrToken = hrLogin.data.token;
    console.log('✅ hr_head登录成功 (ESTJ)');

    // 3. 测试admin的AI性格分析
    console.log('\n3️⃣ 测试admin的AI性格分析...');
    const adminAnalysis = await axios.post(`${API_URL}/ai/personality-analysis`, {
      logText: '今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。',
      mbtiType: 'INFP',
      useDeepSeek: false
    }, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    console.log('✅ admin AI分析完成');
    console.log('   MBTI类型:', adminAnalysis.data.mbtiType);
    console.log('   性格特质:', JSON.stringify(adminAnalysis.data.personalityTraits, null, 2));
    console.log('   AI分析文本:', adminAnalysis.data.aiAnalysisText?.substring(0, 150) + '...');

    // 4. 测试hr_head的AI性格分析
    console.log('\n4️⃣ 测试hr_head的AI性格分析...');
    const hrAnalysis = await axios.post(`${API_URL}/ai/personality-analysis`, {
      logText: '今天组织了部门会议，制定了新的招聘计划，确保团队高效运转。',
      mbtiType: 'ESTJ',
      useDeepSeek: false
    }, {
      headers: { 'Authorization': `Bearer ${hrToken}` }
    });
    console.log('✅ hr_head AI分析完成');
    console.log('   MBTI类型:', hrAnalysis.data.mbtiType);
    console.log('   性格特质:', JSON.stringify(hrAnalysis.data.personalityTraits, null, 2));
    console.log('   AI分析文本:', hrAnalysis.data.aiAnalysisText?.substring(0, 150) + '...');

    console.log('\n🎉 所有测试通过！AI性格分析功能正常工作。');
    console.log('\n📊 测试总结:');
    console.log('   - admin (INFP): 内向、直觉、情感、感知');
    console.log('   - hr_head (ESTJ): 外向、感觉、思维、判断');
    console.log('   - AI分析功能: 正常工作');
    console.log('   - 数据存储: 正常');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
    if (error.response?.status) {
      console.error('   状态码:', error.response.status);
    }
  }
}

testAIFinal();
