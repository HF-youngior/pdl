const mysql = require('mysql2/promise');

async function testConnection() {
  try {
    console.log('正在测试数据库连接...');
    
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'hyx123456',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('数据库连接成功！');
    
    // 测试查询
    const [rows] = await connection.execute('SELECT COUNT(*) as count FROM users');
    console.log(`用户表中有 ${rows[0].count} 个用户`);
    
    const [deptRows] = await connection.execute('SELECT COUNT(*) as count FROM departments');
    console.log(`部门表中有 ${deptRows[0].count} 个部门`);
    
    const [taskRows] = await connection.execute('SELECT COUNT(*) as count FROM tasks');
    console.log(`任务表中有 ${taskRows[0].count} 个任务`);
    
    await connection.end();
    console.log('数据库连接测试完成！');
    
  } catch (error) {
    console.error('数据库连接失败:', error.message);
    process.exit(1);
  }
}

testConnection();
