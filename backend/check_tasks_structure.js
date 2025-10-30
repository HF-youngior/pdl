const mysql = require('mysql2/promise');

async function checkTasksStructure() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'Pyx_07091817',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('=== 任务表结构 ===\n');
    
    const [columns] = await connection.execute(`
      SHOW COLUMNS FROM tasks
    `);
    
    columns.forEach(col => {
      console.log(`- ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
    console.log('\n=== 现有任务数据样本 ===\n');
    
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        title,
        due_date,
        DATE_FORMAT(due_date, '%Y-%m-%d') as task_date
      FROM tasks
      WHERE due_date IS NOT NULL
      ORDER BY due_date DESC
      LIMIT 10
    `);
    
    console.log(`任务数量: ${tasks.length}\n`);
    tasks.forEach((task, idx) => {
      console.log(`${idx + 1}. [${task.task_date}] ${task.title}`);
    });
    
    await connection.end();
    
  } catch (error) {
    console.error('检查失败:', error.message);
    process.exit(1);
  }
}

checkTasksStructure();













