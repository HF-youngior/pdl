// 检查personal_logs表结构
const mysql = require('mysql2/promise');

const dbConfig = {
  host: process.env.DB_HOST || 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl123',
  password: process.env.DB_PASSWORD || 'Pdl1234567',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
};

async function checkTable() {
  let connection;
  try {
    connection = await mysql.createConnection(dbConfig);
    console.log('已连接到数据库');
    
    // 获取表结构
    const [columns] = await connection.execute(`DESCRIBE personal_logs`);
    console.log('\n=== personal_logs 表结构 ===');
    console.table(columns);
    
    // 检查是否有log_date字段
    const hasLogDate = columns.some(col => col.Field === 'log_date');
    console.log(`\n是否有 log_date 字段: ${hasLogDate ? '✅ 是' : '❌ 否'}`);
    
    if (!hasLogDate) {
      console.log('\n尝试添加 log_date 字段...');
      try {
        await connection.execute(`ALTER TABLE personal_logs ADD COLUMN log_date DATE NULL`);
        console.log('✅ log_date 字段添加成功');
      } catch (error) {
        console.error('❌ 添加字段失败:', error.message);
      }
    }
    
    // 再次检查
    if (!hasLogDate) {
      const [newColumns] = await connection.execute(`DESCRIBE personal_logs`);
      const nowHasLogDate = newColumns.some(col => col.Field === 'log_date');
      console.log(`添加后是否有 log_date 字段: ${nowHasLogDate ? '✅ 是' : '❌ 否'}`);
    }
    
  } catch (error) {
    console.error('错误:', error.message);
  } finally {
    if (connection) connection.end();
  }
}

checkTable();


