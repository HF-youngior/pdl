const axios = require('axios');

async function testCompleteFlow() {
  console.log('测试完整的API流程...\n');
  
  // 1. 登录获取token
  console.log('1. 登录获取token...');
  try {
    const loginResponse = await axios.post('http://localhost:3000/api/auth/login', {
      username: 'admin',
      password: 'admin123'
    });
    
    const token = loginResponse.data.token;
    console.log('登录成功，获取到token');
    
    // 2. 创建带经纬度的日志
    console.log('\n2. 创建带经纬度的日志...');
    const logData = {
      title: '测试完整流程',
      content: '这是一个测试日志，用于验证完整的地址转换流程。',
      category: 'work',
      location_latitude: '39.908823',
      location_longitude: '116.397470'
    };
    
    const createResponse = await axios.post('http://localhost:3000/api/personal-logs', logData, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    const createdLog = createResponse.data;
    console.log('创建日志成功');
    console.log('日志ID:', createdLog.id);
    console.log('经纬度:', createdLog.location_latitude, createdLog.location_longitude);
    console.log('转换后的地址:', createdLog.location_address);
    
    // 3. 获取日志列表
    console.log('\n3. 获取日志列表...');
    const listResponse = await axios.get('http://localhost:3000/api/personal-logs', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    const logs = listResponse.data;
    const testLog = logs.find(log => log.id === createdLog.id);
    
    if (testLog) {
      console.log('在列表中找到测试日志');
      console.log('转换后的地址:', testLog.location_address);
    } else {
      console.log('未在列表中找到测试日志');
    }
    
    console.log('\n测试完成！');
    
  } catch (error) {
    console.error('测试过程中出错:', error.message);
    if (error.response) {
      console.error('响应状态:', error.response.status);
      console.error('响应数据:', error.response.data);
    }
  }
}

testCompleteFlow();