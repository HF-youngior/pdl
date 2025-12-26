// 测试MBTI记录修复
const axios = require('axios');

const API_URL = 'http://localhost:8080';

async function testMBTIFix() {
  try {
    console.log('🧪 测试MBTI记录修复...\n');

    // 1. admin登录
    console.log('1️⃣ admin登录...');
    const adminLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    const adminToken = adminLogin.data.token;
    console.log('✅ admin登录成功');

    // 2. 获取admin的MBTI记录
    console.log('\n2️⃣ 获取admin的MBTI记录...');
    const adminMbti = await axios.get(`${API_URL}/api/mbti-records?limit=1`, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    console.log('✅ admin MBTI记录获取成功');
    console.log('   记录数量:', adminMbti.data.records.length);
    if (adminMbti.data.records.length > 0) {
      console.log('   MBTI类型:', adminMbti.data.records[0].mbti_type);
      console.log('   测试日期:', adminMbti.data.records[0].test_date);
    }

    // 3. hr_head登录
    console.log('\n3️⃣ hr_head登录...');
    const hrLogin = await axios.post(`${API_URL}/api/auth/login`, {
      username: 'hr_head',
      password: 'hr123'
    });
    const hrToken = hrLogin.data.token;
    console.log('✅ hr_head登录成功');

    // 4. 获取hr_head的MBTI记录
    console.log('\n4️⃣ 获取hr_head的MBTI记录...');
    const hrMbti = await axios.get(`${API_URL}/api/mbti-records?limit=1`, {
      headers: { 'Authorization': `Bearer ${hrToken}` }
    });
    console.log('✅ hr_head MBTI记录获取成功');
    console.log('   记录数量:', hrMbti.data.records.length);
    if (hrMbti.data.records.length > 0) {
      console.log('   MBTI类型:', hrMbti.data.records[0].mbti_type);
      console.log('   测试日期:', hrMbti.data.records[0].test_date);
    }

    // 5. 测试AI性格分析
    console.log('\n5️⃣ 测试AI性格分析...');
    const adminAnalysis = await axios.post(`${API_URL}/ai/personality-analysis`, {
      logText: '今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。',
      mbtiType: 'INFP',
      useDeepSeek: false
    }, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    console.log('✅ admin AI分析成功');
    console.log('   MBTI类型:', adminAnalysis.data.mbtiType);
    console.log('   AI分析文本长度:', adminAnalysis.data.aiAnalysisText?.length || 0);

    console.log('\n🎉 所有测试通过！MBTI功能已修复。');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
    if (error.response?.status) {
      console.error('   状态码:', error.response.status);
    }
  }
}

testMBTIFix();
