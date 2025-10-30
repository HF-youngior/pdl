@echo off
echo ========================================
echo 快速查看有个人日志的用户信息
echo ========================================
echo.

cd /d "%~dp0"
node -e "
const mysql = require('mysql2/promise');

async function quickCheck() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'Zs462581379',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('📝 有个人日志的用户账号信息:\n');
    
    const [users] = await connection.execute(\`
      SELECT 
        u.username,
        u.name,
        u.position,
        d.name as department,
        COUNT(pl.id) as log_count,
        MAX(pl.created_at) as last_log
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      INNER JOIN personal_logs pl ON u.id = pl.user_id
      GROUP BY u.id, u.username, u.name, u.position, d.name
      ORDER BY log_count DESC
    \`);
    
    users.forEach((user, idx) => {
      console.log(\`\${idx + 1}. 用户名: \${user.username}\`);
      console.log(\`   姓名: \${user.name} | 职位: \${user.position}\`);
      console.log(\`   部门: \${user.department} | 日志数: \${user.log_count}\`);
      console.log(\`   最新日志: \${user.last_log.toISOString().split('T')[0]}\`);
      console.log('');
    });
    
    console.log(\`总计: \${users.length} 个用户有个人日志记录\`);
    
    await connection.end();
  } catch (error) {
    console.error('查询失败:', error.message);
  }
}

quickCheck();
"

echo.
echo ========================================
pause


