const mysql = require('mysql2/promise');

async function checkCurrentData() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'Zs462581379',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('=== 当前日志数据 ===\n');
    
    const [logs] = await connection.execute(`
      SELECT 
        id,
        user_id,
        title,
        created_at,
        DATE_FORMAT(created_at, '%Y-%m-%d') as log_date
      FROM personal_logs
      ORDER BY created_at DESC
    `);
    
    console.log(`总共 ${logs.length} 条日志:\n`);
    logs.forEach((log, idx) => {
      console.log(`${idx + 1}. [${log.log_date}] ${log.title} (用户: ${log.user_id})`);
    });
    
    console.log('\n=== 当前任务数据 ===\n');
    
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        user_id,
        title,
        due_date,
        DATE_FORMAT(due_date, '%Y-%m-%d') as task_date
      FROM tasks
      WHERE due_date IS NOT NULL
      ORDER BY due_date DESC
      LIMIT 20
    `);
    
    console.log(`最近 ${tasks.length} 条任务:\n`);
    tasks.forEach((task, idx) => {
      console.log(`${idx + 1}. [${task.task_date}] ${task.title} (用户: ${task.user_id})`);
    });
    
    await connection.end();
    
  } catch (error) {
    console.error('检查失败:', error.message);
    process.exit(1);
  }
}

checkCurrentData();













