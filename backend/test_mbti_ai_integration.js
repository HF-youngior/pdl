// MBTI和AI分析模块集成测试脚本
const axios = require('axios');

const BASE_URL = 'http://localhost:8080/api';
const AI_BASE_URL = 'http://localhost:8080/ai';

// 测试数据
const testMbtiRecord = {
  mbti_type: 'ENFP',
  test_scores: {
    E: 75,
    I: 25,
    S: 20,
    N: 80,
    T: 30,
    F: 70,
    J: 35,
    P: 65
  },
  personality_traits: {
    extroversion: '外向型，善于社交和沟通',
    intuition: '直觉型，喜欢探索新可能性',
    feeling: '情感型，重视人际关系和价值观',
    perceiving: '感知型，灵活适应环境变化'
  },
  personal_info: {
    full_name: '测试用户',
    birth_date: '1990-01-01',
    address: '测试地址'
  },
  test_version: 'v1.0'
};

const testAiLogAnalysis = {
  text: '今天完成了项目的技术方案设计，与团队成员进行了充分的沟通和讨论，解决了几个关键技术问题。感觉工作很充实，对项目的成功充满信心。',
  user_id: 'test-user-001',
  log_date: '2025-01-01'
};

const testPersonalityAnalysis = {
  logText: '今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。',
  mbtiType: 'INFP',
  useDeepSeek: false
};

const testWordCloudAnalysis = {
  keywords: [
    { word: '项目', count: 10, weight: 1.0 },
    { word: '技术', count: 8, weight: 0.8 },
    { word: '团队', count: 6, weight: 0.6 },
    { word: '沟通', count: 5, weight: 0.5 },
    { word: '问题', count: 4, weight: 0.4 }
  ],
  analysis_date: '2025-01-01',
  user_id: 'test-user-001'
};

// 测试结果存储
const testResults = [];

// 登录获取token
async function login() {
  try {
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    return loginResponse.data.token;
  } catch (error) {
    console.error('❌ 登录失败:', error.response?.data || error.message);
    throw error;
  }
}

// 执行单个测试用例
async function runTestCase(testId, module, testName, endpoint, method, requestData, expectedStatusCode, headers = {}) {
  try {
    let response;
    const requestUrl = endpoint.includes('http') ? endpoint : (method === 'GET' ? `${endpoint}` : `${endpoint}`);
    
    console.log(`\n📝 ${testId} - ${testName}`);
    console.log(`   接口: ${method} ${requestUrl}`);
    
    if (method === 'GET') {
      response = await axios.get(requestUrl, { headers });
    } else if (method === 'POST') {
      response = await axios.post(requestUrl, requestData, { headers });
    } else if (method === 'PUT') {
      response = await axios.put(requestUrl, requestData, { headers });
    } else if (method === 'DELETE') {
      response = await axios.delete(requestUrl, { headers });
    }
    
    const actualStatusCode = response.status;
    const actualResponse = response.data;
    const testPass = actualStatusCode === expectedStatusCode;
    
    testResults.push({
      id: testId,
      module: module,
      testName: testName,
      endpoint: endpoint,
      method: method,
      requestData: JSON.stringify(requestData),
      expectedStatusCode: expectedStatusCode,
      actualStatusCode: actualStatusCode,
      expectedResponse: JSON.stringify({ success: true }),
      actualResponse: JSON.stringify(actualResponse),
      testResult: testPass ? 'Pass' : 'Fail'
    });
    
    console.log(`   状态码: ${actualStatusCode} (预期: ${expectedStatusCode})`);
    console.log(`   结果: ${testPass ? '✅ Pass' : '❌ Fail'}`);
    
    return { response: actualResponse, pass: testPass };
    
  } catch (error) {
    const actualStatusCode = error.response?.status || 0;
    const errorMessage = error.response?.data || error.message;
    
    testResults.push({
      id: testId,
      module: module,
      testName: testName,
      endpoint: endpoint,
      method: method,
      requestData: JSON.stringify(requestData),
      expectedStatusCode: expectedStatusCode,
      actualStatusCode: actualStatusCode,
      expectedResponse: JSON.stringify({ success: true }),
      actualResponse: JSON.stringify(errorMessage),
      testResult: 'Fail'
    });
    
    console.log(`   状态码: ${actualStatusCode} (预期: ${expectedStatusCode})`);
    console.log(`   结果: ❌ Fail`);
    console.log(`   错误: ${JSON.stringify(errorMessage)}`);
    
    return { response: errorMessage, pass: false };
  }
}

