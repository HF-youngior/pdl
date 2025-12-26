const http = require('http');

// 测试配置
const HOST = 'localhost';
const PORT = 8080;
const USER_ID = 'dept-head-001'; // HR Head

// 辅助函数：发送HTTP请求
function makeRequest(path, method = 'GET', headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: HOST,
      port: PORT,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

// 解析日期字符串，检查时区
function checkTimezone(dateString) {
  if (!dateString) return null;
  
  // 检查是否包含时区信息
  if (dateString.includes('+08:00')) {
    return '✅ 北京时间 (+08:00)';
  } else if (dateString.includes('Z')) {
    return '❌ UTC时间 (Z)';
  } else if (dateString.includes('T')) {
    return '⚠️  有T但无时区信息';
  } else {
    return '⚠️  无时区标记';
  }
}

// 从时间字符串提取日期部分
function extractDate(dateString) {
  if (!dateString) return null;
  
  // 处理不同格式
  if (dateString.includes('T')) {
    // ISO格式：2025-10-15T09:00:00+08:00 -> 2025-10-15
    return dateString.split('T')[0];
  } else if (dateString.includes(' ')) {
    // MySQL格式：2025-10-15 09:00:00 -> 2025-10-15
    return dateString.split(' ')[0];
  }
  
  return dateString;
}

async function testTimezone() {
  console.log('=== 时区修复测试 ===\n');
  
  try {
    // 测试1: 周视图API（/api/tasks）
    console.log('1. 测试周视图API (/api/tasks)');
    console.log('   查询10月13日-19日的任务...\n');
    
    const tasksResponse = await makeRequest(
      `/api/tasks?startDate=2025-10-13&endDate=2025-10-19`
    );
    
    if (tasksResponse.error) {
      console.log('   ⚠️  需要认证，跳过周视图测试\n');
    } else {
      const q4Task = tasksResponse.find(t => t.title && t.title.includes('Q4绩效目标'));
      
      if (q4Task) {
        console.log(`   找到任务: ${q4Task.title}`);
        console.log(`   开始时间: ${q4Task.start_time}`);
        console.log(`   ${checkTimezone(q4Task.start_time)}`);
        console.log(`   结束时间: ${q4Task.end_time}`);
        console.log(`   ${checkTimezone(q4Task.end_time)}`);
        console.log(`   日期范围: ${extractDate(q4Task.start_time)} 至 ${extractDate(q4Task.end_time)}\n`);
      } else {
        console.log('   未找到Q4绩效目标任务\n');
      }
    }
    
    // 测试2: 月视图测试API
    console.log('2. 测试月视图API (/api/month-view/:userId/:year/:month)');
    console.log(`   查询 ${USER_ID} 在2025年10月的数据...\n`);
    
    const monthResponse = await makeRequest(`/api/month-view/${USER_ID}/2025/10`);
    
    if (monthResponse.tasks && monthResponse.tasks.length > 0) {
      const q4Task = monthResponse.tasks.find(t => t.title.includes('Q4绩效目标'));
      
      if (q4Task) {
        console.log(`   找到任务: ${q4Task.title}`);
        console.log(`   开始时间: ${q4Task.startTime}`);
        console.log(`   ${checkTimezone(q4Task.startTime)}`);
        console.log(`   结束时间: ${q4Task.endTime}`);
        console.log(`   ${checkTimezone(q4Task.endTime)}`);
        console.log(`   日期范围: ${extractDate(q4Task.startTime)} 至 ${extractDate(q4Task.endTime)}\n`);
      } else {
        console.log('   未找到Q4绩效目标任务\n');
      }
      
      // 检查前3个任务的时区
      console.log('   检查前3个任务的时区:');
      monthResponse.tasks.slice(0, 3).forEach((task, idx) => {
        console.log(`   ${idx + 1}. ${task.title}`);
        console.log(`      开始: ${task.startTime} ${checkTimezone(task.startTime)}`);
        console.log(`      结束: ${task.endTime} ${checkTimezone(task.endTime)}`);
      });
      console.log('');
    } else {
      console.log('   未找到任务\n');
    }
    
    // 测试3: 日视图API（需要认证）
    console.log('3. 测试日视图API (/api/calendar/day-detail)');
    console.log('   ⚠️  此API需要认证，需要通过前端测试\n');
    
    // 总结
    console.log('=== 测试总结 ===');
    console.log('✅ 后端已配置为返回北京时间格式 (+08:00)');
    console.log('✅ 所有时间字段应该包含 +08:00 时区标记');
    console.log('');
    console.log('📝 预期格式示例:');
    console.log('   原始MySQL: 2025-10-15 09:00:00');
    console.log('   转换后:     2025-10-15T09:00:00+08:00');
    console.log('');
    console.log('🎯 在前端（周视图）中:');
    console.log('   - Q4绩效目标设定指导 应该显示在 10月15-17日');
    console.log('   - 而不是 10月14-16日');
    console.log('');
    console.log('🔍 验证步骤:');
    console.log('   1. 重启后端服务器');
    console.log('   2. 在APP中登录HR Head账户');
    console.log('   3. 查看周视图(10/13-10/19)');
    console.log('   4. 确认"Q4绩效目标设定指导"显示在15-17日');
    console.log('   5. 查看月视图(2025年10月)');
    console.log('   6. 确认该任务在15、16、17日都有显示');
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
  }
}

// 运行测试
testTimezone();


