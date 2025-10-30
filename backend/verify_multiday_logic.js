const mysql = require('mysql2/promise');

async function verifyLogic() {
  let connection;
  
  try {
    // 连接数据库
    connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: '23301144',
      database: 'enterprise_management',
      charset: 'utf8mb4'
    });

    console.log('✓ 数据库连接成功\n');
    console.log('=== 验证跨多天任务显示逻辑 ===\n');

    // 查找"秋季校园招聘行程规划"任务
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        title,
        assignee_id,
        start_time,
        end_time,
        DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
        DATE_FORMAT(end_time, '%Y-%m-%d') as end_date
      FROM tasks
      WHERE title LIKE '%秋季校园招聘行程规划%'
      LIMIT 1
    `);

    if (tasks.length === 0) {
      console.log('❌ 没有找到测试任务');
      await connection.end();
      return;
    }

    const task = tasks[0];
    console.log(`任务信息：`);
    console.log(`  ID: ${task.id}`);
    console.log(`  标题: ${task.title}`);
    console.log(`  负责人: ${task.assignee_id}`);
    console.log(`  开始时间: ${task.start_time}`);
    console.log(`  结束时间: ${task.end_time}`);
    console.log(`  开始日期: ${task.start_date}`);
    console.log(`  结束日期: ${task.end_date}\n`);

    // 模拟后端逻辑
    console.log('模拟后端月视图逻辑：\n');
    
    const calendar = {};
    const year = 2025;
    const month = 10;
    const lastDay = 31;
    
    // 初始化10月的所有日期
    for (let day = 1; day <= lastDay; day++) {
      const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      calendar[dateKey] = {
        date: dateKey,
        tasks: [],
        hasData: false
      };
    }
    
    // 应用新逻辑
    let taskStartDate = new Date(task.start_time);
    let taskEndDate = new Date(task.end_time);
    
    const currentDate = new Date(taskStartDate);
    currentDate.setHours(0, 0, 0, 0);
    const endDate = new Date(taskEndDate);
    endDate.setHours(0, 0, 0, 0);
    
    console.log(`任务跨越的日期范围：`);
    console.log(`  从: ${currentDate.toISOString().split('T')[0]}`);
    console.log(`  到: ${endDate.toISOString().split('T')[0]}\n`);
    
    console.log('将任务添加到以下日期：');
    
    // 遍历任务跨越的每一天
    while (currentDate <= endDate) {
      const dateKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(currentDate.getDate()).padStart(2, '0')}`;
      
      if (calendar[dateKey]) {
        calendar[dateKey].tasks.push({
          id: task.id,
          title: task.title
        });
        calendar[dateKey].hasData = true;
        console.log(`  ✓ ${dateKey}`);
      }
      
      // 移动到下一天
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    console.log('\n验证结果：');
    const testDates = ['2025-10-02', '2025-10-03', '2025-10-04'];
    let success = true;
    
    for (const dateKey of testDates) {
      if (calendar[dateKey] && calendar[dateKey].tasks.length > 0) {
        console.log(`  ✓ ${dateKey}: 有任务 (${calendar[dateKey].tasks[0].title})`);
      } else {
        console.log(`  ✗ ${dateKey}: 没有任务`);
        success = false;
      }
    }
    
    console.log('\n');
    if (success) {
      console.log('✓✓✓ 逻辑验证成功！跨多天任务会在每一天都显示');
    } else {
      console.log('✗✗✗ 逻辑验证失败！');
    }
    
    await connection.end();

  } catch (error) {
    console.error('❌ 验证失败:', error.message);
    console.error(error.stack);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

verifyLogic();


