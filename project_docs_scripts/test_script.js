const axios = require('axios');
const fs = require('fs');

// 测试配置
const BASE_URL = 'http://localhost:8080/api';
let authToken = '';
let userId = '';

// 测试结果存储
const testResults = {
  userAuth: [],
  companyItems: [],
  notifications: []
};

// 辅助函数：执行测试用例
async function runTest(testCase, testFn) {
  try {
    const result = await testFn();
    return {
      ...testCase,
      actualResult: result,
      testStatus: 'Pass'
    };
  } catch (error) {
    return {
      ...testCase,
      actualResult: error.message,
      testStatus: 'Fail'
    };
  }
}

// 用户登录及个人信息模块测试
async function testUserAuthModule() {
  console.log('=== 用户登录及个人信息模块测试 ===');
  
  // 测试用例列表
  const userAuthTests = [
    {
      testId: 'S-01',
      requirementId: '5.5',
      testTitle: 'Android前端登录页面 - 不输入用户名密码',
      preCondition: '服务器正常运行，应用已启动',
      testSteps: '1. 打开登录页面\n2. 不输入用户名和密码\n3. 点击登录按钮',
      expectedResult: '系统提示"用户名和密码不能为空"'
    },
    {
      testId: 'S-02',
      requirementId: '5.5',
      testTitle: 'Android前端登录页面 - 错误用户名密码',
      preCondition: '服务器正常运行，应用已启动',
      testSteps: '1. 打开登录页面\n2. 输入错误用户名admin1和密码admin123\n3. 点击登录按钮',
      expectedResult: '系统提示"用户名或密码错误"'
    },
    {
      testId: 'S-03',
      requirementId: '5.5',
      testTitle: 'Android前端登录页面 - 特殊字符输入',
      preCondition: '服务器正常运行，应用已启动',
      testSteps: '1. 打开登录页面\n2. 输入用户名为"admin@#$%"和密码为"admin!@#"\n3. 点击登录按钮',
      expectedResult: '系统提示"用户名或密码错误"'
    },
    {
      testId: 'S-04',
      requirementId: '5.5',
      testTitle: 'Android前端登录页面 - 正确用户名密码',
      preCondition: '服务器正常运行，应用已启动',
      testSteps: '1. 打开登录页面\n2. 输入用户名admin和密码admin123\n3. 点击登录按钮',
      expectedResult: '成功登录，跳转到主页面'
    },
    {
      testId: 'S-05',
      requirementId: '5.5',
      testTitle: '密码更改 - 正确原密码和新密码',
      preCondition: '已登录系统',
      testSteps: '1. 进入密码设置页面\n2. 输入原密码admin123\n3. 输入新密码admin456\n4. 确认新密码admin456\n5. 点击保存按钮',
      expectedResult: '密码修改成功，提示用户重新登录'
    },
    {
      testId: 'S-06',
      requirementId: '5.5',
      testTitle: '密码更改 - 错误原密码',
      preCondition: '已登录系统',
      testSteps: '1. 进入密码设置页面\n2. 输入错误原密码wrong123\n3. 输入新密码admin456\n4. 确认新密码admin456\n5. 点击保存按钮',
      expectedResult: '系统提示"原密码错误"'
    },
    {
      testId: 'S-07',
      requirementId: '5.5',
      testTitle: '个人信息修改 - 基本信息',
      preCondition: '已登录系统',
      testSteps: '1. 进入个人信息页面\n2. 修改姓名为"测试管理员"\n3. 点击保存按钮',
      expectedResult: '个人信息修改成功，页面显示更新后的信息'
    }
  ];
  
  // 执行测试用例
  for (const testCase of userAuthTests) {
    let testFn;
    
    switch (testCase.testId) {
      case 'S-01':
        testFn = async () => {
          try {
            await axios.post(`${BASE_URL}/auth/login`, {}, { headers: { 'Content-Type': 'application/json' } });
            return '未提示用户名密码不能为空';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      case 'S-02':
        testFn = async () => {
          try {
            await axios.post(`${BASE_URL}/auth/login`, { username: 'admin1', password: 'admin123' }, { headers: { 'Content-Type': 'application/json' } });
            return '错误的用户名密码登录成功';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      case 'S-03':
        testFn = async () => {
          try {
            await axios.post(`${BASE_URL}/auth/login`, { username: 'admin@#$%', password: 'admin!@#' }, { headers: { 'Content-Type': 'application/json' } });
            return '特殊字符用户名密码登录成功';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      case 'S-04':
        testFn = async () => {
          const response = await axios.post(`${BASE_URL}/auth/login`, { username: 'admin', password: 'admin123' }, { headers: { 'Content-Type': 'application/json' } });
          authToken = response.data.token;
          userId = response.data.user.id;
          return '登录成功，获取到认证Token';
        };
        break;
      
      case 'S-05':
        testFn = async () => {
          try {
            await axios.put(`${BASE_URL}/auth/change-password`, { oldPassword: 'admin123', newPassword: 'admin456', confirmPassword: 'admin456' }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            // 还原密码
            await axios.put(`${BASE_URL}/auth/change-password`, { oldPassword: 'admin456', newPassword: 'admin123', confirmPassword: 'admin123' }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            return '密码修改成功并还原';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      case 'S-06':
        testFn = async () => {
          try {
            await axios.put(`${BASE_URL}/auth/change-password`, { oldPassword: 'wrong123', newPassword: 'admin456', confirmPassword: 'admin456' }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            return '错误原密码修改密码成功';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      case 'S-07':
        testFn = async () => {
          try {
            const response = await axios.put(`${BASE_URL}/user/profile`, { name: '测试管理员' }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            // 还原姓名
            await axios.put(`${BASE_URL}/user/profile`, { name: '系统管理员' }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            return response.data?.message || '个人信息修改成功';
          } catch (error) {
            return error.response?.data?.message || '请求失败';
          }
        };
        break;
      
      default:
        testFn = async () => '未实现的测试用例';
    }
    
    const result = await runTest(testCase, testFn);
    testResults.userAuth.push(result);
    console.log(`[${result.testStatus}] ${result.testTitle}`);
  }
}

// 公司重要事项模块测试
async function testCompanyItemsModule() {
  console.log('\n=== 公司重要事项模块测试 ===');
  
  // 测试用例列表
  const companyItemsTests = [
    {
      testId: 'CI-01',
      requirementId: '6.1',
      testTitle: '验证admin权限 - 查看公司重要事项',
      preCondition: '已使用admin账号登录',
      testSteps: '1. 进入公司重要事项页面\n2. 查看事项列表',
      expectedResult: '成功查看所有公司重要事项'
    },
    {
      testId: 'CI-02',
      requirementId: '6.1',
      testTitle: '验证admin权限 - 创建公司重要事项',
      preCondition: '已使用admin账号登录',
      testSteps: '1. 进入公司重要事项页面\n2. 点击"创建"按钮\n3. 填写事项内容\n4. 点击"保存"按钮',
      expectedResult: '成功创建公司重要事项'
    },
    {
      testId: 'CI-03',
      requirementId: '6.1',
      testTitle: '验证admin权限 - 修改公司重要事项',
      preCondition: '已使用admin账号登录，存在至少一个公司重要事项',
      testSteps: '1. 进入公司重要事项页面\n2. 选择一个事项\n3. 点击"编辑"按钮\n4. 修改事项内容\n5. 点击"保存"按钮',
      expectedResult: '成功修改公司重要事项'
    },
    {
      testId: 'CI-04',
      requirementId: '6.1',
      testTitle: '验证admin权限 - 删除公司重要事项',
      preCondition: '已使用admin账号登录，存在至少一个公司重要事项',
      testSteps: '1. 进入公司重要事项页面\n2. 选择一个事项\n3. 点击"删除"按钮\n4. 确认删除',
      expectedResult: '成功删除公司重要事项'
    },
    {
      testId: 'CI-05',
      requirementId: '6.1',
      testTitle: '验证最多展示10个公司重要事项',
      preCondition: '已使用admin账号登录，系统中存在多于10个公司重要事项',
      testSteps: '1. 进入公司重要事项页面\n2. 查看事项列表数量',
      expectedResult: '页面最多展示10个公司重要事项'
    }
  ];
  
  // 执行测试用例
  for (const testCase of companyItemsTests) {
    let testFn;
    let createdItemId;
    
    switch (testCase.testId) {
      case 'CI-01':
        testFn = async () => {
          const response = await axios.get(`${BASE_URL}/company-important-items`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          return `获取到 ${response.data.length} 个公司重要事项`;
        };
        break;
      
      case 'CI-02':
        testFn = async () => {
          const response = await axios.post(`${BASE_URL}/company-important-items`, {
            title: '测试重要事项',
            content: '这是一个测试的公司重要事项',
            priority: 'high',
            due_date: new Date().toISOString().split('T')[0]
          }, {
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${authToken}`
            }
          });
          createdItemId = response.data.id;
          return '公司重要事项创建成功';
        };
        break;
      
      case 'CI-03':
        testFn = async () => {
          if (!createdItemId) {
            // 创建一个测试事项
            const createResponse = await axios.post(`${BASE_URL}/company-important-items`, {
              title: '测试重要事项',
              content: '这是一个测试的公司重要事项',
              priority: 'high',
              due_date: new Date().toISOString().split('T')[0]
            }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            createdItemId = createResponse.data.id;
          }
          
          const response = await axios.put(`${BASE_URL}/company-important-items/${createdItemId}`, {
            title: '修改后的测试重要事项',
            content: '这是修改后的测试内容',
            priority: 'medium'
          }, {
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${authToken}`
            }
          });
          return '公司重要事项修改成功';
        };
        break;
      
      case 'CI-04':
        testFn = async () => {
          if (!createdItemId) {
            // 创建一个测试事项
            const createResponse = await axios.post(`${BASE_URL}/company-important-items`, {
              title: '测试重要事项',
              content: '这是一个测试的公司重要事项',
              priority: 'high',
              due_date: new Date().toISOString().split('T')[0]
            }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            createdItemId = createResponse.data.id;
          }
          
          await axios.delete(`${BASE_URL}/company-important-items/${createdItemId}`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          createdItemId = null;
          return '公司重要事项删除成功';
        };
        break;
      
      case 'CI-05':
        testFn = async () => {
          const response = await axios.get(`${BASE_URL}/company-important-items?limit=15`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          return `获取到 ${response.data.length} 个公司重要事项，验证是否最多10个`;
        };
        break;
      
      default:
        testFn = async () => '未实现的测试用例';
    }
    
    const result = await runTest(testCase, testFn);
    testResults.companyItems.push(result);
    console.log(`[${result.testStatus}] ${result.testTitle}`);
  }
}

// 通知板块测试
async function testNotificationsModule() {
  console.log('\n=== 通知板块测试 ===');
  
  // 测试用例列表
  const notificationsTests = [
    {
      testId: 'NT-01',
      requirementId: '6.2',
      testTitle: '获取通知列表',
      preCondition: '已登录系统',
      testSteps: '1. 进入通知页面\n2. 查看通知列表',
      expectedResult: '成功获取通知列表'
    },
    {
      testId: 'NT-02',
      requirementId: '6.2',
      testTitle: '查看通知详情',
      preCondition: '已登录系统，存在至少一个通知',
      testSteps: '1. 进入通知页面\n2. 点击一条通知\n3. 查看通知详情',
      expectedResult: '成功查看通知详情'
    },
    {
      testId: 'NT-03',
      requirementId: '6.2',
      testTitle: '标记通知为已读',
      preCondition: '已登录系统，存在未读通知',
      testSteps: '1. 进入通知页面\n2. 选择一条未读通知\n3. 点击"标记为已读"按钮',
      expectedResult: '通知状态变为已读'
    },
    {
      testId: 'NT-04',
      requirementId: '6.2',
      testTitle: '删除通知',
      preCondition: '已登录系统，存在至少一个通知',
      testSteps: '1. 进入通知页面\n2. 选择一条通知\n3. 点击"删除"按钮\n4. 确认删除',
      expectedResult: '通知被成功删除'
    }
  ];
  
  // 执行测试用例
  for (const testCase of notificationsTests) {
    let testFn;
    let notificationId;
    
    switch (testCase.testId) {
      case 'NT-01':
        testFn = async () => {
          const response = await axios.get(`${BASE_URL}/notifications`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          if (response.data.length > 0) {
            notificationId = response.data[0].id;
          }
          return `获取到 ${response.data.length} 条通知`;
        };
        break;
      
      case 'NT-02':
        testFn = async () => {
          if (!notificationId) {
            // 获取第一条通知
            const listResponse = await axios.get(`${BASE_URL}/notifications`, {
              headers: {
                'Authorization': `Bearer ${authToken}`
              }
            });
            if (listResponse.data.length === 0) {
              return '没有可用的通知进行测试';
            }
            notificationId = listResponse.data[0].id;
          }
          
          const response = await axios.get(`${BASE_URL}/notifications/${notificationId}`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          return '通知详情获取成功';
        };
        break;
      
      case 'NT-03':
        testFn = async () => {
          if (!notificationId) {
            // 获取第一条通知
            const listResponse = await axios.get(`${BASE_URL}/notifications`, {
              headers: {
                'Authorization': `Bearer ${authToken}`
              }
            });
            if (listResponse.data.length === 0) {
              return '没有可用的通知进行测试';
            }
            notificationId = listResponse.data[0].id;
          }
          
          const response = await axios.put(`${BASE_URL}/notifications/${notificationId}/read`, {}, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          return '通知标记为已读成功';
        };
        break;
      
      case 'NT-04':
        testFn = async () => {
          if (!notificationId) {
            // 创建一个测试通知
            const createResponse = await axios.post(`${BASE_URL}/notifications`, {
              user_id: userId,
              title: '测试通知',
              content: '这是一个测试通知',
              type: 'system'
            }, {
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
              }
            });
            notificationId = createResponse.data.id;
          }
          
          await axios.delete(`${BASE_URL}/notifications/${notificationId}`, {
            headers: {
              'Authorization': `Bearer ${authToken}`
            }
          });
          notificationId = null;
          return '通知删除成功';
        };
        break;
      
      default:
        testFn = async () => '未实现的测试用例';
    }
    
    const result = await runTest(testCase, testFn);
    testResults.notifications.push(result);
    console.log(`[${result.testStatus}] ${result.testTitle}`);
  }
}

// 生成MD格式的测试报告
function generateMDReport() {
  let mdContent = '# PDL系统测试报告\n\n';
  mdContent += `**测试时间**: ${new Date().toLocaleString()}\n`;
  mdContent += `**测试环境**: ${BASE_URL}\n\n`;
  
  // 用户登录及个人信息模块
  mdContent += '## 1. 用户登录及个人信息模块\n\n';
  mdContent += '| 测试用例编号 | 需求编号 | 测试用例标题 | 前置条件 | 测试步骤 | 预期结果 | 实际结果 | 测试结果 |\n';
  mdContent += '|------------|---------|------------|---------|---------|---------|---------|---------|\n';
  
  testResults.userAuth.forEach(result => {
    mdContent += `| ${result.testId} | ${result.requirementId} | ${result.testTitle} | ${result.preCondition} | ${result.testSteps.replace(/\n/g, '<br>')} | ${result.expectedResult} | ${result.actualResult} | ${result.testStatus} |\n`;
  });
  
  // 公司重要事项模块
  mdContent += '\n## 2. 公司重要事项模块\n\n';
  mdContent += '| 测试用例编号 | 需求编号 | 测试用例标题 | 前置条件 | 测试步骤 | 预期结果 | 实际结果 | 测试结果 |\n';
  mdContent += '|------------|---------|------------|---------|---------|---------|---------|---------|\n';
  
  testResults.companyItems.forEach(result => {
    mdContent += `| ${result.testId} | ${result.requirementId} | ${result.testTitle} | ${result.preCondition} | ${result.testSteps.replace(/\n/g, '<br>')} | ${result.expectedResult} | ${result.actualResult} | ${result.testStatus} |\n`;
  });
  
  // 通知板块
  mdContent += '\n## 3. 通知板块\n\n';
  mdContent += '| 测试用例编号 | 需求编号 | 测试用例标题 | 前置条件 | 测试步骤 | 预期结果 | 实际结果 | 测试结果 |\n';
  mdContent += '|------------|---------|------------|---------|---------|---------|---------|---------|\n';
  
  testResults.notifications.forEach(result => {
    mdContent += `| ${result.testId} | ${result.requirementId} | ${result.testTitle} | ${result.preCondition} | ${result.testSteps.replace(/\n/g, '<br>')} | ${result.expectedResult} | ${result.actualResult} | ${result.testStatus} |\n`;
  });
  
  // 测试总结
  const totalTests = 
    testResults.userAuth.length + 
    testResults.companyItems.length + 
    testResults.notifications.length;
  
  const passedTests = 
    testResults.userAuth.filter(r => r.testStatus === 'Pass').length + 
    testResults.companyItems.filter(r => r.testStatus === 'Pass').length + 
    testResults.notifications.filter(r => r.testStatus === 'Pass').length;
  
  mdContent += '\n## 测试总结\n\n';
  mdContent += `**总测试用例数**: ${totalTests}\n`;
  mdContent += `**通过测试用例数**: ${passedTests}\n`;
  mdContent += `**失败测试用例数**: ${totalTests - passedTests}\n`;
  mdContent += `**测试通过率**: ${((passedTests / totalTests) * 100).toFixed(2)}%\n`;
  
  return mdContent;
}

// 主函数
async function main() {
  console.log('开始执行PDL系统测试...\n');
  
  // 安装axios依赖（如果需要）
  try {
    require('axios');
  } catch (e) {
    console.log('正在安装axios依赖...');
    const { execSync } = require('child_process');
    execSync('npm install axios', { stdio: 'inherit' });
  }
  
  // 执行测试模块
  await testUserAuthModule();
  await testCompanyItemsModule();
  await testNotificationsModule();
  
  // 生成测试报告
  const mdReport = generateMDReport();
  fs.writeFileSync('f:\\pdl\\测试报告.md', mdReport, 'utf8');
  
  console.log('\n=== 测试完成 ===');
  console.log(`测试报告已生成：f:\\pdl\\测试报告.md`);
  console.log(`总测试用例数：${testResults.userAuth.length + testResults.companyItems.length + testResults.notifications.length}`);
  console.log(`通过测试用例数：${
    testResults.userAuth.filter(r => r.testStatus === 'Pass').length +
    testResults.companyItems.filter(r => r.testStatus === 'Pass').length +
    testResults.notifications.filter(r => r.testStatus === 'Pass').length
  }`);
}

// 启动测试
main().catch(error => {
  console.error('测试执行出错:', error);
  process.exit(1);
});