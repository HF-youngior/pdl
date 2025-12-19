const mysql = require('mysql2/promise');
require('dotenv').config();

// 数据库配置
const dbConfig = {
  host: process.env.DB_HOST || 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl123',
  password: process.env.DB_PASSWORD || 'Pdl1234567',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4',
  connectTimeout: 10000,
  acquireTimeout: 10000,
  timeout: 10000
};

console.log('正在测试远程数据库连接...');
console.log('配置信息:');
console.log(`  主机: ${dbConfig.host}`);
console.log(`  端口: ${dbConfig.port}`);
console.log(`  用户: ${dbConfig.user}`);
console.log(`  数据库: ${dbConfig.database}`);
console.log('');

async function testConnection() {
  try {
    console.log('尝试连接数据库...');
    const connection = await mysql.createConnection(dbConfig);
    console.log('✅ 数据库连接成功！');
    
    // 测试查询
    console.log('\n执行测试查询...');
    const [rows] = await connection.execute('SELECT VERSION() as version');
    console.log(`MySQL版本: ${rows[0].version}`);
    
    // 检查数据库是否存在
    const [dbRows] = await connection.execute('SHOW DATABASES');
    const dbExists = dbRows.some(row => row.Database === dbConfig.database);
    console.log(`数据库 ${dbConfig.database} 是否存在: ${dbExists ? '是' : '否'}`);
    
    if (dbExists) {
      // 检查表是否存在
      await connection.changeUser({ database: dbConfig.database });
      const [tables] = await connection.execute('SHOW TABLES');
      console.log(`数据库中的表数量: ${tables.length}`);
      
      if (tables.length > 0) {
        console.log('表列表:');
        tables.forEach(table => {
          const tableName = Object.values(table)[0];
          console.log(`  - ${tableName}`);
        });
      }
    }
    
    await connection.end();
    console.log('\n✅ 数据库连接测试完成！');
    
  } catch (error) {
    console.error('❌ 数据库连接失败:');
    console.error(`错误代码: ${error.code}`);
    console.error(`错误信息: ${error.message}`);
    console.error(`错误详情: ${error.errno}`);
    
    // 提供常见问题的解决建议
    console.log('\n可能的解决方案:');
    
    if (error.code === 'ECONNREFUSED') {
      console.log('1. 检查数据库服务器是否运行');
      console.log('2. 检查主机地址和端口是否正确');
      console.log('3. 检查防火墙设置是否阻止连接');
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.log('1. 检查用户名和密码是否正确');
      console.log('2. 检查用户是否有访问该数据库的权限');
    } else if (error.code === 'ENOTFOUND') {
      console.log('1. 检查主机名是否正确');
      console.log('2. 检查DNS解析是否正常');
    } else if (error.code === 'ETIMEDOUT') {
      console.log('1. 检查网络连接是否稳定');
      console.log('2. 检查数据库服务器响应时间');
      console.log('3. 尝试增加连接超时时间');
    } else {
      console.log('1. 检查网络连接');
      console.log('2. 联系数据库管理员');
    }
    
    process.exit(1);
  }
}

testConnection();