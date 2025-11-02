const mysql = require('mysql2/promise');

// 时区处理工具函数 - 与server_enterprise.js中的一致
function formatDateTimeForBeijing(dateTime) {
  if (!dateTime) return null;
  
  let date;
  
  // 如果已经是Date对象
  if (dateTime instanceof Date) {
    date = dateTime;
  }
  // 如果是字符串
  else if (typeof dateTime === 'string') {
    // 如果已经包含时区信息，直接返回
    if (dateTime.includes('+08:00')) {
      return dateTime;
    }
    // 解析字符串为Date对象
    date = new Date(dateTime);
  } else {
    return null;
  }
  
  // MySQL返回的Date对象已经是本地时区（北京时间GMT+8）
  // 我们需要获取本地时间的各个部分，然后标记为+08:00
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  
  // 组合成ISO 8601格式，明确标记为+08:00时区
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}+08:00`;
}

async function testTimezone() {
  let connection;
  
  try {
    console.log('=== 时区转换测试（直接查询数据库）===\n');
    
    // 创建两个连接：一个不带时区，一个带时区
    console.log('1. 不带时区配置的连接\n');
    const connWithoutTZ = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'asdfgh0625YYH',
      database: 'enterprise_management',
      charset: 'utf8mb4'
    });

    const [rows1] = await connWithoutTZ.execute(`
      SELECT 
        id,
        title,
        start_time,
        end_time
      FROM tasks
      WHERE id = 'task-hr-oct-003'
    `);

    if (rows1.length > 0) {
      const task = rows1[0];
      console.log(`   任务: ${task.title}`);
      console.log(`   原始 start_time (无TZ): ${task.start_time}`);
      console.log(`   原始 end_time (无TZ):   ${task.end_time}`);
      console.log(`   类型: ${typeof task.start_time}, 是Date? ${task.start_time instanceof Date}`);
      console.log('');
    }
    
    await connWithoutTZ.end();
    
    // 带时区的连接
    console.log('2. 带时区配置的连接 (timezone: +08:00)\n');
    const connWithTZ = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'asdfgh0625YYH',
      database: 'enterprise_management',
      charset: 'utf8mb4',
      timezone: '+08:00'
    });

    const [rows2] = await connWithTZ.execute(`
      SELECT 
        id,
        title,
        start_time,
        end_time
      FROM tasks
      WHERE id = 'task-hr-oct-003'
    `);

    if (rows2.length > 0) {
      const task = rows2[0];
      console.log(`   任务: ${task.title}`);
      console.log(`   原始 start_time (有TZ): ${task.start_time}`);
      console.log(`   原始 end_time (有TZ):   ${task.end_time}`);
      console.log(`   类型: ${typeof task.start_time}, 是Date? ${task.start_time instanceof Date}`);
      console.log('');
      
      console.log('3. 应用formatDateTimeForBeijing转换\n');
      const formatted_start = formatDateTimeForBeijing(task.start_time);
      const formatted_end = formatDateTimeForBeijing(task.end_time);
      console.log(`   转换后 start_time: ${formatted_start}`);
      console.log(`   转换后 end_time:   ${formatted_end}`);
      console.log('');
      
      // 验证日期部分
      const startDate = formatted_start.split('T')[0];
      const endDate = formatted_end.split('T')[0];
      console.log('4. 验证日期\n');
      console.log(`   开始日期: ${startDate}`);
      console.log(`   结束日期: ${endDate}`);
      console.log(`   预期: 2025-10-15 至 2025-10-17`);
      
      if (startDate === '2025-10-15' && endDate === '2025-10-17') {
        console.log('   ✅ 日期正确！');
      } else {
        console.log(`   ❌ 日期错误！实际: ${startDate} 至 ${endDate}`);
      }
    }
    
    await connWithTZ.end();
    
    console.log('\n=== 测试完成 ===');
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

testTimezone();

