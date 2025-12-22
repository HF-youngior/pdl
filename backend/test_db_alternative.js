const mysql = require('mysql2/promise');
require('dotenv').config();

// 数据库配置
const host = process.env.DB_HOST || 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com';
const user = process.env.DB_USER || 'pdl123';
const password = process.env.DB_PASSWORD || 'Pdl1234567';
const database = process.env.DB_NAME || 'enterprise_management';
const port = process.env.DB_PORT || 3306;

console.log('===== 尝试不同的数据库连接配置 =====');
console.log('配置信息:');
console.log(`  主机: ${host}`);
console.log(`  端口: ${port}`);
console.log(`  用户: ${user}`);
console.log(`  数据库: ${database}`);
console.log('');

// 尝试不同的连接配置
const configs = [
  {
    name: '基础配置',
    config: {
      host,
      user,
      password,
      database,
      port,
      charset: 'utf8mb4'
    }
  },
  {
    name: '增加超时时间',
    config: {
      host,
      user,
      password,
      database,
      port,
      charset: 'utf8mb4',
      connectTimeout: 60000,
      acquireTimeout: 60000
    }
  },
  {
    name: '不指定数据库',
    config: {
      host,
      user,
      password,
      port,
      charset: 'utf8mb4',
      connectTimeout: 60000
    }
  },
  {
    name: '添加SSL配置',
    config: {
      host,
      user,
      password,
      database,
      port,
      charset: 'utf8mb4',
      ssl: {
        rejectUnauthorized: false
      }
    }
  }
];

async function testConfigs() {
  for (const { name, config } of configs) {
    console.log(`\n尝试配置: ${name}`);
    try {
      console.log('  正在连接...');
      const connection = await mysql.createConnection(config);
      console.log('  ✅ 连接成功！');
      
      // 如果没有指定数据库，尝试使用数据库
      if (!config.database) {
        try {
          await connection.query(`USE ${database}`);
          console.log(`  ✅ 成功切换到数据库: ${database}`);
        } catch (error) {
          console.log(`  ❌ 切换数据库失败: ${error.message}`);
        }
      }
      
      // 执行简单查询
      const [rows] = await connection.execute('SELECT 1 as test');
      console.log(`  ✅ 查询成功: ${JSON.stringify(rows)}`);
      
      await connection.end();
      console.log('  ✅ 连接已关闭');
      
      // 如果成功连接，可以退出循环
      console.log('\n✅ 找到可用的连接配置！');
      return;
      
    } catch (error) {
      console.log(`  ❌ 连接失败: ${error.code} - ${error.message}`);
    }
  }
  
  console.log('\n❌ 所有配置都无法连接到数据库');
  
  // 提供额外的建议
  console.log('\n其他可能的解决方案:');
  console.log('1. 检查是否需要VPN或其他网络配置');
  console.log('2. 确认数据库服务器是否允许外部IP连接');
  console.log('3. 检查阿里云RDS安全组设置是否允许您的IP地址访问');
  console.log('4. 尝试使用其他网络环境（如手机热点）连接');
  console.log('5. 联系数据库管理员确认服务器状态和访问权限');
}

testConfigs();