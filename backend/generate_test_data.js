const mysql = require('mysql2/promise');
// const { v4: uuidv4 } = require('uuid'); // Removed dependency
const bcrypt = require('bcryptjs');

// Database configuration
const dbConfig = {
  host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: 'pdl123',
  password: 'Pdl1234567',
  database: 'enterprise_management',
  port: 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Constants
const BATCH_SIZE = 100; // Insert in batches
const TARGET_COUNT = 1000;
const TEST_DEPT_NAME = 'Test Department';
const TEST_DEPT_DESC = 'Department for test data';
const TEST_USER_PREFIX = 'test_user_';
const TEST_ITEM_PREFIX = '[TEST] ';

// Helper to generate UUID if library is missing (checking package.json, uuid is NOT listed in dependencies, only in devDependencies maybe? No, checked earlier.)
// package.json dependencies: axios, bcryptjs, better-sqlite3, cors, dotenv, express, jsonwebtoken, multer, mysql2, segmentit, swagger-ui-express
// No uuid. So I need a helper.
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

async function main() {
  let connection;
  try {
    console.log('Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('Connected.');

    // 1. Create Test Department
    console.log('Checking Test Department...');
    const [depts] = await connection.execute('SELECT id FROM departments WHERE name = ?', [TEST_DEPT_NAME]);
    let deptId;
    if (depts.length === 0) {
      deptId = generateUUID();
      await connection.execute('INSERT INTO departments (id, name, description) VALUES (?, ?, ?)', [deptId, TEST_DEPT_NAME, TEST_DEPT_DESC]);
      console.log(`Created Test Department with ID: ${deptId}`);
    } else {
      deptId = depts[0].id;
      console.log(`Using existing Test Department ID: ${deptId}`);
    }

    // 2. Generate Users
    console.log(`Generating ${TARGET_COUNT} users...`);
    const hashedPassword = await bcrypt.hash('123456', 10);
    const userIds = [];
    
    // Check how many we already have to avoid duplicates if run multiple times
    const [existingUsers] = await connection.execute(`SELECT count(*) as count FROM users WHERE username LIKE '${TEST_USER_PREFIX}%'`);
    let currentCount = existingUsers[0].count;
    let usersToCreate = TARGET_COUNT - currentCount;
    
    if (usersToCreate > 0) {
        let values = [];
        for (let i = 0; i < usersToCreate; i++) {
            const id = generateUUID();
            const username = `${TEST_USER_PREFIX}${currentCount + i + 1}`;
            const name = `Test User ${currentCount + i + 1}`;
            userIds.push(id);
            // (id, username, password, name, position, department_id, role, is_active)
            values.push([id, username, hashedPassword, name, 'Tester', deptId, 'employee', 1]);
            
            if (values.length >= BATCH_SIZE) {
                await insertUsers(connection, values);
                values = [];
                console.log(`Inserted users... ${i+1}/${usersToCreate}`);
            }
        }
        if (values.length > 0) {
            await insertUsers(connection, values);
        }
    } else {
        console.log('Sufficient test users already exist.');
        // Fetch existing IDs for linking
        const [rows] = await connection.execute(`SELECT id FROM users WHERE username LIKE '${TEST_USER_PREFIX}%' LIMIT ${TARGET_COUNT}`);
        rows.forEach(row => userIds.push(row.id));
    }

    // 3. Generate Important Items
    console.log(`Generating ${TARGET_COUNT} important items...`);
    const [existingItems] = await connection.execute(`SELECT count(*) as count FROM company_important_items WHERE title LIKE '${TEST_ITEM_PREFIX.replace('[','\\[')}%'`);
    // Note: LIKE escaping for [ might be needed or just use %TEST%
    // Simpler: just check count.
    
    let itemsToCreate = TARGET_COUNT; // Always add 1000 more? Or fill up to 1000? User said "increase data... roughly add 1000". So add 1000.
    // User said "add 1000 entries". "原来的数据不变". So I should just add.
    
    let itemValues = [];
    for (let i = 0; i < itemsToCreate; i++) {
        const id = generateUUID();
        const title = `${TEST_ITEM_PREFIX}Item ${Date.now()}_${i}`;
        const description = `This is a test important item generated at ${new Date().toISOString()}`;
        const creatorId = userIds[Math.floor(Math.random() * userIds.length)];
        
        // (id, title, description, priority, status, created_by, department_id?? No dept_id in items, usually linked to user)
        // Table: id, title, description, priority, status, is_selected, created_at, deadline, created_by, updated_by
        itemValues.push([id, title, description, 'p1', 'pending', creatorId]);
        
        if (itemValues.length >= BATCH_SIZE) {
            await insertItems(connection, itemValues);
            itemValues = [];
             console.log(`Inserted items... ${i+1}/${itemsToCreate}`);
        }
    }
    if (itemValues.length > 0) {
        await insertItems(connection, itemValues);
    }

    // 4. Generate Tasks
    console.log(`Generating ${TARGET_COUNT} tasks...`);
    let taskValues = [];
    for (let i = 0; i < itemsToCreate; i++) {
        const id = generateUUID();
        const title = `${TEST_ITEM_PREFIX}Task ${Date.now()}_${i}`;
        const description = `Test task description`;
        const userId = userIds[Math.floor(Math.random() * userIds.length)];
        const creatorId = userIds[Math.floor(Math.random() * userIds.length)];
        
        // Table: id, title, description, assignee_id, assignee_name, department_id, priority, status, created_by
        taskValues.push([id, title, description, userId, 'Test User', deptId, 'p1', 'pending', creatorId]);
        
        if (taskValues.length >= BATCH_SIZE) {
            await insertTasks(connection, taskValues);
            taskValues = [];
            console.log(`Inserted tasks... ${i+1}/${itemsToCreate}`);
        }
    }
    if (taskValues.length > 0) {
        await insertTasks(connection, taskValues);
    }

    // 5. Generate System Logs
    console.log(`Generating ${TARGET_COUNT} system logs...`);
    let logValues = [];
    for (let i = 0; i < itemsToCreate; i++) {
        const id = generateUUID();
        const userId = userIds[Math.floor(Math.random() * userIds.length)];
        const action = `${TEST_ITEM_PREFIX}Action`;
        const description = `Test system log entry ${i}`;
        
        // Table: id, user_id, user_name, action, description, category
        logValues.push([id, userId, 'Test User', action, description, 'test']);
        
        if (logValues.length >= BATCH_SIZE) {
            await insertLogs(connection, logValues);
            logValues = [];
            console.log(`Inserted logs... ${i+1}/${itemsToCreate}`);
        }
    }
    if (logValues.length > 0) {
        await insertLogs(connection, logValues);
    }

    console.log('All test data generated successfully.');

  } catch (err) {
    console.error('Error generating data:', err);
  } finally {
    if (connection) connection.end();
  }
}

async function insertUsers(conn, values) {
    const sql = 'INSERT INTO users (id, username, password, name, position, department_id, role, is_active) VALUES ?';
    await conn.query(sql, [values]);
}

async function insertItems(conn, values) {
    const sql = 'INSERT INTO company_important_items (id, title, description, priority, status, created_by) VALUES ?';
    await conn.query(sql, [values]);
}

async function insertTasks(conn, values) {
    const sql = 'INSERT INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, created_by) VALUES ?';
    await conn.query(sql, [values]);
}

async function insertLogs(conn, values) {
    const sql = 'INSERT INTO system_logs (id, user_id, user_name, action, description, category) VALUES ?';
    await conn.query(sql, [values]);
}

main();
