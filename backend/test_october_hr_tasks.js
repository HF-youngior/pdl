const mysql = require('mysql2/promise');

async function testOctoberHRTasks() {
  let connection;
  
  try {
    // 连接数据库
    connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'Pyx_07091817',
      database: 'enterprise_management',
      charset: 'utf8mb4'
    });

    console.log('✓ 数据库连接成功\n');

    // 查找"秋季校园招聘行程规划"任务
    console.log('=== 查找"秋季校园招聘行程规划"任务 ===\n');
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        title,
        assignee_id,
        DATE_FORMAT(start_time, '%Y-%m-%d %H:%i') as start_time,
        DATE_FORMAT(end_time, '%Y-%m-%d %H:%i') as end_time,
        DATEDIFF(end_time, start_time) as duration_days
      FROM tasks
      WHERE title LIKE '%秋季校园招聘行程规划%'
      LIMIT 1
    `);

    if (tasks.length === 0) {
      console.log('❌ 没有找到该任务');
      await connection.end();
      return;
    }

    const testTask = tasks[0];
    console.log(`任务ID: ${testTask.id}`);
    console.log(`任务名称: ${testTask.title}`);
    console.log(`开始时间: ${testTask.start_time}`);
    console.log(`结束时间: ${testTask.end_time}`);
    console.log(`持续天数: ${testTask.duration_days + 1} 天`);
    console.log(`负责人ID: ${testTask.assignee_id}\n`);

    // 模拟月视图逻辑
    const year = 2025;
    const month = 10;
    
    console.log('=== 模拟月视图API逻辑 ===\n');
    
    // 获取10月份的任务
    const startDateOnly = `${year}-${String(month).padStart(2, '0')}-01`;
    const lastDay = new Date(year, month, 0).getDate();
    const endDateOnly = `${year}-${String(month).padStart(2, '0')}-${lastDay}`;
    
    const [monthTasks] = await connection.execute(`
      SELECT DISTINCT
        t.id,
        t.title,
        t.start_time,
        t.end_time,
        t.priority,
        DATE_FORMAT(COALESCE(t.start_time, t.deadline), '%Y-%m-%d') as task_date
      FROM tasks t
      WHERE t.assignee_id = ?
      AND (
        DATE(t.start_time) BETWEEN ? AND ?
        OR DATE(t.end_time) BETWEEN ? AND ?
        OR DATE(t.deadline) BETWEEN ? AND ?
      )
      AND t.id = ?
      ORDER BY t.start_time, t.priority
    `, [
      testTask.assignee_id, 
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      testTask.id
    ]);

    if (monthTasks.length > 0) {
      console.log(`✓ 任务在月视图查询中被找到`);
      console.log(`  查询到的task_date: ${monthTasks[0].task_date}\n`);
    } else {
      console.log(`✗ 任务在月视图查询中未被找到\n`);
    }

    // 模拟前端月视图的日期分组逻辑
    console.log('=== 模拟前端月视图日期分组逻辑 ===\n');
    
    const calendar = {};
    
    // 初始化整个月的日期
    for (let day = 1; day <= lastDay; day++) {
      const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      calendar[dateKey] = {
        date: dateKey,
        tasks: [],
        hasData: false
      };
    }
    
    // 使用新的逻辑填充任务数据 - 对于跨多天的任务，在每一天都显示
    monthTasks.forEach(task => {
      // 确定任务的开始和结束日期
      let taskStartDate = null;
      let taskEndDate = null;
      
      if (task.start_time) {
        taskStartDate = new Date(task.start_time);
      }
      
      if (task.end_time) {
        taskEndDate = new Date(task.end_time);
      } else if (task.start_time) {
        // 如果没有 end_time，使用 start_time 作为结束日期
        taskEndDate = new Date(task.start_time);
      }
      
      // 如果任务有时间范围，在每一天都显示该任务
      if (taskStartDate && taskEndDate) {
        const currentDate = new Date(taskStartDate);
        currentDate.setHours(0, 0, 0, 0);
        const endDate = new Date(taskEndDate);
        endDate.setHours(0, 0, 0, 0);
        
        console.log(`处理任务: ${task.title}`);
        console.log(`  开始日期: ${taskStartDate.toISOString().split('T')[0]}`);
        console.log(`  结束日期: ${taskEndDate.toISOString().split('T')[0]}\n`);
        
        // 遍历任务跨越的每一天
        while (currentDate <= endDate) {
          const dateKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(currentDate.getDate()).padStart(2, '0')}`;
          
          if (calendar[dateKey]) {
            // 检查该任务是否已经添加到这一天（避免重复）
            const existingTask = calendar[dateKey].tasks.find(t => t.id === task.id);
            if (!existingTask) {
              calendar[dateKey].tasks.push({
                id: task.id,
                title: task.title
              });
              calendar[dateKey].hasData = true;
              console.log(`  ✓ 任务添加到日期: ${dateKey}`);
            }
          }
          
          // 移动到下一天
          currentDate.setDate(currentDate.getDate() + 1);
        }
      }
    });
    
    console.log('\n=== 检查10月2日、3日、4日是否都包含该任务 ===\n');
    const testDates = ['2025-10-02', '2025-10-03', '2025-10-04'];
    let allDatesHaveTask = true;
    
    for (const dateKey of testDates) {
      if (calendar[dateKey] && calendar[dateKey].tasks.length > 0) {
        console.log(`✓ ${dateKey}: 有 ${calendar[dateKey].tasks.length} 个任务`);
        calendar[dateKey].tasks.forEach(t => {
          console.log(`    - ${t.title}`);
        });
      } else {
        console.log(`✗ ${dateKey}: 没有任务 (错误!)`);
        allDatesHaveTask = false;
      }
    }
    
    console.log('\n=== 测试结果 ===');
    if (allDatesHaveTask) {
      console.log('✓ 月视图逻辑正确！10月2、3、4日都包含了该任务');
    } else {
      console.log('✗ 月视图逻辑有问题！某些日期缺失该任务');
    }
    
    await connection.end();
    console.log('\n✓ 测试完成');

  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    console.error(error.stack);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

testOctoberHRTasks();

