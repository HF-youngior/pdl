const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'pdl.db');
const db = new sqlite3.Database(dbPath);

console.log('\n=== 数据库中的表 ===\n');

db.all(`
  SELECT name FROM sqlite_master 
  WHERE type='table' 
  ORDER BY name
`, (err, rows) => {
  if (err) {
    console.error('查询失败:', err.message);
    db.close();
    return;
  }
  
  rows.forEach(row => {
    console.log(`- ${row.name}`);
  });
  
  console.log('\n=== 查询任务示例 ===\n');
  
  // 尝试查询任务表
  db.all(`
    SELECT id, title, start_time, end_time, DATE(created_at) as created_date 
    FROM tasks 
    ORDER BY created_at 
    LIMIT 10
  `, (err, tasks) => {
    if (err) {
      console.error('查询tasks表失败:', err.message);
    } else {
      console.log(`找到 ${tasks.length} 条任务:\n`);
      tasks.forEach((task, index) => {
        console.log(`${index + 1}. ${task.title}`);
        console.log(`   创建时间: ${task.created_date}`);
        console.log(`   开始时间: ${task.start_time || '无'}`);
        console.log(`   结束时间: ${task.end_time || '无'}`);
        console.log('');
      });
    }
    db.close();
  });
});


