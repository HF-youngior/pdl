const mysql = require('mysql2/promise');

async function testMultiDayTasks() {
  let connection;
  
  try {
    // 连接数据库
    connection = await mysql.createConnection({
      host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
      user: 'pdl123',
      password: 'Pdl1234567',
      database: 'enterprise_management',
      charset: 'utf8mb4'
    });

    console.log('✓ 数据库连接成功\n');

    // 查找一个跨多天的任务作为示例
    console.log('=== 查找跨多天的任务 ===\n');
    const [multiDayTasks] = await connection.execute(`
      SELECT 
        id,
        title,
        assignee_id,
        DATE_FORMAT(start_time, '%Y-%m-%d %H:%i') as start_time,
        DATE_FORMAT(end_time, '%Y-%m-%d %H:%i') as end_time,
        DATEDIFF(end_time, start_time) as duration_days
      FROM tasks
      WHERE end_time IS NOT NULL
        AND DATEDIFF(end_time, start_time) >= 2
      ORDER BY start_time
      LIMIT 1
    `);

    if (multiDayTasks.length === 0) {
      console.log('❌ 没有找到跨多天的任务');
      return;
    }

    const testTask = multiDayTasks[0];
    console.log(`找到测试任务: ${testTask.title}`);
    console.log(`时间: ${testTask.start_time} 至 ${testTask.end_time}`);
    console.log(`持续天数: ${testTask.duration_days + 1} 天`);
    console.log(`负责人ID: ${testTask.assignee_id}\n`);

    // 提取日期范围
    const startDate = new Date(testTask.start_time.split(' ')[0]);
    const endDate = new Date(testTask.end_time.split(' ')[0]);
    
    console.log('=== 验证该任务在跨越的每一天是否都会被API返回 ===\n');
    
    // 测试每一天
    const currentDate = new Date(startDate);
    let allDaysIncluded = true;
    
    while (currentDate <= endDate) {
      const dateStr = currentDate.toISOString().split('T')[0];
      
      // 模拟日视图API查询
      const [dayTasks] = await connection.execute(`
        SELECT 
          id,
          title
        FROM tasks
        WHERE assignee_id = ?
        AND (
          -- 任务的开始时间在该日期
          (DATE(start_time) = ?)
          -- 任务的结束时间在该日期
          OR (DATE(end_time) = ?)
          -- 任务跨越该日期（开始时间在之前，结束时间在之后）
          OR (DATE(start_time) <= ? AND DATE(end_time) >= ?)
          -- deadline 在该日期
          OR (DATE(deadline) = ?)
        )
        AND id = ?
      `, [testTask.assignee_id, dateStr, dateStr, dateStr, dateStr, dateStr, testTask.id]);
      
      if (dayTasks.length > 0) {
        console.log(`✓ ${dateStr}: 任务被包含`);
      } else {
        console.log(`✗ ${dateStr}: 任务未被包含 (错误!)`);
        allDaysIncluded = false;
      }
      
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    console.log('\n=== 测试结果 ===');
    if (allDaysIncluded) {
      console.log('✓ 所有日期都包含了该任务！');
    } else {
      console.log('✗ 某些日期缺失该任务！');
    }
    
    await connection.end();
    console.log('\n✓ 测试完成');

  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

testMultiDayTasks();



