const mysql = require('mysql2/promise');

async function debugMonthView() {
  const db = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'hyx123456',
    database: 'pdl_enterprise',
    timezone: '+08:00'
  });

  console.log('=== 检查 personal_logs 表最近的数据 ===\n');
  
  const [logs] = await db.execute(`
    SELECT 
      id, 
      user_id,
      title,
      created_at,
      DATE_FORMAT(created_at, '%Y-%m-%d') as log_date,
      DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as formatted_date
    FROM personal_logs 
    ORDER BY created_at DESC 
    LIMIT 10
  `);
  
  console.table(logs);
  
  console.log('\n=== 测试月视图查询（2024年10月）===\n');
  
  const year = 2024;
  const month = 10;
  const startDate = `${year}-${String(month).padStart(2, '0')}-01 00:00:00`;
  const lastDay = new Date(year, month, 0).getDate();
  const endDate = `${year}-${String(month).padStart(2, '0')}-${lastDay} 23:59:59`;
  
  console.log(`查询范围: ${startDate} 到 ${endDate}\n`);
  
  const [monthLogs] = await db.execute(`
    SELECT 
      id,
      user_id,
      title,
      created_at,
      DATE_FORMAT(created_at, '%Y-%m-%d') as log_date
    FROM personal_logs
    WHERE created_at >= ? AND created_at <= ?
    ORDER BY created_at DESC
  `, [startDate, endDate]);
  
  console.log(`找到 ${monthLogs.length} 条日志记录：`);
  console.table(monthLogs.slice(0, 20));
  
  console.log('\n=== 检查 tasks 表最近的数据 ===\n');
  
  const [tasks] = await db.execute(`
    SELECT 
      id,
      assignee_id,
      title,
      start_time,
      end_time,
      deadline,
      DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
      DATE_FORMAT(deadline, '%Y-%m-%d') as deadline_date
    FROM tasks
    ORDER BY created_at DESC
    LIMIT 10
  `);
  
  console.table(tasks);
  
  await db.end();
}

debugMonthView().catch(console.error);

