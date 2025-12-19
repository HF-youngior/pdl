const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const dbConfig = {
  host: process.env.DB_HOST || 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl',
  password: process.env.DB_PASSWORD || 'Pdl123456',
  database: process.env.DB_NAME || 'enterprise_management',
  port: Number(process.env.DB_PORT || 3306),
  charset: 'utf8mb4'
};

async function checkCurrentData() {
  try {
    const connection = await mysql.createConnection(dbConfig);

    console.log('=== 当前用户 ===\n');
    const [users] = await connection.execute(`
      SELECT id, name, role, department_id 
      FROM users 
      ORDER BY FIELD(role,'founder','department_head','team_leader','employee'), name
    `);
    console.log(`共有 ${users.length} 名用户`);
    users.slice(0, 10).forEach((user, idx) => {
      console.log(`${idx + 1}. ${user.name} (${user.role}) - ${user.id}`);
    });
    if (users.length > 10) {
      console.log(`... 其余 ${users.length - 10} 人省略 ...\n`);
    } else {
      console.log('');
    }

    console.log('=== 当前日志数据 ===\n');
    
    const [logs] = await connection.execute(`
      SELECT 
        id,
        user_id,
        title,
        created_at,
        DATE_FORMAT(created_at, '%Y-%m-%d') as log_date
      FROM personal_logs
      ORDER BY created_at DESC
    `);
    
    console.log(`总共 ${logs.length} 条日志:\n`);
    logs.slice(0, 20).forEach((log, idx) => {
      console.log(`${idx + 1}. [${log.log_date}] ${log.title} (用户: ${log.user_id})`);
    });
    
    console.log('\n=== 当前任务数据 ===\n');
    
    const [tasks] = await connection.execute(`
      SELECT 
        id,
        assignee_id,
        assignee_name,
        title,
        deadline,
        DATE_FORMAT(IFNULL(deadline, start_time), '%Y-%m-%d') as task_date
      FROM tasks
      ORDER BY IFNULL(deadline, start_time) DESC
      LIMIT 20
    `);
    
    console.log(`最近 ${tasks.length} 条任务:\n`);
    tasks.forEach((task, idx) => {
      console.log(`${idx + 1}. [${task.task_date}] ${task.title} (责任人: ${task.assignee_name || task.assignee_id})`);
    });
    
    console.log('\n=== 当前个人重要事项 ===\n');
    const [importantItems] = await connection.execute(`
      SELECT id, title, priority, status FROM company_important_items ORDER BY created_at DESC LIMIT 10
    `);
    importantItems.forEach((item, idx) => {
      console.log(`${idx + 1}. [${item.priority}] ${item.title} - ${item.status}`);
    });
    
    await connection.end();
    
  } catch (error) {
    console.error('检查失败:', error.message);
    process.exit(1);
  }
}

checkCurrentData();













