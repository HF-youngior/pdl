const mysql = require('mysql2/promise');
const http = require('http');

// 复制formatDateTimeForBeijing函数
function formatDateTimeForBeijing(dateTime) {
  if (!dateTime) return null;
  
  let date;
  if (dateTime instanceof Date) {
    date = dateTime;
  } else if (typeof dateTime === 'string') {
    date = new Date(dateTime);
  } else {
    return null;
  }
  
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}+08:00`;
}

async function testComplete() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '23301144',
    database: 'enterprise_management',
    timezone: '+08:00'
  });

  try {
    console.log('\n========== 员工满意度提升行动计划 - 完整测试 ==========\n');
    
    // 1. 查询数据库
    const [tasks] = await connection.execute(
      `SELECT * FROM tasks WHERE title LIKE '%员工满意度提升行动计划%' LIMIT 1`
    );

    if (tasks.length === 0) {
      console.log('❌ 未找到任务');
      return;
    }

    const task = tasks[0];
    console.log('【1】数据库存储:');
    console.log(`  开始时间: ${task.start_time}`);
    console.log(`  结束时间: ${task.end_time}`);
    console.log(`  应该显示在: 10月26、27、28、29日`);
    
    // 2. API返回格式
    console.log('\n【2】后端API返回格式:');
    const apiStartTime = formatDateTimeForBeijing(task.start_time);
    const apiEndTime = formatDateTimeForBeijing(task.end_time);
    console.log(`  start_time: ${apiStartTime}`);
    console.log(`  end_time: ${apiEndTime}`);
    
    // 3. 前端解析（模拟）
    console.log('\n【3】前端DateTime.parse()解析:');
    const jsStart = new Date(apiStartTime);
    const jsEnd = new Date(apiEndTime);
    console.log(`  JavaScript Date对象: ${jsStart} ~ ${jsEnd}`);
    console.log(`  提取日期: ${jsStart.getFullYear()}-${String(jsStart.getMonth()+1).padLeft(2,'0')}-${String(jsStart.getDate()).padLeft(2,'0')}`);
    
    // 4. 测试每一天的日视图查询
    console.log('\n【4】日视图API查询测试:');
    for (let day = 26; day <= 29; day++) {
      const date = `2025-10-${day}`;
      const [dayTasks] = await connection.execute(
        `SELECT COUNT(*) as count FROM tasks 
         WHERE title LIKE '%员工满意度提升行动计划%'
         AND (
           DATE(start_time) = ? 
           OR DATE(end_time) = ? 
           OR (DATE(start_time) <= ? AND DATE(end_time) >= ?)
         )`,
        [date, date, date, date]
      );
      
      const found = dayTasks[0].count > 0;
      const status = found ? '✅' : '❌';
      console.log(`  ${status} ${date}: ${found ? '能查到任务' : '查不到任务'}`);
    }
    
    // 5. 测试月视图逻辑
    console.log('\n【5】月视图逻辑测试:');
    const startDate = new Date(task.start_time);
    const endDate = new Date(task.end_time);
    console.log(`  开始日期对象: ${startDate}`);
    console.log(`  结束日期对象: ${endDate}`);
    
    let currentDate = new Date(startDate);
    const dates = [];
    while (currentDate <= endDate) {
      const dateKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(currentDate.getDate()).padStart(2, '0')}`;
      dates.push(dateKey);
      currentDate.setDate(currentDate.getDate() + 1);
    }
    console.log(`  应该在这些日期显示: ${dates.join(', ')}`);
    
    // 6. 总结
    console.log('\n【6】预期结果总结:');
    console.log('  ✅ 周视图: 应该显示在10/26、10/27、10/28、10/29');
    console.log('  ✅ 月视图: 应该在10/26、10/27、10/28、10/29都有显示');
    console.log('  ✅ 日视图: 点击10/26、10/27、10/28、10/29都能看到');
    
    console.log('\n==========完成==========\n');

  } finally {
    await connection.end();
  }
}

// 添加padLeft到String原型
String.prototype.padLeft = function(length, char) {
  return this.padStart(length, char);
};

testComplete().catch(console.error);

