const mysql = require('mysql2/promise');

async function checkUsersStructure() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'hyx123456',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('=== users 表结构 ===\n');
    
    const [columns] = await connection.execute(`
      SHOW COLUMNS FROM users
    `);
    
    columns.forEach(col => {
      console.log(`- ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
    console.log('\n=== 用户数据示例 ===\n');
    const [users] = await connection.execute(`
      SELECT * FROM users LIMIT 5
    `);
    
    users.forEach(user => {
      console.log(JSON.stringify(user, null, 2));
    });
    
    await connection.end();
    
  } catch (error) {
    console.error('检查失败:', error.message);
    process.exit(1);
  }
}

checkUsersStructure();


