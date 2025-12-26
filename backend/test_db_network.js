const mysql = require('mysql2/promise');
const net = require('net');

async function testConnection() {
  console.log('='.repeat(60));
  console.log('测试数据库网络连接');
  console.log('='.repeat(60));
  console.log();

  const dbHost = 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com';
  const dbPort = 3306;
  const dbUser = 'pdl123';
  const dbPassword = 'Pdl1234567';
  const dbName = 'enterprise_management';

  // 测试1: DNS解析
  console.log('📡 [1/3] 测试DNS解析...');
  try {
    const dns = require('dns').promises;
    const addresses = await dns.resolve4(dbHost);
    console.log('✅ DNS解析成功:', addresses);
  } catch (error) {
    console.log('❌ DNS解析失败:', error.message);
    console.log('   → 请检查网络连接');
    return;
  }
  console.log();

  // 测试2: TCP端口连接
  console.log('🔌 [2/3] 测试TCP端口连接...');
  const tcpTest = new Promise((resolve, reject) => {
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error('连接超时（10秒）'));
    }, 10000);

    socket.connect(dbPort, dbHost, () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve('成功');
    });

    socket.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });

  try {
    await tcpTest;
    console.log(`✅ TCP端口 ${dbPort} 连接成功`);
  } catch (error) {
    console.log(`❌ TCP端口 ${dbPort} 连接失败:`, error.message);
    console.log('   → 可能原因:');
    console.log('      1. 您的IP没有在数据库白名单中');
    console.log('      2. 防火墙阻止了连接');
    console.log('      3. 数据库服务器不可用');
    console.log();
    console.log('   💡 解决方案:');
    console.log('      请在阿里云RDS控制台添加您的IP到白名单');
    return;
  }
  console.log();

  // 测试3: MySQL认证
  console.log('🔐 [3/3] 测试MySQL认证...');
  try {
    const connection = await mysql.createConnection({
      host: dbHost,
      user: dbUser,
      password: dbPassword,
      database: dbName,
      connectTimeout: 10000
    });
    
    console.log('✅ MySQL认证成功');
    console.log('✅ 数据库连接正常');
    
    // 测试查询
    const [rows] = await connection.query('SELECT 1 as test');
    console.log('✅ 查询测试通过');
    
    await connection.end();
  } catch (error) {
    console.log('❌ MySQL认证失败:', error.message);
    if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.log('   → 用户名或密码错误');
    } else if (error.code === 'ETIMEDOUT') {
      console.log('   → 连接超时，请检查白名单设置');
    }
    return;
  }

  console.log();
  console.log('='.repeat(60));
  console.log('🎉 所有测试通过！数据库连接正常');
  console.log('='.repeat(60));
}

testConnection().catch(console.error);
