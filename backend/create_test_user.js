const mysql = require('mysql2/promise');
const crypto = require('crypto');

async function createTestUser() {
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

    console.log('\n=== 创建测试用户（普通员工） ===\n');

    const username = 'test_employee';
    const password = 'test123456';
    const name = '测试员工';
    const position = '测试专员';
    const role = 'employee';

    // 检查用户名是否已存在
    const [existingUsers] = await connection.execute(
      'SELECT id, username FROM users WHERE username = ?',
      [username]
    );

    if (existingUsers.length > 0) {
      console.log('⚠️  用户名 "test_employee" 已存在！');
      console.log(`   用户ID: ${existingUsers[0].id}`);
      console.log('   将使用现有用户进行测试\n');
      await connection.end();
      return existingUsers[0].id;
    }

    // 获取第一个部门ID
    const [departments] = await connection.execute(
      'SELECT id, name FROM departments LIMIT 1'
    );

    if (departments.length === 0) {
      console.log('❌ 错误：数据库中没有部门，请先创建部门！');
      await connection.end();
      return null;
    }

    const departmentId = departments[0].id;
    const departmentName = departments[0].name;
    console.log(`使用部门: ${departmentName} (${departmentId})`);

    // 获取一个team_leader作为parent_id（可选）
    const [teamLeaders] = await connection.execute(
      'SELECT id FROM users WHERE role = ? LIMIT 1',
      ['team_leader']
    );
    const parentId = teamLeaders.length > 0 ? teamLeaders[0].id : null;

    // 生成用户ID
    const userId = crypto.randomUUID();

    // 插入用户（使用明文密码，便于测试）
    await connection.execute(
      `INSERT INTO users (id, username, password, name, position, department_id, role, parent_id, is_active, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE, NOW())`,
      [userId, username, password, name, position, departmentId, role, parentId]
    );

    console.log('✓ 测试用户创建成功！');
    console.log(`   用户ID: ${userId}`);
    console.log(`   用户名: ${username}`);
    console.log(`   密码: ${password}`);
    console.log(`   姓名: ${name}`);
    console.log(`   职位: ${position}`);
    console.log(`   角色: ${role}`);
    console.log(`   部门: ${departmentName}`);
    console.log('\n✅ 用户信息：');
    console.log(`   用户名: ${username}`);
    console.log(`   密码: ${password}`);
    console.log(`   角色: ${role} (普通员工)`);

    await connection.end();
    return userId;

  } catch (error) {
    console.error('\n❌ 创建失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

createTestUser();

