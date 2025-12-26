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

async function testRealAPIResponse() {
  const connection = await mysql.createConnection({
    host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
    user: 'pdl123',
    password: 'Pdl1234567',
    database: 'enterprise_management',
    timezone: '+08:00'
  });

  try {
    console.log('\n=== 测试日视图API（模拟10月26日查询）===\n');
    
    // 模拟日视图API查询
    const date = '2025-10-26';
    const [tasks] = await connection.execute(
      `SELECT * FROM tasks 
       WHERE (DATE(start_time) = ? 
              OR DATE(end_time) = ? 
              OR (DATE(start_time) <= ? AND DATE(end_time) >= ?))
       AND title LIKE '%员工满意度提升行动计划%'`,
      [date, date, date, date]
    );

    console.log(`查询日期: ${date}`);
    console.log(`找到任务数: ${tasks.length}`);
    
    if (tasks.length > 0) {
      const task = tasks[0];
      console.log('\n原始数据库数据:');
      console.log(`  start_time: ${task.start_time}`);
      console.log(`  end_time: ${task.end_time}`);
      
      console.log('\nAPI返回的JSON（转换后）:');
      const apiTask = {
        id: task.id,
        title: task.title,
        start_time: formatDateTimeForBeijing(task.start_time),
        end_time: formatDateTimeForBeijing(task.end_time)
      };
      console.log(JSON.stringify(apiTask, null, 2));
      
      console.log('\n✅ 10月26日应该能看到这个任务');
    } else {
      console.log('\n❌ 10月26日查询不到这个任务！');
    }

    console.log('\n=== 测试日视图API（模拟10月28日查询）===\n');
    
    const date2 = '2025-10-28';
    const [tasks2] = await connection.execute(
      `SELECT * FROM tasks 
       WHERE (DATE(start_time) = ? 
              OR DATE(end_time) = ? 
              OR (DATE(start_time) <= ? AND DATE(end_time) >= ?))
       AND title LIKE '%员工满意度提升行动计划%'`,
      [date2, date2, date2, date2]
    );

    console.log(`查询日期: ${date2}`);
    console.log(`找到任务数: ${tasks2.length}`);
    
    if (tasks2.length > 0) {
      console.log('✅ 10月28日能看到这个任务');
    }

    // 测试DATE()函数的行为
    console.log('\n=== 测试DATE()函数 ===\n');
    const [dateTest] = await connection.execute(
      `SELECT 
        start_time,
        end_time,
        DATE(start_time) as start_date,
        DATE(end_time) as end_date,
        DATE(start_time) = '2025-10-26' as matches_oct26,
        DATE(start_time) <= '2025-10-26' as start_before_oct26,
        DATE(end_time) >= '2025-10-26' as end_after_oct26
       FROM tasks 
       WHERE title LIKE '%员工满意度提升行动计划%'`
    );

    if (dateTest.length > 0) {
      const test = dateTest[0];
      console.log('DATE()函数结果:');
      console.log(`  start_date: ${test.start_date}`);
      console.log(`  end_date: ${test.end_date}`);
      console.log(`  matches_oct26: ${test.matches_oct26}`);
      console.log(`  start_before_oct26: ${test.start_before_oct26}`);
      console.log(`  end_after_oct26: ${test.end_after_oct26}`);
      
      if (test.start_before_oct26 && test.end_after_oct26) {
        console.log('\n✅ 按理说10月26日应该能查到这个任务');
      }
    }

  } finally {
    await connection.end();
  }
}

testRealAPIResponse().catch(console.error);


