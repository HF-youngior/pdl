const mysql = require('mysql2/promise');

// 复制formatDateTimeForBeijing函数
function formatDateTimeForBeijing(dateTime) {
  if (!dateTime) return null;
  
  let date;
  if (dateTime instanceof Date) {
    date = dateTime;
  } else if (typeof dateTime === 'string') {
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

async function testSatisfactionAPI() {
  const connection = await mysql.createConnection({
    host: 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
    user: 'pdl',
    password: 'Pdl123456',
    database: 'enterprise_management',
    timezone: '+08:00'
  });

  try {
    console.log('\n=== 测试员工满意度任务的API返回 ===\n');

    // 查询任务
    const [rows] = await connection.execute(
      `SELECT * FROM tasks WHERE title LIKE '%员工满意度提升行动计划%' LIMIT 1`
    );

    if (rows.length === 0) {
      console.log('未找到任务');
      return;
    }

    const task = rows[0];
    
    console.log('数据库原始数据：');
    console.log(`  start_time: ${task.start_time}`);
    console.log(`  end_time: ${task.end_time}`);
    
    console.log('\n转换后的API返回格式（formatDateTimeForBeijing）：');
    const apiStartTime = formatDateTimeForBeijing(task.start_time);
    const apiEndTime = formatDateTimeForBeijing(task.end_time);
    console.log(`  start_time: ${apiStartTime}`);
    console.log(`  end_time: ${apiEndTime}`);

    // 解析检查
    console.log('\n前端DateTime.parse()解析后：');
    const startDate = new Date(apiStartTime);
    const endDate = new Date(apiEndTime);
    console.log(`  start: ${startDate.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })}`);
    console.log(`  end: ${endDate.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })}`);
    
    console.log('\n应该显示的日期：');
    let currentDate = new Date(startDate);
    const dates = [];
    while (currentDate <= endDate) {
      const dateStr = currentDate.toISOString().split('T')[0];
      dates.push(dateStr);
      console.log(`  ${dateStr} (${['周日', '周一', '周二', '周三', '周四', '周五', '周六'][currentDate.getDay()]})`);
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    console.log(`\n总共应该显示 ${dates.length} 天：${dates.join(', ')}`);

    // 测试月视图逻辑
    console.log('\n=== 测试月视图逻辑 ===');
    const startTime = new Date(task.start_time);
    const endTime = new Date(task.end_time);
    
    console.log(`startTime对象: ${startTime}`);
    console.log(`endTime对象: ${endTime}`);
    
    let current = new Date(startTime);
    const monthDates = [];
    while (current <= endTime) {
      const dateKey = `${current.getFullYear()}-${String(current.getMonth() + 1).padStart(2, '0')}-${String(current.getDate()).padStart(2, '0')}`;
      monthDates.push(dateKey);
      current.setDate(current.getDate() + 1);
    }
    console.log(`月视图应该在这些日期显示: ${monthDates.join(', ')}`);

  } finally {
    await connection.end();
  }
}

testSatisfactionAPI().catch(console.error);

