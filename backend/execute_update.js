const mysql = require('mysql2/promise');
const fs = require('fs').promises;
const path = require('path');

async function executeUpdate() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'asdfgh0625YYH',
      database: 'enterprise_management',
      port: 3306,
      charset: 'utf8mb4',
      multipleStatements: true
    });

    console.log('\n=== 开始更新任务和日志数据 ===\n');

    // 读取SQL文件
    const sqlFile = path.join(__dirname, 'update_real_task_dates.sql');
    const sql = await fs.readFile(sqlFile, 'utf8');

    // 执行SQL
    console.log('正在执行SQL更新...');
    await connection.query(sql);

    console.log('✓ SQL执行完成！\n');

    // 查看更新后的统计
    console.log('=== 更新后的数据统计 ===\n');
    
    const [stats] = await connection.execute(`
      SELECT 
        COUNT(*) as total_tasks,
        COUNT(CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL THEN 1 END) as tasks_with_dates,
        COUNT(CASE WHEN DATEDIFF(end_time, start_time) > 0 THEN 1 END) as multi_day_tasks
      FROM tasks
    `);

    const stat = stats[0];
    console.log(`总任务数: ${stat.total_tasks}`);
    console.log(`有完整时间段的任务: ${stat.tasks_with_dates}`);
    console.log(`跨多天的任务: ${stat.multi_day_tasks}`);
    console.log('');

    // 查询跨多天的任务示例
    console.log('=== 跨多天任务示例（前10个） ===\n');
    const [multiDayTasks] = await connection.execute(`
      SELECT 
        title,
        DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
        DATE_FORMAT(end_time, '%Y-%m-%d') as end_date,
        DATEDIFF(end_time, start_time) + 1 as duration_days,
        status
      FROM tasks
      WHERE DATEDIFF(end_time, start_time) > 0
      ORDER BY start_time
      LIMIT 10
    `);

    multiDayTasks.forEach((task, index) => {
      const statusText = {
        'pending': '待办',
        'in_progress': '进行中',
        'completed': '已完成',
        'cancelled': '已取消'
      }[task.status] || task.status;
      
      console.log(`${index + 1}. ${task.title} [${statusText}]`);
      console.log(`   ${task.start_date} 至 ${task.end_date} (${task.duration_days}天)`);
      console.log('');
    });

    // 查询日志统计
    const [logStats] = await connection.execute(`
      SELECT COUNT(*) as total_logs
      FROM personal_logs
    `);
    console.log(`\n总日志数: ${logStats[0].total_logs}`);

    await connection.end();
    console.log('\n✓ 所有操作完成！');

  } catch (error) {
    console.error('\n❌ 更新失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

executeUpdate();


