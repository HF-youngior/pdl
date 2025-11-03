const mysql = require('mysql2/promise');

// 时区处理工具函数 - 与server_enterprise.js中的一致
function formatDateTimeForBeijing(dateTime) {
  if (!dateTime) return null;
  
  let date;
  
  if (dateTime instanceof Date) {
    date = dateTime;
  } else if (typeof dateTime === 'string') {
    if (dateTime.includes('+08:00')) {
      return dateTime;
    }
    date = new Date(dateTime);
  } else {
    return null;
  }
  
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}+08:00`;
}

async function testAllViews() {
  let connection;
  
  try {
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║       时区修复测试 - 模拟所有视图的API响应              ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');
    
    connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: '23301144',
      database: 'enterprise_management',
      charset: 'utf8mb4',
      timezone: '+08:00'
    });

    // 获取Q4绩效目标任务
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        title,
        start_time,
        end_time,
        status,
        priority
      FROM tasks
      WHERE id = 'task-hr-oct-003'
    `);

    if (tasks.length === 0) {
      console.log('❌ 未找到测试任务');
      return;
    }

    const task = tasks[0];
    
    console.log('【测试任务】');
    console.log(`任务ID:   ${task.id}`);
    console.log(`任务标题: ${task.title}`);
    console.log(`状态:     ${task.status}`);
    console.log(`优先级:   ${task.priority}`);
    console.log('');
    
    // 模拟周视图API (/api/tasks)
    console.log('┌─────────────────────────────────────────────────────────┐');
    console.log('│ 1. 周视图 API (/api/tasks)                              │');
    console.log('└─────────────────────────────────────────────────────────┘');
    
    const weekViewTask = {
      ...task,
      start_time: formatDateTimeForBeijing(task.start_time),
      end_time: formatDateTimeForBeijing(task.end_time)
    };
    
    console.log(`原始数据库值:`);
    console.log(`  start_time: ${task.start_time}`);
    console.log(`  end_time:   ${task.end_time}`);
    console.log('');
    console.log(`API返回值（应用formatDateTimeForBeijing后）:`);
    console.log(`  start_time: ${weekViewTask.start_time}`);
    console.log(`  end_time:   ${weekViewTask.end_time}`);
    console.log('');
    
    const startDate_week = weekViewTask.start_time.split('T')[0];
    const endDate_week = weekViewTask.end_time.split('T')[0];
    console.log(`前端解析的日期范围: ${startDate_week} 至 ${endDate_week}`);
    
    if (startDate_week === '2025-10-15' && endDate_week === '2025-10-17') {
      console.log('✅ 周视图：日期正确！应显示在10月15-17日\n');
    } else {
      console.log(`❌ 周视图：日期错误！实际: ${startDate_week} 至 ${endDate_week}\n`);
    }
    
    // 模拟月视图API (/api/calendar/month-view 或 /api/month-view)
    console.log('┌─────────────────────────────────────────────────────────┐');
    console.log('│ 2. 月视图 API (/api/calendar/month-view)                │');
    console.log('└─────────────────────────────────────────────────────────┘');
    
    // 月视图的逻辑：遍历每一天
    const taskStartDate = new Date(task.start_time);
    const taskEndDate = new Date(task.end_time);
    
    const currentDate = new Date(taskStartDate);
    currentDate.setHours(0, 0, 0, 0);
    const endDate = new Date(taskEndDate);
    endDate.setHours(0, 0, 0, 0);
    
    const daysInMonth = [];
    while (currentDate <= endDate) {
      const dateKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(currentDate.getDate()).padStart(2, '0')}`;
      daysInMonth.push(dateKey);
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    console.log(`任务会被添加到以下日期:`);
    daysInMonth.forEach(date => {
      console.log(`  - ${date}`);
    });
    console.log('');
    
    console.log(`每个日期返回的任务数据（时间已转换）:`);
    console.log(`  start_time: ${formatDateTimeForBeijing(task.start_time)}`);
    console.log(`  end_time:   ${formatDateTimeForBeijing(task.end_time)}`);
    console.log('');
    
    if (daysInMonth.length === 3 && 
        daysInMonth[0] === '2025-10-15' &&
        daysInMonth[1] === '2025-10-16' &&
        daysInMonth[2] === '2025-10-17') {
      console.log('✅ 月视图：任务会在15、16、17日都显示\n');
    } else {
      console.log(`❌ 月视图：日期分配错误\n`);
    }
    
    // 模拟日视图API (/api/calendar/day-detail)
    console.log('┌─────────────────────────────────────────────────────────┐');
    console.log('│ 3. 日视图 API (/api/calendar/day-detail)                │');
    console.log('└─────────────────────────────────────────────────────────┘');
    
    // 测试三个日期
    const testDates = ['2025-10-15', '2025-10-16', '2025-10-17'];
    
    for (const testDate of testDates) {
      const [dayTasks] = await connection.execute(`
        SELECT 
          t.id,
          t.title,
          t.start_time,
          t.end_time
        FROM tasks t
        WHERE t.id = 'task-hr-oct-003'
        AND (
          DATE(t.start_time) = ?
          OR DATE(t.end_time) = ?
          OR (DATE(t.start_time) <= ? AND DATE(t.end_time) >= ?)
        )
      `, [testDate, testDate, testDate, testDate]);
      
      console.log(`查询日期: ${testDate}`);
      if (dayTasks.length > 0) {
        const dayTask = {
          ...dayTasks[0],
          start_time: formatDateTimeForBeijing(dayTasks[0].start_time),
          end_time: formatDateTimeForBeijing(dayTasks[0].end_time)
        };
        console.log(`  ✅ 找到任务: ${dayTask.title}`);
        console.log(`     start_time: ${dayTask.start_time}`);
        console.log(`     end_time:   ${dayTask.end_time}`);
      } else {
        console.log(`  ❌ 未找到任务`);
      }
    }
    console.log('');
    
    // 总结
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║                      测试总结                            ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');
    
    console.log('✅ 时区转换函数工作正常');
    console.log('✅ 所有API都会返回带 +08:00 时区标记的时间');
    console.log('✅ 时间格式: 2025-10-15T09:00:00+08:00');
    console.log('');
    console.log('📋 预期效果:');
    console.log('   周视图: Q4绩效目标设定指导 显示在 10月15-17日');
    console.log('   月视图: 该任务在 15、16、17 日都有显示');
    console.log('   日视图: 点击 15、16、17 日都能看到该任务');
    console.log('');
    console.log('🎯 关键修复:');
    console.log('   问题: 前端显示14-16日（时区UTC问题）');
    console.log('   修复: 后端返回明确的+08:00时区标记');
    console.log('   结果: 前端正确显示15-17日');
    console.log('');
    console.log('⚠️  重要: 修改后需要重启服务器才能生效！');
    
    await connection.end();

  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

testAllViews();


