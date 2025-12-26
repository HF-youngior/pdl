const mysql = require('mysql2/promise');

async function checkCurrentTasks() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
      user: 'pdl',
      password: 'Pdl123456',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('\n=== 当前任务数据概览 ===\n');

    // 查询总数
    const [countResult] = await connection.execute(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN start_time IS NOT NULL THEN 1 END) as with_start,
        COUNT(CASE WHEN end_time IS NOT NULL THEN 1 END) as with_end
      FROM tasks
    `);

    console.log(`总任务数: ${countResult[0].total}`);
    console.log(`有开始时间: ${countResult[0].with_start}`);
    console.log(`有结束时间: ${countResult[0].with_end}`);
    console.log('');

    // 查询10月份的任务（前20条）
    console.log('=== 2025年10月份的任务 ===\n');
    const [octTasks] = await connection.execute(`
      SELECT 
        id,
        title,
        DATE_FORMAT(created_at, '%Y-%m-%d') as created_date,
        DATE_FORMAT(start_time, '%Y-%m-%d %H:%i') as start,
        DATE_FORMAT(end_time, '%Y-%m-%d %H:%i') as end_t,
        status
      FROM tasks
      WHERE DATE(created_at) >= '2025-10-01' AND DATE(created_at) <= '2025-10-31'
      ORDER BY created_at
      LIMIT 30
    `);

    octTasks.forEach((task, index) => {
      console.log(`${index + 1}. [${task.created_date}] ${task.title}`);
      console.log(`   状态: ${task.status || '无'}`);
      console.log(`   开始: ${task.start || '无'} | 结束: ${task.end_t || '无'}`);
      console.log('');
    });

    // 查询11月份的任务（前20条）
    console.log('\n=== 2025年11月份的任务 ===\n');
    const [novTasks] = await connection.execute(`
      SELECT 
        id,
        title,
        DATE_FORMAT(created_at, '%Y-%m-%d') as created_date,
        DATE_FORMAT(start_time, '%Y-%m-%d %H:%i') as start,
        DATE_FORMAT(end_time, '%Y-%m-%d %H:%i') as end_t,
        status
      FROM tasks
      WHERE DATE(created_at) >= '2025-11-01' AND DATE(created_at) <= '2025-11-30'
      ORDER BY created_at
      LIMIT 30
    `);

    novTasks.forEach((task, index) => {
      console.log(`${index + 1}. [${task.created_date}] ${task.title}`);
      console.log(`   状态: ${task.status || '无'}`);
      console.log(`   开始: ${task.start || '无'} | 结束: ${task.end_t || '无'}`);
      console.log('');
    });

    await connection.end();

  } catch (error) {
    console.error('❌ 查询失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

checkCurrentTasks();


