/**
 * 重置 hr_head 用户密码脚本
 * 此脚本会将 hr_head 用户的密码重置为 hr123（使用 bcrypt 加密）
 */

require('dotenv').config();
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const BCRYPT_ROUNDS = 10;
const hashPassword = async (plain) => bcrypt.hash(plain.trim(), BCRYPT_ROUNDS);

async function resetHrHeadPassword() {
  let connection;
  
  try {
    // 创建数据库连接
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'enterprise_management'
    });

    console.log('🔗 数据库连接成功');

    // 生成新的密码哈希
    const newPassword = 'hr123';
    const hashedPassword = await hashPassword(newPassword);
    console.log('🔒 已生成密码哈希');

    // 更新密码
    const [result] = await connection.execute(
      `UPDATE users SET password = ? WHERE username = 'hr_head'`,
      [hashedPassword]
    );

    if (result.affectedRows > 0) {
      console.log(`✅ hr_head 用户密码已成功重置为: ${newPassword}`);
      console.log(`   影响行数: ${result.affectedRows}`);
      
      // 验证更新
      const [users] = await connection.execute(
        `SELECT username, name, role, 
         CASE 
           WHEN password LIKE '$2%' THEN 'bcrypt加密'
           ELSE '明文'
         END as password_type
         FROM users WHERE username = 'hr_head'`
      );
      
      if (users.length > 0) {
        console.log(`\n📋 用户信息:`);
        console.log(`   用户名: ${users[0].username}`);
        console.log(`   姓名: ${users[0].name}`);
        console.log(`   角色: ${users[0].role}`);
        console.log(`   密码类型: ${users[0].password_type}`);
      }
    } else {
      console.log('⚠️  未找到 hr_head 用户，请检查用户名是否正确');
    }

  } catch (error) {
    console.error('❌ 重置密码失败:', error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 数据库连接已关闭');
    }
  }
}

// 运行脚本
resetHrHeadPassword()
  .then(() => {
    console.log('\n✨ 脚本执行完成');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ 脚本执行失败:', error);
    process.exit(1);
  });

