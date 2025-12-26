const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'pdl.db');
const db = new sqlite3.Database(dbPath);

console.log('\n=== 任务时间数据统计 ===\n');

// 查询任务统计
db.get(`
  SELECT 
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL THEN 1 END) as tasks_with_dates,
    COUNT(CASE WHEN JULIANDAY(end_time) - JULIANDAY(start_time) > 0 THEN 1 END) as multi_day_tasks
  FROM timeline_tasks
`, (err, row) => {
  if (err) {
    console.error('查询失败:', err.message);
    return;
  }
  
  console.log(`总任务数: ${row.total_tasks}`);
  console.log(`有时间段的任务: ${row.tasks_with_dates}`);
  console.log(`跨多天的任务: ${row.multi_day_tasks}`);
  console.log('');
});

// 查询跨多天的任务示例
console.log('=== 跨多天的任务示例 ===\n');
db.all(`
  SELECT 
    id,
    title,
    DATE(start_time) as start_date,
    DATE(end_time) as end_date,
    JULIANDAY(end_time) - JULIANDAY(start_time) + 1 as duration_days
  FROM timeline_tasks
  WHERE JULIANDAY(end_time) - JULIANDAY(start_time) > 0
  ORDER BY start_time
  LIMIT 15
`, (err, rows) => {
  if (err) {
    console.error('查询失败:', err.message);
    return;
  }
  
  rows.forEach((row, index) => {
    console.log(`${index + 1}. ${row.title}`);
    console.log(`   时间: ${row.start_date} 至 ${row.end_date} (${row.duration_days}天)`);
    console.log('');
  });
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
db.all(`
  SELECT 
    id,
    title,
    DATE(start_time) as start_date,
    DATE(end_time) as end_date,
    status,
    priority
  FROM timeline_tasks
  WHERE (DATE(start_time) BETWEEN ? AND ?) 
     OR (DATE(end_time) BETWEEN ? AND ?)
     OR (DATE(start_time) <= ? AND DATE(end_time) >= ?)
  ORDER BY start_time
`, [weekStartStr, weekEndStr, weekStartStr, weekEndStr, weekStartStr, weekEndStr], (err, rows) => {
  if (err) {
    console.error('查询失败:', err.message);
    db.close();
    return;
  }
  
  if (rows.length === 0) {
    console.log('本周没有任务\n');
  } else {
    rows.forEach((row, index) => {
      const statusText = {
        'pending': '待办',
        'in_progress': '进行中',
        'completed': '已完成',
        'cancelled': '已取消'
      }[row.status] || row.status;
      
      const priorityText = {
        'p0': 'P0',
        'p1': 'P1',
        'p2': 'P2',
        'p3': 'P3'
      }[row.priority] || '';
      
      console.log(`${index + 1}. ${row.title} [${statusText}] ${priorityText}`);
      console.log(`   ${row.start_date} 至 ${row.end_date}`);
      console.log('');
    });
  }
  
  db.close();
});


