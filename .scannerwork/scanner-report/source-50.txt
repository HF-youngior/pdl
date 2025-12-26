const http = require('http');

// 首先登录获取token
function login() {
  return new Promise((resolve, reject) => {
    const loginData = JSON.stringify({
      username: 'hr_head',
      password: '123456'
    });

    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/api/auth/login',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': loginData.length
      }
    };

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          const response = JSON.parse(data);
          resolve(response.token);
        } else {
          reject(new Error(`登录失败: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(loginData);
    req.end();
  });
}

// 测试月视图API
function testMonthView(token, year, month) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/api/calendar/month-view?year=${year}&month=${month}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    };

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`API调用失败: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

// 测试日视图API
function testDayView(token, date) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/api/calendar/day-detail?date=${date}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    };

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`API调用失败: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

async function runTests() {
  try {
    console.log('=== 跨多天任务API测试 ===\n');

    // 1. 登录
    console.log('步骤 1: 登录HR Head账户...');
    const token = await login();
    console.log('✓ 登录成功\n');

    // 2. 测试月视图
    console.log('步骤 2: 测试10月份月视图API...');
    const monthData = await testMonthView(token, 2025, 10);
    
    console.log(`✓ 月视图API调用成功`);
    console.log(`  总天数: ${monthData.days.length}`);
    console.log(`  总任务数: ${monthData.summary.totalTasks}`);
    console.log(`  总日志数: ${monthData.summary.totalLogs}\n`);

    // 3. 检查10月2、3、4日的任务
    console.log('步骤 3: 检查10月2、3、4日是否都包含"秋季校园招聘行程规划"...\n');
    
    const testDates = ['2025-10-02', '2025-10-03', '2025-10-04'];
    const targetTaskTitle = '秋季校园招聘行程规划';
    let allDatesHaveTask = true;

    for (const dateStr of testDates) {
      const dayInfo = monthData.days.find(d => d.date === dateStr);
      
      if (dayInfo) {
        const targetTask = dayInfo.tasks.find(t => t.title.includes(targetTaskTitle));
        
        if (targetTask) {
          console.log(`✓ ${dateStr}: 找到任务 "${targetTask.title}"`);
          console.log(`    任务ID: ${targetTask.id}`);
          console.log(`    开始时间: ${targetTask.start_time}`);
          console.log(`    结束时间: ${targetTask.end_time}`);
        } else {
          console.log(`✗ ${dateStr}: 未找到任务 (该日期共有 ${dayInfo.tasks.length} 个任务)`);
          if (dayInfo.tasks.length > 0) {
            console.log(`    该日期的任务：`);
            dayInfo.tasks.forEach(t => console.log(`      - ${t.title}`));
          }
          allDatesHaveTask = false;
        }
      } else {
        console.log(`✗ ${dateStr}: 日期数据不存在`);
        allDatesHaveTask = false;
      }
      console.log('');
    }

    if (allDatesHaveTask) {
      console.log('✓✓✓ 月视图测试通过！所有日期都正确显示跨多天任务\n');
    } else {
      console.log('✗✗✗ 月视图测试失败！某些日期缺失跨多天任务\n');
    }

    // 4. 测试日视图API
    console.log('步骤 4: 测试日视图API（10月3日）...');
    const dayData = await testDayView(token, '2025-10-03');
    
    console.log(`✓ 日视图API调用成功`);
    console.log(`  日期: ${dayData.date}`);
    console.log(`  任务数: ${dayData.tasks.length}`);
    console.log(`  日志数: ${dayData.logs.length}\n`);

    const targetTaskInDay = dayData.tasks.find(t => t.title.includes(targetTaskTitle));
    if (targetTaskInDay) {
      console.log(`✓✓✓ 日视图测试通过！10月3日正确显示跨多天任务`);
      console.log(`    任务: ${targetTaskInDay.title}`);
      console.log(`    开始时间: ${targetTaskInDay.start_time}`);
      console.log(`    结束时间: ${targetTaskInDay.end_time}\n`);
    } else {
      console.log(`✗✗✗ 日视图测试失败！10月3日未显示跨多天任务\n`);
      if (dayData.tasks.length > 0) {
        console.log(`该日期的任务列表：`);
        dayData.tasks.forEach(t => console.log(`  - ${t.title}`));
      }
    }

    console.log('=== 所有测试完成 ===');

  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    process.exit(1);
  }
}

runTests();


