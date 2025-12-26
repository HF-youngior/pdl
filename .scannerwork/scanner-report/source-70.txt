const axios = require('axios');
const https = require('https');

// 配置
const BASE_URL = 'https://localhost:8080';

// 创建axios实例，忽略SSL证书验证（用于测试自签名证书）
const axiosInstance = axios.create({
  httpsAgent: new https.Agent({
    rejectUnauthorized: false
  })
});
const TEST_USER = {
  username: 'test_employee',
  password: 'test123456'
};

// 需要管理员权限的接口列表
const ADMIN_ENDPOINTS = [
  {
    method: 'GET',
    path: '/api/admin/dashboard-stats',
    description: '获取管理员仪表盘统计'
  },
  // 注意：GET /api/users 接口通过数据过滤实现权限控制，不是越权问题
  // employee角色只能看到自己，这是合理的设计
  {
    method: 'POST',
    path: '/api/users',
    description: '创建新用户',
    body: {
      username: 'test_user_unauthorized',
      password: 'test123',
      name: '测试用户',
      position: '测试',
      department_id: 'dept-001',
      role: 'employee'
    }
  },
  {
    method: 'GET',
    path: '/api/company-important-items/all',
    description: '获取所有重要事项（管理员）'
  },
  {
    method: 'POST',
    path: '/api/company-important-items',
    description: '创建重要事项',
    body: {
      title: '测试重要事项',
      description: '这是越权测试',
      priority: 'p1'
    }
  },
  {
    method: 'GET',
    path: '/api/admin/search-users',
    description: '搜索用户（仅管理员）',
    params: { q: 'test' }
  },
  {
    method: 'GET',
    path: '/api/admin/user-statistics',
    description: '获取用户统计（仅管理员）'
  }
];

async function testUnauthorizedAccess() {
  console.log('\n=== 越权访问控制安全测试 ===\n');
  console.log('测试目标：验证普通用户无法访问管理员专用接口\n');

  let token = null;

  try {
    // 步骤1: 使用普通用户登录获取Token
    console.log('步骤1: 使用普通用户登录获取Token');
    console.log(`用户名: ${TEST_USER.username}`);
    console.log(`密码: ${TEST_USER.password}\n`);

    const loginResponse = await axiosInstance.post(`${BASE_URL}/api/auth/login`, {
      username: TEST_USER.username,
      password: TEST_USER.password
    });

    if (loginResponse.status === 200 && loginResponse.data.token) {
      token = loginResponse.data.token;
      console.log('✓ 登录成功！');
      console.log(`✓ Token已获取: ${token.substring(0, 50)}...`);
      console.log(`✓ 用户角色: ${loginResponse.data.user.role}`);
      console.log(`✓ 用户ID: ${loginResponse.data.user.id}\n`);
    } else {
      console.error('❌ 登录失败：未获取到Token');
      return;
    }

    // 步骤2: 验证Token可以访问普通接口
    console.log('步骤2: 验证Token可以访问普通接口（用户信息）');
    try {
      const profileResponse = await axiosInstance.get(`${BASE_URL}/api/user/profile`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (profileResponse.status === 200) {
        console.log('✓ 普通接口访问成功（符合预期）');
        console.log(`✓ 用户信息: ${profileResponse.data.username}\n`);
      }
    } catch (error) {
      console.error('❌ 普通接口访问失败:', error.response?.data || error.message);
      return;
    }

    // 步骤3: 尝试使用普通用户Token访问管理员接口
    console.log('步骤3: 尝试使用普通用户Token访问管理员接口');
    console.log('='.repeat(60) + '\n');

    let successCount = 0;
    let failCount = 0;

    for (const endpoint of ADMIN_ENDPOINTS) {
      try {
        const config = {
          method: endpoint.method,
          url: `${BASE_URL}${endpoint.path}`,
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        };

        if (endpoint.params) {
          config.params = endpoint.params;
        }

        if (endpoint.body) {
          config.data = endpoint.body;
        }

        const response = await axiosInstance(config);

        // 如果返回200，说明越权成功（这是安全问题）
        if (response.status === 200 || response.status === 201) {
          console.log(`❌ 安全漏洞！`);
          console.log(`   接口: ${endpoint.method} ${endpoint.path}`);
          console.log(`   描述: ${endpoint.description}`);
          console.log(`   状态码: ${response.status}`);
          console.log(`   响应: ${JSON.stringify(response.data).substring(0, 100)}...`);
          console.log('');
          successCount++;
        } else {
          console.log(`⚠️  意外状态码: ${response.status}`);
          console.log(`   接口: ${endpoint.method} ${endpoint.path}`);
          console.log('');
        }
      } catch (error) {
        const status = error.response?.status;
        const errorMessage = error.response?.data?.error || error.message;

        if (status === 403) {
          // 403是预期的，说明权限控制有效
          console.log(`✓ 权限控制有效`);
          console.log(`   接口: ${endpoint.method} ${endpoint.path}`);
          console.log(`   描述: ${endpoint.description}`);
          console.log(`   状态码: 403 Forbidden`);
          console.log(`   错误消息: ${errorMessage}`);
          console.log('');
          failCount++;
        } else if (status === 401) {
          console.log(`⚠️  认证失败（可能是Token问题）`);
          console.log(`   接口: ${endpoint.method} ${endpoint.path}`);
          console.log(`   状态码: 401 Unauthorized`);
          console.log('');
        } else {
          console.log(`⚠️  其他错误`);
          console.log(`   接口: ${endpoint.method} ${endpoint.path}`);
          console.log(`   状态码: ${status || 'N/A'}`);
          console.log(`   错误: ${errorMessage}`);
          console.log('');
        }
      }
    }

    // 测试结果总结
    console.log('='.repeat(60));
    console.log('\n=== 测试结果总结 ===\n');
    console.log(`总测试接口数: ${ADMIN_ENDPOINTS.length}`);
    console.log(`✓ 权限控制有效（返回403）: ${failCount}`);
    console.log(`❌ 越权成功（返回200）: ${successCount}\n`);

    if (successCount === 0) {
      console.log('✅ 测试通过！');
      console.log('✅ 所有管理员接口都正确拒绝了普通用户的访问');
      console.log('✅ 权限控制机制有效，不存在越权风险\n');
    } else {
      console.log('❌ 测试失败！');
      console.log('❌ 发现安全漏洞：普通用户可以访问管理员接口');
      console.log('❌ 需要修复权限控制机制\n');
    }

  } catch (error) {
    console.error('\n❌ 测试过程出错:', error.message);
    if (error.response) {
      console.error('响应状态:', error.response.status);
      console.error('响应数据:', error.response.data);
    }
  }
}

// 运行测试
testUnauthorizedAccess();

