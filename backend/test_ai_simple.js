// 简单的AI性格分析测试脚本
const axios = require('axios');

const API_URL = 'http://localhost:8080/api';

async function testAIPersonality() {
  try {
    console.log('🧪 开始测试AI性格分析功能...\n');

    // 1. 测试admin登录
    console.log('1️⃣ 测试admin账号登录...');
    const adminLogin = await axios.post(`${API_URL}/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    console.log('✅ admin登录成功');
    const adminToken = adminLogin.data.token;

    // 2. 测试hr_head登录
    console.log('\n2️⃣ 测试hr_head账号登录...');
    const hrLogin = await axios.post(`${API_URL}/auth/login`, {
      username: 'hr_head',
      password: 'hr123'
    });
    console.log('✅ hr_head登录成功');
    const hrToken = hrLogin.data.token;

    // 3. 获取admin的MBTI记录
    console.log('\n3️⃣ 获取admin的MBTI记录...');
    const adminMbti = await axios.get(`${API_URL}/mbti-records?limit=1`, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    console.log('✅ admin MBTI记录:', adminMbti.data.records[0]?.mbti_type || '无记录');

    // 4. 获取hr_head的MBTI记录
    console.log('\n4️⃣ 获取hr_head的MBTI记录...');
    const hrMbti = await axios.get(`${API_URL}/mbti-records?limit=1`, {
      headers: { 'Authorization': `Bearer ${hrToken}` }
    });
    console.log('✅ hr_head MBTI记录:', hrMbti.data.records[0]?.mbti_type || '无记录');

    // 5. 测试admin的AI性格分析
    console.log('\n5️⃣ 测试admin的AI性格分析...');
    const adminAnalysis = await axios.post(`${API_URL}/ai/personality-analysis`, {
      logText: '今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。',
      mbtiType: 'INFP',
      useDeepSeek: false
    }, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    console.log('✅ admin AI分析完成');
    console.log('   MBTI类型:', adminAnalysis.data.mbtiType);
    console.log('   AI分析文本:', adminAnalysis.data.aiAnalysisText?.substring(0, 100) + '...');

    // 6. 测试hr_head的AI性格分析
    console.log('\n6️⃣ 测试hr_head的AI性格分析...');
    const hrAnalysis = await axios.post(`${API_URL}/ai/personality-analysis`, {
      logText: '今天组织了部门会议，制定了新的招聘计划，确保团队高效运转。',
      mbtiType: 'ESTJ',
      useDeepSeek: false
    }, {
      headers: { 'Authorization': `Bearer ${hrToken}` }
    });
    console.log('✅ hr_head AI分析完成');
    console.log('   MBTI类型:', hrAnalysis.data.mbtiType);
    console.log('   AI分析文本:', hrAnalysis.data.aiAnalysisText?.substring(0, 100) + '...');

    console.log('\n🎉 所有测试通过！AI性格分析功能正常工作。');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
  }
}

testAIPersonality();
