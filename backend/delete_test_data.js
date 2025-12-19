const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: 'pdl123',
  password: 'Pdl1234567',
  database: 'enterprise_management',
  port: 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 60000 // 60s timeout
};

const TEST_DEPT_NAME = 'Test Department';
const TEST_USER_PREFIX = 'test_user_';
const TEST_ITEM_PREFIX = '[TEST] ';

async function main() {
  let connection;
  try {
    console.log('Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('Connected.');

    // Delete Logs
    console.log('Deleting test system logs...');
    // We can identify logs by category 'test' or description prefix
    const [logsResult] = await connection.execute('DELETE FROM system_logs WHERE category = ? OR description LIKE ?', ['test', `${TEST_ITEM_PREFIX}%`]);
    console.log(`Deleted ${logsResult.affectedRows} logs.`);

    // Delete Tasks
    console.log('Deleting test tasks...');
    const [tasksResult] = await connection.execute('DELETE FROM tasks WHERE title LIKE ?', [`${TEST_ITEM_PREFIX}%`]);
    console.log(`Deleted ${tasksResult.affectedRows} tasks.`);

    // Delete Important Items
    console.log('Deleting test important items...');
    const [itemsResult] = await connection.execute('DELETE FROM company_important_items WHERE title LIKE ?', [`${TEST_ITEM_PREFIX}%`]);
    console.log(`Deleted ${itemsResult.affectedRows} items.`);

    // Delete Users
    console.log('Deleting test users...');
    const [usersResult] = await connection.execute('DELETE FROM users WHERE username LIKE ?', [`${TEST_USER_PREFIX}%`]);
    console.log(`Deleted ${usersResult.affectedRows} users.`);

    // Delete Department
    console.log('Deleting test department...');
    const [deptResult] = await connection.execute('DELETE FROM departments WHERE name = ?', [TEST_DEPT_NAME]);
    console.log(`Deleted ${deptResult.affectedRows} department.`);

    console.log('All test data deleted successfully.');

  } catch (err) {
    console.error('Error deleting data:', err);
  } finally {
    if (connection) connection.end();
  }
}

main();
