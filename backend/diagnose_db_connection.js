const mysql = require('mysql2/promise');
const dns = require('dns').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

require('dotenv').config();

// 数据库配置
const dbConfig = {
  host: process.env.DB_HOST || 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl123',
  password: process.env.DB_PASSWORD || 'Pdl1234567',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4',
  connectTimeout: 30000, // 增加连接超时时间到30秒
  acquireTimeout: 30000,
  timeout: 30000
};

console.log('===== 数据库连接诊断工具 =====');
console.log('配置信息:');
console.log(`  主机: ${dbConfig.host}`);
console.log(`  端口: ${dbConfig.port}`);
console.log(`  用户: ${dbConfig.user}`);
console.log(`  数据库: ${dbConfig.database}`);
console.log('');

async function diagnoseConnection() {
  try {
    // 1. DNS解析测试
    console.log('1. 测试DNS解析...');
    try {
      const addresses = await dns.resolve4(dbConfig.host);
      console.log(`✅ DNS解析成功: ${dbConfig.host} -> ${addresses.join(', ')}`);
    } catch (error) {
      console.log(`❌ DNS解析失败: ${error.message}`);
      return;
    }
    
    // 2. 网络连通性测试（ping）
    console.log('\n2. 测试网络连通性（ping）...');
    try {
      const { stdout, stderr } = await execAsync(`ping -n 4 ${dbConfig.host}`);
      console.log('✅ 网络连通性测试成功');
      // 提取ping统计信息
      const lines = stdout.split('\n');
      const summaryLine = lines.find(line => line.includes('数据包') || line.includes('Packets'));
      if (summaryLine) {
        console.log(`   ${summaryLine.trim()}`);
      }
    } catch (error) {
      console.log(`❌ 网络连通性测试失败: ${error.message}`);
    }
    
    // 3. 端口连通性测试
    console.log('\n3. 测试端口连通性...');
    try {
      const { stdout, stderr } = await execAsync(`telnet ${dbConfig.host} ${dbConfig.port}`, { timeout: 5000 });
      console.log('✅ 端口连通性测试成功');
    } catch (error) {
      console.log(`❌ 端口连通性测试失败: ${error.message}`);
      console.log('   尝试使用PowerShell测试端口...');
      try {
        const { stdout, stderr } = await execAsync(`powershell -Command "Test-NetConnection -ComputerName ${dbConfig.host} -Port ${dbConfig.port}"`, { timeout: 10000 });
        console.log('✅ PowerShell端口测试结果:');
        console.log(stdout);
      } catch (psError) {
        console.log(`❌ PowerShell端口测试也失败: ${psError.message}`);
      }
    }
    
    // 4. MySQL连接测试
    console.log('\n4. 测试MySQL连接...');
    try {
      console.log('   尝试连接数据库...');
      const connection = await mysql.createConnection(dbConfig);
      console.log('✅ MySQL连接成功！');
      
      // 测试查询
      console.log('\n5. 执行测试查询...');
      const [rows] = await connection.execute('SELECT VERSION() as version');
      console.log(`   MySQL版本: ${rows[0].version}`);
      
      // 检查数据库是否存在
      const [dbRows] = await connection.execute('SHOW DATABASES');
      const dbExists = dbRows.some(row => row.Database === dbConfig.database);
      console.log(`   数据库 ${dbConfig.database} 是否存在: ${dbExists ? '是' : '否'}`);
      
      if (dbExists) {
        // 检查表是否存在
        await connection.changeUser({ database: dbConfig.database });
        const [tables] = await connection.execute('SHOW TABLES');
        console.log(`   数据库中的表数量: ${tables.length}`);
        
        if (tables.length > 0) {
          console.log('   表列表:');
          tables.forEach(table => {
            const tableName = Object.values(table)[0];
            console.log(`     - ${tableName}`);
          });
        }
      }
      
      await connection.end();
      console.log('\n✅ 所有测试通过！数据库连接正常。');
      
    } catch (error) {
      console.error('❌ MySQL连接失败:');
      console.error(`   错误代码: ${error.code}`);
      console.error(`   错误信息: ${error.message}`);
      
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
        console.log('4. 检查是否需要VPN或其他网络配置');
      } else {
        console.log('1. 检查网络连接');
        console.log('2. 联系数据库管理员');
      }
    }
    
  } catch (error) {
    console.error('诊断过程中发生错误:', error.message);
  }
}

diagnoseConnection();