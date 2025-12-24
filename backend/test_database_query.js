const mysql = require('mysql2/promise');
require('dotenv').config();

async function testDatabaseQuery() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });

  try {
    console.log('连接数据库成功');
    
    // 查询最近的日志
    const [logs] = await connection.execute(
      'SELECT id, title, location_latitude, location_longitude, created_at FROM personal_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT 5',
      ['admin-001']
    );
    
    console.log('最近的5条日志:');
    logs.forEach(log => {
      console.log(`ID: ${log.id}, 标题: ${log.title}, 纬度: ${log.location_latitude}, 经度: ${log.location_longitude}, 创建时间: ${log.created_at}`);
    });
    
    // 查询特定ID的日志
    const testId = 'a7cbab59-8ece-4bd3-93f4-5bd3b0cc7e97';
    const [specificLog] = await connection.execute(
      'SELECT * FROM personal_logs WHERE id = ?',
      [testId]
    );
    
    if (specificLog.length > 0) {
      console.log('\n特定ID的日志详情:');
      console.log(specificLog[0]);
    } else {
      console.log(`\n未找到ID为 ${testId} 的日志`);
    }
    
  } catch (error) {
    console.error('查询数据库错误:', error);
  } finally {
    await connection.end();
  }
}

testDatabaseQuery();