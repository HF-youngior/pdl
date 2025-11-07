const mysql = require('mysql2/promise');

async function checkSatisfactionTask() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '23301144',
    database: 'enterprise_management',
    timezone: '+08:00'
  });

  try {
    // 查找"员工满意度提升行动计划"任务
    const [tasks] = await connection.execute(
      `SELECT id, title, start_time, end_time, 
              DATE(start_time) as start_date, 
              DATE(end_time) as end_date,
              DAYOFWEEK(start_time) as start_weekday,
              DAYOFWEEK(end_time) as end_weekday
       FROM tasks 
       WHERE title LIKE '%员工满意度%'
       ORDER BY start_time DESC
       LIMIT 5`
    );

    console.log('\n=== 员工满意度提升行动计划任务 ===\n');
    
    tasks.forEach(task => {
      console.log(`任务ID: ${task.id}`);
      console.log(`任务标题: ${task.title}`);
      console.log(`开始时间: ${task.start_time}`);
      console.log(`结束时间: ${task.end_time}`);
      console.log(`开始日期: ${task.start_date}`);
      console.log(`结束日期: ${task.end_date}`);
      console.log(`开始是星期: ${getWeekdayName(task.start_weekday)}`);
      console.log(`结束是星期: ${getWeekdayName(task.end_weekday)}`);
      console.log('---');
    });

    // 获取原始存储数据（不带时区转换）
    await connection.query('SET time_zone = "+00:00"');
    const [rawTasks] = await connection.execute(
      `SELECT id, title, start_time, end_time 
       FROM tasks 
       WHERE title LIKE '%员工满意度%'
       ORDER BY start_time DESC
       LIMIT 1`
    );

    console.log('\n=== 原始UTC存储 ===\n');
    if (rawTasks.length > 0) {
      const task = rawTasks[0];
      console.log(`开始时间(UTC): ${task.start_time}`);
      console.log(`结束时间(UTC): ${task.end_time}`);
    }

  } finally {
    await connection.end();
  }
}

function getWeekdayName(dayNum) {
  const days = ['', '周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return days[dayNum];
}

checkSatisfactionTask().catch(console.error);

