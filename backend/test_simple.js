// 简单的测试脚本
const axios = require('axios');

const API_URL = 'http://localhost:8080/api';

async function testSimple() {
  try {
    console.log('🧪 简单测试...\n');

    // 测试admin登录
    console.log('1️⃣ 测试admin登录...');
    const adminLogin = await axios.post(`${API_URL}/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    console.log('✅ admin登录成功');
    console.log('   用户ID:', adminLogin.data.user.id);
    console.log('   用户名:', adminLogin.data.user.username);

    // 测试hr_head登录
    console.log('\n2️⃣ 测试hr_head登录...');
    const hrLogin = await axios.post(`${API_URL}/auth/login`, {
      username: 'hr_head',
      password: 'hr123'
    });
    console.log('✅ hr_head登录成功');
    console.log('   用户ID:', hrLogin.data.user.id);
    console.log('   用户名:', hrLogin.data.user.username);

    console.log('\n🎉 基本功能正常！');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
    if (error.response?.status) {
      console.error('   状态码:', error.response.status);
    }
  }
}

testSimple();
