const mysql = require('mysql2/promise');
const crypto = require('crypto');

async function insertUser() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
      user: 'pdl123',
      password: 'Pdl1234567',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4',
      multipleStatements: true
    });

    console.log('\n=== 开始插入新用户 ===\n');

    // 检查用户名是否已存在
    const [existingUsers] = await connection.execute(
      'SELECT id, username FROM users WHERE username = ?',
      ['hyx']
    );

    if (existingUsers.length > 0) {
      console.log('❌ 用户名 "hyx" 已存在！');
      console.log(`   用户ID: ${existingUsers[0].id}`);
      await connection.end();
      return;
    }

    // 获取第一个部门ID（如果存在）
    const [departments] = await connection.execute(
      'SELECT id, name FROM departments LIMIT 1'
    );

    if (departments.length === 0) {
      console.log('❌ 错误：数据库中没有部门，请先创建部门！');
      await connection.end();
      return;
    }

    const departmentId = departments[0].id;
    const departmentName = departments[0].name;
    console.log(`使用部门: ${departmentName} (${departmentId})`);

    // 生成用户ID
    const userId = crypto.randomUUID();
    const username = 'hyx';
    const password = 'hyx123';
    const name = 'hyx'; // 使用用户名作为姓名
    const position = '员工'; // 默认职位
    const role = 'employee'; // 默认角色

    // 插入用户
    await connection.execute(
      `INSERT INTO users (id, username, password, name, position, department_id, role, is_active, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, NOW())`,
      [userId, username, password, name, position, departmentId, role]
    );

    console.log('✓ 用户插入成功！');
    console.log(`   用户ID: ${userId}`);
    console.log(`   用户名: ${username}`);
    console.log(`   姓名: ${name}`);
    console.log(`   职位: ${position}`);
    console.log(`   角色: ${role}`);
    console.log(`   部门: ${departmentName}`);
    console.log(`   密码: ${password}`);

    // 验证插入
    const [newUser] = await connection.execute(
      'SELECT id, username, name, position, role, department_id FROM users WHERE username = ?',
      [username]
    );

    if (newUser.length > 0) {
      console.log('\n✓ 用户验证成功！');
    }

    await connection.end();
    console.log('\n✓ 所有操作完成！');

  } catch (error) {
    console.error('\n❌ 插入失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

insertUser();

