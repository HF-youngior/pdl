// MBTI API测试脚本
const axios = require('axios');

const BASE_URL = 'http://localhost:8080/api';

// 测试数据
const testMbtiRecord = {
  mbti_type: 'ENFP',
  test_scores: {
    E: 75,
    N: 80,
    F: 70,
    P: 65,
    total_score: 290
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
  }
};

async function testMbtiApi() {
  try {
    console.log('🚀 开始测试MBTI API...\n');

    // 1. 登录获取token
    console.log('1. 用户登录...');
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      username: 'admin',
      password: 'admin123'
    });
    
    const token = loginResponse.data.token;
    console.log('✅ 登录成功，获取到token\n');

    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };

    // 2. 创建MBTI记录
    console.log('2. 创建MBTI记录...');
    const createResponse = await axios.post(`${BASE_URL}/mbti-records`, testMbtiRecord, { headers });
    console.log('✅ 创建成功:', createResponse.data);
    const recordId = createResponse.data.id;
    console.log('');

    // 3. 获取MBTI记录列表
    console.log('3. 获取MBTI记录列表...');
    const listResponse = await axios.get(`${BASE_URL}/mbti-records`, { headers });
    console.log('✅ 获取列表成功，记录数量:', listResponse.data.records.length);
    console.log('');

    // 4. 获取特定MBTI记录详情
    console.log('4. 获取MBTI记录详情...');
    const detailResponse = await axios.get(`${BASE_URL}/mbti-records/${recordId}`, { headers });
    console.log('✅ 获取详情成功:', {
      id: detailResponse.data.id,
      mbti_type: detailResponse.data.mbti_type,
      confidence_score: detailResponse.data.confidence_score
    });
    console.log('');

    // 5. 更新MBTI记录
    console.log('5. 更新MBTI记录...');
    const updateData = {
      personal_info: {
        full_name: '更新后的测试用户',
        birth_date: '1990-01-01',
        address: '更新后的测试地址',
        phone: '13800138000'
      }
    };
    const updateResponse = await axios.put(`${BASE_URL}/mbti-records/${recordId}`, updateData, { headers });
    console.log('✅ 更新成功:', updateResponse.data);
    console.log('');

    // 6. 按MBTI类型过滤
    console.log('6. 按MBTI类型过滤...');
    const filterResponse = await axios.get(`${BASE_URL}/mbti-records?mbti_type=ENFP`, { headers });
    console.log('✅ 过滤成功，ENFP类型记录数量:', filterResponse.data.records.length);
    console.log('');

    // 7. 获取MBTI统计信息（管理员权限）
    console.log('7. 获取MBTI统计信息...');
    const statsResponse = await axios.get(`${BASE_URL}/mbti-records/statistics`, { headers });
    console.log('✅ 统计信息:', statsResponse.data);
    console.log('');

    // 8. 删除MBTI记录
    console.log('8. 删除MBTI记录...');
    const deleteResponse = await axios.delete(`${BASE_URL}/mbti-records/${recordId}`, { headers });
    console.log('✅ 删除成功:', deleteResponse.data);
    console.log('');

    console.log('🎉 所有MBTI API测试通过！');

  } catch (error) {
    console.error('❌ 测试失败:', error.response?.data || error.message);
  }
}

// 运行测试
testMbtiApi();