// 生成测试报告
function generateTestReport() {
  console.log('\n\n==================== 测试报告 ====================');
  console.log('ID\t模块\t测试名称\t接口名称\t请求类型\t预期响应码\t实际响应码\t测试结果');
  console.log('--------------------------------------------------');
  
  testResults.forEach(result => {
    console.log(`${result.id}\t${result.module}\t${result.testName}\t${result.endpoint}\t${result.method}\t${result.expectedStatusCode}\t${result.actualStatusCode}\t${result.testResult}`);
  });
  
  console.log('--------------------------------------------------');
  const totalTests = testResults.length;
  const passedTests = testResults.filter(r => r.testResult === 'Pass').length;
  const failedTests = totalTests - passedTests;
  
  console.log(`总计: ${totalTests} 测试用例`);
  console.log(`通过: ${passedTests} 测试用例`);
  console.log(`失败: ${failedTests} 测试用例`);
  console.log(`通过率: ${((passedTests / totalTests) * 100).toFixed(2)}%`);
  console.log('==================================================');
  
  // 生成表格格式的测试报告（CSV格式，方便导入Excel）
  console.log('\n\n--- 表格格式测试报告（可直接复制到Excel） ---');
  console.log('ID,模块,测试名称,接口名称,请求类型,预期响应码,实际响应码,测试结果');
  testResults.forEach(result => {
    console.log(`${result.id},${result.module},${result.testName},${result.endpoint},${result.method},${result.expectedStatusCode},${result.actualStatusCode},${result.testResult}`);
  });
}

// 主测试函数
async function runAllTests() {
  try {
    console.log('🚀 开始执行MBTI和AI分析模块集成测试...\n');
    
    // 登录获取token
    console.log('🔑 正在登录...');
    const token = await login();
    console.log('✅ 登录成功，获取到token\n');
    
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
    
    // MBTI模块测试
    console.log('\n📊 MBTI模块测试');
    console.log('--------------------------------------------------');
    
    // 1. 创建MBTI记录
    await runTestCase('MBTI-001', 'MBTI', '创建MBTI测评记录', `${BASE_URL}/mbti-records`, 'POST', testMbtiRecord, 201, headers);
    
    // 2. 获取MBTI记录列表
    const listResult = await runTestCase('MBTI-002', 'MBTI', '获取MBTI测评记录列表', `${BASE_URL}/mbti-records`, 'GET', {}, 200, headers);
    
    // 3. 获取最近一次MBTI测评记录
    await runTestCase('MBTI-003', 'MBTI', '获取最近一次MBTI测评记录', `${BASE_URL}/mbti-records/latest`, 'GET', {}, 200, headers);
    
    // 获取一个实际的记录ID用于后续测试
    let recordId;
    if (listResult.pass && listResult.response.records && listResult.response.records.length > 0) {
      recordId = listResult.response.records[0].id;
      
      // 4. 获取单条MBTI记录详情
      await runTestCase('MBTI-004', 'MBTI', '获取单条MBTI测评记录', `${BASE_URL}/mbti-records/${recordId}`, 'GET', {}, 200, headers);
      
      // 5. 更新MBTI记录
      const updateData = { ...testMbtiRecord, personal_info: { ...testMbtiRecord.personal_info, phone: '13800138000' } };
      await runTestCase('MBTI-005', 'MBTI', '更新MBTI测评记录', `${BASE_URL}/mbti-records/${recordId}`, 'PUT', updateData, 200, headers);
      
      // 6. 删除MBTI记录
      await runTestCase('MBTI-006', 'MBTI', '删除MBTI测评记录', `${BASE_URL}/mbti-records/${recordId}`, 'DELETE', {}, 200, headers);
    }
    
    // 7. 获取MBTI统计信息
    await runTestCase('MBTI-007', 'MBTI', '获取MBTI统计信息', `${BASE_URL}/mbti-records/statistics`, 'GET', {}, 200, headers);
    
    // AI分析模块测试
    console.log('\n🤖 AI分析模块测试');
    console.log('--------------------------------------------------');
    
    // 1. 对日志进行AI分析
    await runTestCase('AI-001', 'AI分析', '对日志进行AI分析', `${BASE_URL}/ai/analyze-log`, 'POST', testAiLogAnalysis, 200, headers);
    
    // 2. 分析今日任务/日志
    await runTestCase('AI-002', 'AI分析', '分析今日任务/日志', `${BASE_URL}/ai/analyze-today`, 'GET', {}, 200, headers);
    
    // 3. 保存词云分析结果
    await runTestCase('AI-003', 'AI分析', '保存词云分析结果', `${BASE_URL}/ai/save-wordcloud`, 'POST', testWordCloudAnalysis, 200, headers);
    
    // 4. 获取词云历史记录
    await runTestCase('AI-004', 'AI分析', '获取词云历史记录', `${BASE_URL}/ai/wordcloud-history`, 'GET', {}, 200, headers);
    
    // 5. 发起人格分析请求
    await runTestCase('AI-005', 'AI分析', '发起人格分析请求', `${BASE_URL}/ai/personality-analysis`, 'POST', testPersonalityAnalysis, 200, headers);
    
    // 6. 获取人格分析历史记录
    await runTestCase('AI-006', 'AI分析', '获取人格分析历史记录', `${BASE_URL}/ai/personality-history`, 'GET', {}, 200, headers);
    
    // 生成测试报告
    generateTestReport();
    
  } catch (error) {
    console.error('❌ 测试过程中发生错误:', error);
    generateTestReport();
  }
}

// 运行测试
runAllTests();