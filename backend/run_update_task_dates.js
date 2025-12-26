const mysql = require('mysql2/promise');
const fs = require('fs').promises;
const path = require('path');

async function updateTaskDates() {
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

    console.log('\n=== 开始更新任务时间数据 ===\n');

    // 读取SQL文件
    const sqlFile = path.join(__dirname, 'update_task_dates.sql');
    const sql = await fs.readFile(sqlFile, 'utf8');

    // 执行SQL
    console.log('正在执行SQL更新...\n');
    const [results] = await connection.query(sql);

    console.log('✓ 更新完成！\n');

    // 查看更新后的统计
    console.log('=== 任务时间数据统计 ===\n');
    const [stats] = await connection.execute(`
      SELECT 
        COUNT(*) as total_tasks,
        COUNT(CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL THEN 1 END) as tasks_with_dates,
        COUNT(CASE WHEN DATEDIFF(end_time, start_time) > 0 THEN 1 END) as multi_day_tasks
      FROM tasks
    `);

    const stat = stats[0];
    console.log(`总任务数: ${stat.total_tasks}`);
    console.log(`有时间段的任务: ${stat.tasks_with_dates}`);
    console.log(`跨多天的任务: ${stat.multi_day_tasks}`);
    console.log('');

    // 查询跨多天的任务示例
    console.log('=== 跨多天的任务示例 ===\n');
    const [multiDayTasks] = await connection.execute(`
      SELECT 
        id,
        title,
        DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
        DATE_FORMAT(end_time, '%Y-%m-%d') as end_date,
        DATEDIFF(end_time, start_time) + 1 as duration_days
      FROM tasks
      WHERE DATEDIFF(end_time, start_time) > 0
      ORDER BY start_time
      LIMIT 15
    `);

    multiDayTasks.forEach((task, index) => {
      console.log(`${index + 1}. ${task.title}`);
      console.log(`   时间: ${task.start_date} 至 ${task.end_date} (${task.duration_days}天)`);
      console.log('');
    });

    // 查询本周任务
    const today = new Date();
    const weekStart = new Date(today);
    weekStart.setDate(today.getDate() - today.getDay() + 1); // 本周一
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6); // 本周日

    const weekStartStr = weekStart.toISOString().split('T')[0];
    const weekEndStr = weekEnd.toISOString().split('T')[0];

    console.log(`=== 本周任务 (${weekStartStr} 至 ${weekEndStr}) ===\n`);
    const [weekTasks] = await connection.execute(`
      SELECT 
        id,
        title,
        DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
        DATE_FORMAT(end_time, '%Y-%m-%d') as end_date,
        status,
        priority
      FROM tasks
      WHERE (DATE(start_time) BETWEEN ? AND ?) 
         OR (DATE(end_time) BETWEEN ? AND ?)
         OR (DATE(start_time) <= ? AND DATE(end_time) >= ?)
      ORDER BY start_time
    `, [weekStartStr, weekEndStr, weekStartStr, weekEndStr, weekStartStr, weekEndStr]);

    if (weekTasks.length === 0) {
      console.log('本周没有任务\n');
    } else {
      weekTasks.forEach((task, index) => {
        const statusText = {
          'pending': '待办',
          'in_progress': '进行中',
          'completed': '已完成',
          'cancelled': '已取消'
        }[task.status] || task.status;

        const priorityText = task.priority ? `[${task.priority.toUpperCase()}]` : '';

        console.log(`${index + 1}. ${task.title} [${statusText}] ${priorityText}`);
        console.log(`   ${task.start_date} 至 ${task.end_date}`);
        console.log('');
      });
    }

    await connection.end();
    console.log('✓ 所有操作完成！');

  } catch (error) {
    console.error('❌ 更新失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

updateTaskDates();



