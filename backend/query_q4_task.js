const mysql = require('mysql2/promise');

async function queryTask() {
  let connection;

  try {
    connection = await mysql.createConnection({
      host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
      user: 'pdl123',
      password: 'Pdl1234567',
      database: 'enterprise_management',
      charset: 'utf8mb4'
    });

    console.log('✓ 数据库连接成功\n');

    const [tasks] = await connection.execute(`
      SELECT 
        id,
        title,
        assignee_id,
        start_time,
        end_time,
        deadline,
        DATE_FORMAT(start_time, '%Y-%m-%d %H:%i') as start_display,
        DATE_FORMAT(end_time, '%Y-%m-%d %H:%i') as end_display,
        DATE_FORMAT(deadline, '%Y-%m-%d') as deadline_display,
        DATEDIFF(end_time, start_time) as duration_days
      FROM tasks
      WHERE title LIKE '%Q4绩效目标设定指导%'
    `);

    if (tasks.length === 0) {
      console.log('❌ 没有找到"Q4绩效目标设定指导"任务');
    } else {
      console.log('找到任务信息：\n');
      tasks.forEach((task, index) => {
        console.log(`任务 ${index + 1}:`);
        console.log(`  ID: ${task.id}`);
        console.log(`  标题: ${task.title}`);
        console.log(`  负责人: ${task.assignee_id}`);
        console.log(`  开始时间: ${task.start_display}`);
        console.log(`  结束时间: ${task.end_display}`);
        console.log(`  截止日期: ${task.deadline_display || '无'}`);
        console.log(`  持续天数: ${task.duration_days} 天`);
        console.log('');
      });
    }

    await connection.end();

  } catch (error) {
    console.error('❌ 查询失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

queryTask();



