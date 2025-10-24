const mysql = require('mysql2/promise');

async function checkLogsStructure() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: '23301144',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('=== personal_logs 表结构 ===\n');
    
    const [columns] = await connection.execute(`
      SHOW COLUMNS FROM personal_logs
    `);
    
    columns.forEach(col => {
      console.log(`- ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
    await connection.end();
    
  } catch (error) {
    console.error('检查失败:', error.message);
    process.exit(1);
  }
}

checkLogsStructure();









