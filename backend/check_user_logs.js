const mysql = require('mysql2/promise');

async function checkUserLogs() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'asdfgh0625YYH',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4'
    });

    console.log('=== 用户个人日志统计 ===\n');
    
    // 查询所有用户及其日志数量
    const [userLogs] = await connection.execute(`
      SELECT 
        u.id,
        u.username,
        u.name,
        u.position,
        d.name as department,
        u.role,
        COUNT(pl.id) as log_count,
        MAX(pl.created_at) as last_log_date,
        MIN(pl.created_at) as first_log_date
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      LEFT JOIN personal_logs pl ON u.id = pl.user_id
      GROUP BY u.id, u.username, u.name, u.position, d.name, u.role
      ORDER BY log_count DESC, u.name
    `);
    
    console.log(`总共 ${userLogs.length} 个用户:\n`);
    
    // 有日志的用户
    const usersWithLogs = userLogs.filter(user => user.log_count > 0);
    console.log(`📝 有个人日志的用户 (${usersWithLogs.length} 个):\n`);
    
    usersWithLogs.forEach((user, idx) => {
      console.log(`${idx + 1}. ${user.name} (${user.username})`);
      console.log(`   - 职位: ${user.position} | 部门: ${user.department} | 角色: ${user.role}`);
      console.log(`   - 日志数量: ${user.log_count} 条`);
      console.log(`   - 首次日志: ${user.first_log_date ? user.first_log_date.toISOString().split('T')[0] : 'N/A'}`);
      console.log(`   - 最新日志: ${user.last_log_date ? user.last_log_date.toISOString().split('T')[0] : 'N/A'}`);
      console.log('');
    });
    
    // 没有日志的用户
    const usersWithoutLogs = userLogs.filter(user => user.log_count === 0);
    if (usersWithoutLogs.length > 0) {
      console.log(`❌ 没有个人日志的用户 (${usersWithoutLogs.length} 个):\n`);
      usersWithoutLogs.forEach((user, idx) => {
        console.log(`${idx + 1}. ${user.name} (${user.username}) - ${user.position} | ${user.department}`);
      });
      console.log('');
    }
    
    // 按部门统计
    console.log('📊 按部门统计:\n');
    const [deptStats] = await connection.execute(`
      SELECT 
        d.name as department,
        COUNT(DISTINCT u.id) as total_users,
        COUNT(DISTINCT CASE WHEN pl.id IS NOT NULL THEN u.id END) as users_with_logs,
        COUNT(pl.id) as total_logs
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      LEFT JOIN personal_logs pl ON u.id = pl.user_id
      GROUP BY d.name
      ORDER BY total_logs DESC
    `);
    
    deptStats.forEach(dept => {
      const percentage = dept.total_users > 0 ? ((dept.users_with_logs / dept.total_users) * 100).toFixed(1) : 0;
      console.log(`${dept.department}:`);
      console.log(`  - 总用户数: ${dept.total_users}`);
      console.log(`  - 有日志用户: ${dept.users_with_logs} (${percentage}%)`);
      console.log(`  - 总日志数: ${dept.total_logs}`);
      console.log('');
    });
    
    // 最近7天的日志活动
    console.log('📅 最近7天日志活动:\n');
    const [recentLogs] = await connection.execute(`
      SELECT 
        u.name,
        u.username,
        COUNT(pl.id) as recent_logs,
        MAX(pl.created_at) as last_activity
      FROM users u
      INNER JOIN personal_logs pl ON u.id = pl.user_id
      WHERE pl.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      GROUP BY u.id, u.name, u.username
      ORDER BY recent_logs DESC
    `);
    
    if (recentLogs.length > 0) {
      recentLogs.forEach((user, idx) => {
        console.log(`${idx + 1}. ${user.name} (${user.username}) - ${user.recent_logs} 条日志`);
        console.log(`   最新活动: ${user.last_activity.toISOString().split('T')[0]}`);
      });
    } else {
      console.log('最近7天没有日志活动');
    }
    
    await connection.end();
    
  } catch (error) {
    console.error('查询失败:', error.message);
    process.exit(1);
  }
}

checkUserLogs();
