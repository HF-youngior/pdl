const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const { useDefault, Segment } = require('segmentit');
const segmenter = useDefault(new Segment());

const app = express();
const PORT = process.env.PORT || 8080;

// 中间件
app.use(cors());
app.use(express.json());

// 静态文件服务 - 提供Web管理端
app.use('/web_admin', express.static('../web_admin'));

// 数据库连接
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'asdfgh0625YYH',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4'
};

let db;

// 初始化数据库连接
async function initDatabase() {
  try {
    db = await mysql.createConnection(dbConfig);
    console.log('数据库连接成功');
    
    // 创建表
    await createTables();
  } catch (error) {
    console.error('数据库连接失败:', error);
    process.exit(1);
  }
}

// 创建数据库表
async function createTables() {
  const tables = [
    // 部门表
    `CREATE TABLE IF NOT EXISTS departments (
      id VARCHAR(36) PRIMARY KEY,
      name VARCHAR(100) NOT NULL UNIQUE,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    
    // 用户表 - 扩展支持多层级权限
    `CREATE TABLE IF NOT EXISTS users (
      id VARCHAR(36) PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      name VARCHAR(100) NOT NULL,
      position VARCHAR(100) NOT NULL,
      department_id VARCHAR(36) NOT NULL,
      role ENUM('admin', 'founder', 'department_head', 'team_leader', 'employee') NOT NULL,
      parent_id VARCHAR(36) NULL,
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_login_at TIMESTAMP NULL,
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (parent_id) REFERENCES users(id)
    )`,
    
    // 公司十大重要事项表
    `CREATE TABLE IF NOT EXISTS company_important_items (
      id VARCHAR(36) PRIMARY KEY,
      title VARCHAR(200) NOT NULL,
      description TEXT,
      priority ENUM('p0', 'p1', 'p2', 'p3') DEFAULT 'p1',
      status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
      is_selected BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      deadline TIMESTAMP NULL,
      created_by VARCHAR(36) NOT NULL,
      updated_by VARCHAR(36) NULL,
      FOREIGN KEY (created_by) REFERENCES users(id),
      FOREIGN KEY (updated_by) REFERENCES users(id)
    )`,
    
    // 任务表 - 支持层级任务关系
    `CREATE TABLE IF NOT EXISTS tasks (
      id VARCHAR(36) PRIMARY KEY,
      title VARCHAR(200) NOT NULL,
      description TEXT,
      parent_task_id VARCHAR(36) NULL,
      assignee_id VARCHAR(36) NOT NULL,
      assignee_name VARCHAR(100) NOT NULL,
      department_id VARCHAR(36) NOT NULL,
      priority ENUM('p0', 'p1', 'p2', 'p3') DEFAULT 'p1',
      status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
      progress_percentage INT DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      deadline TIMESTAMP NULL,
      completed_at TIMESTAMP NULL,
      created_by VARCHAR(36) NOT NULL,
      start_time TIMESTAMP NULL,
      end_time TIMESTAMP NULL,
      color VARCHAR(7) DEFAULT '#4CAF50',
      location VARCHAR(200) NULL,
      is_all_day BOOLEAN DEFAULT FALSE,
      special_notes TEXT NULL,
      FOREIGN KEY (parent_task_id) REFERENCES tasks(id),
      FOREIGN KEY (assignee_id) REFERENCES users(id),
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (created_by) REFERENCES users(id)
    )`,
    
    // 任务通知表
    `CREATE TABLE IF NOT EXISTS task_notifications (
      id VARCHAR(36) PRIMARY KEY,
      task_id VARCHAR(36) NOT NULL,
      from_user_id VARCHAR(36) NOT NULL,
      to_user_id VARCHAR(36) NOT NULL,
      notification_type ENUM('task_assigned', 'task_progress_update', 'task_completed', 'task_cancelled', 'special_notes') NOT NULL,
      message TEXT NOT NULL,
      is_read BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (task_id) REFERENCES tasks(id),
      FOREIGN KEY (from_user_id) REFERENCES users(id),
      FOREIGN KEY (to_user_id) REFERENCES users(id)
    )`,
    
    // 个人日志表
    `CREATE TABLE IF NOT EXISTS personal_logs (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      title VARCHAR(200) NOT NULL,
      content TEXT,
      category VARCHAR(50) NOT NULL,
      quadrant ENUM('important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent') DEFAULT 'important_not_urgent',
      related_task_id VARCHAR(36) NULL,
      is_completed BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (related_task_id) REFERENCES tasks(id)
    )`,
    
    // 系统日志表
    `CREATE TABLE IF NOT EXISTS system_logs (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      user_name VARCHAR(100) NOT NULL,
      action VARCHAR(100) NOT NULL,
      description TEXT,
      category VARCHAR(50) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      metadata JSON,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`
  ];

  for (const table of tables) {
    await db.execute(table);
  }
  
  // 插入示例数据
  await insertSampleData();
}

// 插入示例数据
async function insertSampleData() {
  try {
    // 检查是否已有数据
    const [userCount] = await db.execute('SELECT COUNT(*) as count FROM users');
    if (userCount[0].count > 0) return;

    // 插入部门数据
    const departments = [
      { id: 'dept-001', name: 'HR Department', description: 'Responsible for human resource management and employee relations' },
      { id: 'dept-002', name: 'Finance Department', description: 'Responsible for financial management and capital operations' },
      { id: 'dept-003', name: 'Marketing Department', description: 'Responsible for brand promotion and market expansion' }
    ];

    for (const dept of departments) {
      await db.execute(
        'INSERT INTO departments (id, name, description) VALUES (?, ?, ?)',
        [dept.id, dept.name, dept.description]
      );
    }

    // 创建用户数据
    const users = [
      // 管理员
      { id: 'admin-001', username: 'admin', password: 'admin123', name: '系统管理员', position: '管理员', department_id: 'dept-001', role: 'admin', parent_id: null },
      
      // 创始人
      { id: 'founder-001', username: 'founder1', password: 'founder123', name: '张创始人', position: '创始人', department_id: 'dept-001', role: 'founder', parent_id: null },
      { id: 'founder-002', username: 'founder2', password: 'founder123', name: '李创始人', position: '创始人', department_id: 'dept-001', role: 'founder', parent_id: null },
      
      // 部门老总
      { id: 'dept-head-001', username: 'hr_head', password: 'hr123', name: '王人事总监', position: '人事总监', department_id: 'dept-001', role: 'department_head', parent_id: 'founder-001' },
      { id: 'dept-head-002', username: 'finance_head', password: 'finance123', name: '赵财务总监', position: '财务总监', department_id: 'dept-002', role: 'department_head', parent_id: 'founder-001' },
      { id: 'dept-head-003', username: 'marketing_head', password: 'marketing123', name: '陈宣传总监', position: '宣传总监', department_id: 'dept-003', role: 'department_head', parent_id: 'founder-002' },
      
      // 团队长
      { id: 'team-leader-001', username: 'hr_team1', password: 'hrteam123', name: '刘人事组长', position: '人事组长', department_id: 'dept-001', role: 'team_leader', parent_id: 'dept-head-001' },
      { id: 'team-leader-002', username: 'hr_team2', password: 'hrteam123', name: '孙人事组长', position: '人事组长', department_id: 'dept-001', role: 'team_leader', parent_id: 'dept-head-001' },
      { id: 'team-leader-003', username: 'finance_team1', password: 'financeteam123', name: '周财务组长', position: '财务组长', department_id: 'dept-002', role: 'team_leader', parent_id: 'dept-head-002' },
      { id: 'team-leader-004', username: 'finance_team2', password: 'financeteam123', name: '吴财务组长', position: '财务组长', department_id: 'dept-002', role: 'team_leader', parent_id: 'dept-head-002' },
      { id: 'team-leader-005', username: 'marketing_team1', password: 'marketingteam123', name: '郑宣传组长', position: '宣传组长', department_id: 'dept-003', role: 'team_leader', parent_id: 'dept-head-003' },
      { id: 'team-leader-006', username: 'marketing_team2', password: 'marketingteam123', name: '冯宣传组长', position: '宣传组长', department_id: 'dept-003', role: 'team_leader', parent_id: 'dept-head-003' },
      
      // 员工
      { id: 'employee-001', username: 'hr_emp1', password: 'hremp123', name: '陈人事专员', position: '人事专员', department_id: 'dept-001', role: 'employee', parent_id: 'team-leader-001' },
      { id: 'employee-002', username: 'hr_emp2', password: 'hremp123', name: '褚人事专员', position: '人事专员', department_id: 'dept-001', role: 'employee', parent_id: 'team-leader-001' },
      { id: 'employee-003', username: 'hr_emp3', password: 'hremp123', name: '卫人事专员', position: '人事专员', department_id: 'dept-001', role: 'employee', parent_id: 'team-leader-002' },
      { id: 'employee-004', username: 'hr_emp4', password: 'hremp123', name: '蒋人事专员', position: '人事专员', department_id: 'dept-001', role: 'employee', parent_id: 'team-leader-002' },
      { id: 'employee-005', username: 'finance_emp1', password: 'financeemp123', name: '沈财务专员', position: '财务专员', department_id: 'dept-002', role: 'employee', parent_id: 'team-leader-003' },
      { id: 'employee-006', username: 'finance_emp2', password: 'financeemp123', name: '韩财务专员', position: '财务专员', department_id: 'dept-002', role: 'employee', parent_id: 'team-leader-003' },
      { id: 'employee-007', username: 'finance_emp3', password: 'financeemp123', name: '杨财务专员', position: '财务专员', department_id: 'dept-002', role: 'employee', parent_id: 'team-leader-004' },
      { id: 'employee-008', username: 'finance_emp4', password: 'financeemp123', name: '朱财务专员', position: '财务专员', department_id: 'dept-002', role: 'employee', parent_id: 'team-leader-004' },
      { id: 'employee-009', username: 'marketing_emp1', password: 'marketingemp123', name: '秦宣传专员', position: '宣传专员', department_id: 'dept-003', role: 'employee', parent_id: 'team-leader-005' },
      { id: 'employee-010', username: 'marketing_emp2', password: 'marketingemp123', name: '尤宣传专员', position: '宣传专员', department_id: 'dept-003', role: 'employee', parent_id: 'team-leader-005' },
      { id: 'employee-011', username: 'marketing_emp3', password: 'marketingemp123', name: '许宣传专员', position: '宣传专员', department_id: 'dept-003', role: 'employee', parent_id: 'team-leader-006' },
      { id: 'employee-012', username: 'marketing_emp4', password: 'marketingemp123', name: '何宣传专员', position: '宣传专员', department_id: 'dept-003', role: 'employee', parent_id: 'team-leader-006' }
    ];

    for (const user of users) {
      // 直接存储明文密码，便于测试
      await db.execute(
        'INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [user.id, user.username, user.password, user.name, user.position, user.department_id, user.role, user.parent_id]
      );
    }

    // 插入公司十大重要事项
    const importantItems = [
      { id: 'item-001', title: '2024年度战略规划制定', description: '制定公司2024年度发展战略和业务规划', priority: 'p0', is_selected: true, created_by: 'founder-001' },
      { id: 'item-002', title: '新产品研发项目启动', description: '启动核心产品的新版本研发工作', priority: 'p0', is_selected: true, created_by: 'founder-001' },
      { id: 'item-003', title: '市场扩张计划', description: '制定海外市场扩张和本地化策略', priority: 'p1', is_selected: true, created_by: 'founder-002' },
      { id: 'item-004', title: '人才招聘计划', description: '招聘关键岗位人才，完善团队结构', priority: 'p1', is_selected: true, created_by: 'founder-001' },
      { id: 'item-005', title: '财务合规审计', description: '完成年度财务审计和合规检查', priority: 'p1', is_selected: true, created_by: 'founder-002' },
      { id: 'item-006', title: '品牌升级项目', description: '全面升级公司品牌形象和视觉识别', priority: 'p2', is_selected: true, created_by: 'founder-002' },
      { id: 'item-007', title: '员工培训体系', description: '建立完善的员工培训和发展体系', priority: 'p2', is_selected: true, created_by: 'founder-001' },
      { id: 'item-008', title: '技术架构升级', description: '升级公司技术架构，提升系统性能', priority: 'p2', is_selected: true, created_by: 'founder-001' },
      { id: 'item-009', title: '客户服务体系', description: '优化客户服务流程，提升客户满意度', priority: 'p3', is_selected: true, created_by: 'founder-002' },
      { id: 'item-010', title: '办公环境改善', description: '改善办公环境，提升员工工作体验', priority: 'p3', is_selected: true, created_by: 'founder-001' }
    ];

    for (const item of importantItems) {
      await db.execute(
        'INSERT INTO company_important_items (id, title, description, priority, is_selected, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        [item.id, item.title, item.description, item.priority, item.is_selected, item.created_by]
      );
    }

    console.log('示例数据插入成功');
  } catch (error) {
    console.error('插入示例数据失败:', error);
  }
}

// JWT中间件
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: '访问令牌缺失' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: '无效的访问令牌' });
    }
    req.user = user;
    next();
  });
}

// 权限检查中间件
function checkPermission(requiredRoles) {
  return (req, res, next) => {
    if (!req.user || !requiredRoles.includes(req.user.role)) {
      return res.status(403).json({ error: '权限不足' });
    }
    next();
  };
}

// 路由

// 用户认证
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }

    const [rows] = await db.execute(
      `SELECT u.*, d.name as department_name 
       FROM users u 
       LEFT JOIN departments d ON u.department_id = d.id 
       WHERE u.username = ? AND u.is_active = TRUE`,
      [username]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    const user = rows[0];
    // 直接比较明文密码
    const isValidPassword = (password === user.password);

    if (!isValidPassword) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    // 更新最后登录时间
    await db.execute(
      'UPDATE users SET last_login_at = NOW() WHERE id = ?',
      [user.id]
    );

    // 生成JWT令牌
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role, department_id: user.department_id },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '24h' }
    );

    // 移除密码字段
    delete user.password;

    res.json({
      message: '登录成功',
      user,
      token
    });
  } catch (error) {
    console.error('登录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取用户信息
app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT u.*, d.name as department_name 
       FROM users u 
       LEFT JOIN departments d ON u.department_id = d.id 
       WHERE u.id = ?`,
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: '用户不存在' });
    }

    const user = rows[0];
    delete user.password;

    res.json(user);
  } catch (error) {
    console.error('获取用户信息错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取部门列表
app.get('/api/departments', async (req, res) => {
  try {
    const [rows] = await db.execute('SELECT * FROM departments ORDER BY name');
    res.json(rows);
  } catch (error) {
    console.error('获取部门列表错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取用户列表（根据权限）
app.get('/api/users', authenticateToken, async (req, res) => {
  try {
    let query = `
      SELECT u.id, u.username, u.name, u.position, u.role, u.is_active, u.created_at, u.last_login_at,
             d.name as department_name, p.name as parent_name
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      LEFT JOIN users p ON u.parent_id = p.id
      WHERE u.is_active = TRUE
    `;
    let params = [];

    // 根据用户角色限制可见范围
    if (req.user.role === 'admin') {
      // 管理员可以看到所有用户
    } else if (req.user.role === 'founder') {
      // 创始人可以看到所有用户
    } else if (req.user.role === 'department_head') {
      // 部门老总只能看到本部门用户
      query += ' AND u.department_id = ?';
      params.push(req.user.department_id);
    } else if (req.user.role === 'team_leader') {
      // 团队长只能看到本团队用户
      query += ' AND (u.parent_id = ? OR u.id = ?)';
      params.push(req.user.id, req.user.id);
    } else if (req.user.role === 'employee') {
      // 员工只能看到自己
      query += ' AND u.id = ?';
      params.push(req.user.id);
    }

    query += ' ORDER BY u.role, u.name';

    const [rows] = await db.execute(query, params);
    res.json(rows);
  } catch (error) {
    console.error('获取用户列表错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取公司十大重要事项
app.get('/api/company-important-items', async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT ci.*, u.name as created_by_name, u2.name as updated_by_name
       FROM company_important_items ci
       LEFT JOIN users u ON ci.created_by = u.id
       LEFT JOIN users u2 ON ci.updated_by = u2.id
       WHERE ci.is_selected = TRUE
       ORDER BY ci.priority, ci.created_at DESC`
    );
    res.json(rows);
  } catch (error) {
    console.error('获取公司重要事项错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 兼容旧API - 重要事项
app.get('/api/important-items', async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT ci.*, u.name as created_by_name, u2.name as updated_by_name
       FROM company_important_items ci
       LEFT JOIN users u ON ci.created_by = u.id
       LEFT JOIN users u2 ON ci.updated_by = u2.id
       WHERE ci.is_selected = TRUE
       ORDER BY ci.priority, ci.created_at DESC`
    );
    res.json(rows);
  } catch (error) {
    console.error('获取重要事项错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取所有重要事项（用于编辑）
app.get('/api/company-important-items/all', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT ci.*, u.name as created_by_name, u2.name as updated_by_name
       FROM company_important_items ci
       LEFT JOIN users u ON ci.created_by = u.id
       LEFT JOIN users u2 ON ci.updated_by = u2.id
       ORDER BY ci.priority, ci.created_at DESC`
    );
    res.json(rows);
  } catch (error) {
    console.error('获取所有重要事项错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新重要事项选择状态
app.put('/api/company-important-items/:id/select', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;
    const { is_selected } = req.body;

    await db.execute(
      'UPDATE company_important_items SET is_selected = ?, updated_by = ? WHERE id = ?',
      [is_selected, req.user.id, id]
    );

    res.json({ message: '更新成功' });
  } catch (error) {
    console.error('更新重要事项选择状态错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 创建重要事项
app.post('/api/company-important-items', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { title, description, priority, deadline } = req.body;
    const id = require('crypto').randomUUID();

    await db.execute(
      'INSERT INTO company_important_items (id, title, description, priority, deadline, created_by) VALUES (?, ?, ?, ?, ?, ?)',
      [id, title, description, priority, deadline, req.user.id]
    );

    res.status(201).json({ message: '创建成功', id });
  } catch (error) {
    console.error('创建重要事项错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取任务列表（根据权限）
app.get('/api/tasks', authenticateToken, async (req, res) => {
  try {
    const { startDate, endDate, status } = req.query;
    let query = `
      SELECT t.*, d.name as department_name, u.name as created_by_name
      FROM tasks t
      LEFT JOIN departments d ON t.department_id = d.id
      LEFT JOIN users u ON t.created_by = u.id
      WHERE 1=1
    `;
    let params = [];

    // 根据用户角色限制可见范围
    if (req.user.role === 'admin') {
      // 管理员可以看到所有任务
    } else if (req.user.role === 'founder') {
      // 创始人可以看到所有任务
    } else if (req.user.role === 'department_head') {
      // 部门老总只能看到本部门任务
      query += ' AND t.department_id = ?';
      params.push(req.user.department_id);
    } else if (req.user.role === 'team_leader') {
      // 团队长只能看到分配给自己的任务和分配给下属的任务
      query += ' AND (t.assignee_id = ? OR t.assignee_id IN (SELECT id FROM users WHERE parent_id = ?))';
      params.push(req.user.id, req.user.id);
    } else if (req.user.role === 'employee') {
      // 员工只能看到分配给自己的任务
      query += ' AND t.assignee_id = ?';
      params.push(req.user.id);
    }

    // 日期范围过滤
    if (startDate && endDate) {
      query += ' AND ((t.start_time >= ? AND t.start_time <= ?) OR (t.end_time >= ? AND t.end_time <= ?) OR (t.start_time <= ? AND t.end_time >= ?))';
      params.push(startDate, endDate, startDate, endDate, startDate, endDate);
    }

    // 状态过滤
    if (status) {
      query += ' AND t.status = ?';
      params.push(status);
    }

    query += ' ORDER BY t.priority, t.created_at DESC';

    const [rows] = await db.execute(query, params);
    res.json(rows);
  } catch (error) {
    console.error('获取任务列表错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 创建任务
app.post('/api/tasks', authenticateToken, async (req, res) => {
  try {
    const {
      title,
      description,
      assignee_id,
      department_id,
      priority,
      deadline,
      start_time,
      end_time,
      location,
      is_all_day,
      parent_task_id
    } = req.body;

    // 权限检查
    if (req.user.role === 'employee') {
      return res.status(403).json({ error: '员工无权创建任务' });
    }

    // 获取被分配人信息
    const [assigneeRows] = await db.execute(
      'SELECT name FROM users WHERE id = ?',
      [assignee_id]
    );

    if (assigneeRows.length === 0) {
      return res.status(400).json({ error: '被分配人不存在' });
    }

    const assignee_name = assigneeRows[0].name;
    const taskId = require('crypto').randomUUID();

    await db.execute(
      `INSERT INTO tasks (
        id, title, description, parent_task_id, assignee_id, assignee_name, 
        department_id, priority, deadline, created_by, start_time, end_time, 
        location, is_all_day
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        taskId, title, description, parent_task_id, assignee_id, assignee_name,
        department_id, priority, deadline, req.user.id, start_time, end_time,
        location, is_all_day
      ]
    );

    // 创建任务分配通知
    await createNotification(taskId, req.user.id, assignee_id, 'task_assigned', `您收到了新任务：${title}`);

    res.status(201).json({ message: '任务创建成功', id: taskId });
  } catch (error) {
    console.error('创建任务错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新任务状态
app.put('/api/tasks/:id/status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, progress_percentage, special_notes } = req.body;

    // 获取任务信息
    const [taskRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    if (taskRows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = taskRows[0];

    // 权限检查：只有被分配人才能更新任务状态
    if (task.assignee_id !== req.user.id) {
      return res.status(403).json({ error: '无权更新此任务' });
    }

    const updateData = { status };
    if (progress_percentage !== undefined) updateData.progress_percentage = progress_percentage;
    if (special_notes !== undefined) updateData.special_notes = special_notes;
    if (status === 'completed') updateData.completed_at = new Date();

    await db.execute(
      `UPDATE tasks SET 
       status = ?, progress_percentage = ?, special_notes = ?, completed_at = ?
       WHERE id = ?`,
      [status, updateData.progress_percentage, updateData.special_notes, updateData.completed_at, id]
    );

    // 创建进度更新通知
    if (task.parent_task_id) {
      // 通知上级任务进度更新
      const [parentTask] = await db.execute('SELECT created_by FROM tasks WHERE id = ?', [task.parent_task_id]);
      if (parentTask.length > 0) {
        await createNotification(id, req.user.id, parentTask[0].created_by, 'task_progress_update', `任务进度更新：${task.title}`);
      }
    }

    res.json({ message: '任务状态更新成功' });
  } catch (error) {
    console.error('更新任务状态错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取任务通知
app.get('/api/notifications', authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT tn.*, t.title as task_title, u.name as from_user_name
       FROM task_notifications tn
       LEFT JOIN tasks t ON tn.task_id = t.id
       LEFT JOIN users u ON tn.from_user_id = u.id
       WHERE tn.to_user_id = ?
       ORDER BY tn.created_at DESC`,
      [req.user.id]
    );

    res.json(rows);
  } catch (error) {
    console.error('获取通知错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 标记通知为已读
app.put('/api/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    await db.execute(
      'UPDATE task_notifications SET is_read = TRUE WHERE id = ? AND to_user_id = ?',
      [id, req.user.id]
    );

    res.json({ message: '通知已标记为已读' });
  } catch (error) {
    console.error('标记通知已读错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 创建个人日志
app.post('/api/personal-logs', authenticateToken, async (req, res) => {
  try {
    const { title, content, category, quadrant, related_task_id } = req.body;
    const id = require('crypto').randomUUID();

    await db.execute(
      'INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, req.user.id, title, content, category, quadrant, related_task_id]
    );

    res.status(201).json({ message: '日志创建成功', id });
  } catch (error) {
    console.error('创建个人日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取个人日志
app.get('/api/personal-logs', authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT pl.*, t.title as related_task_title
       FROM personal_logs pl
       LEFT JOIN tasks t ON pl.related_task_id = t.id
       WHERE pl.user_id = ?
       ORDER BY pl.created_at DESC`,
      [req.user.id]
    );

    res.json(rows);
  } catch (error) {
    console.error('获取个人日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 兼容旧API - 个人信息
app.get('/api/personal-info/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const [rows] = await db.execute(
      'SELECT * FROM personal_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT 10',
      [userId]
    );
    res.json(rows);
  } catch (error) {
    console.error('获取个人信息错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 兼容旧API - 系统日志
app.get('/api/logs', async (req, res) => {
  try {
    const [rows] = await db.execute(
      'SELECT * FROM system_logs ORDER BY created_at DESC LIMIT 50'
    );
    res.json(rows);
  } catch (error) {
    console.error('获取日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新个人日志完成状态
app.put('/api/personal-logs/:id/complete', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { is_completed } = req.body;

    await db.execute(
      'UPDATE personal_logs SET is_completed = ? WHERE id = ? AND user_id = ?',
      [is_completed, id, req.user.id]
    );

    // 如果日志关联了任务，更新任务进度
    const [logRows] = await db.execute(
      'SELECT related_task_id FROM personal_logs WHERE id = ?',
      [id]
    );

    if (logRows.length > 0 && logRows[0].related_task_id) {
      // 计算该任务关联的已完成日志数量
      const [completedLogs] = await db.execute(
        'SELECT COUNT(*) as count FROM personal_logs WHERE related_task_id = ? AND is_completed = TRUE',
        [logRows[0].related_task_id]
      );

      // 更新任务进度（这里简化处理，实际可能需要更复杂的计算）
      const progressPercentage = Math.min(completedLogs[0].count * 10, 100);
      
      await db.execute(
        'UPDATE tasks SET progress_percentage = ? WHERE id = ?',
        [progressPercentage, logRows[0].related_task_id]
      );
    }

    res.json({ message: '日志状态更新成功' });
  } catch (error) {
    console.error('更新日志状态错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 辅助函数：创建通知
async function createNotification(taskId, fromUserId, toUserId, type, message) {
  try {
    const notificationId = require('crypto').randomUUID();
    await db.execute(
      'INSERT INTO task_notifications (id, task_id, from_user_id, to_user_id, notification_type, message) VALUES (?, ?, ?, ?, ?, ?)',
      [notificationId, taskId, fromUserId, toUserId, type, message]
    );
  } catch (error) {
    console.error('创建通知失败:', error);
  }
}

// 启动服务器
async function startServer() {
  await initDatabase();
  
  app.listen(PORT, () => {
    console.log(`企业管理系统服务器运行在端口 ${PORT}`);
    console.log(`API地址: http://localhost:${PORT}/api`);
    console.log(`Web管理端: http://localhost:${PORT}/web_admin`);
    console.log(`\n📱 测试账户:`);
    console.log(`   管理员: admin / admin123`);
    console.log(`   创始人: founder1 / founder123, founder2 / founder123`);
    console.log(`   人事总监: hr_head / hr123`);
    console.log(`   财务总监: finance_head / finance123`);
    console.log(`   宣传总监: marketing_head / marketing123`);
    console.log(`   团队长: hr_team1 / hrteam123, finance_team1 / financeteam123, marketing_team1 / marketingteam123`);
    console.log(`   员工: hr_emp1 / hremp123, finance_emp1 / financeemp123, marketing_emp1 / marketingemp123`);
    console.log(`\n🌐 访问地址:`);
    console.log(`   API接口: http://localhost:${PORT}/api`);
    console.log(`   Web管理: http://localhost:${PORT}/web_admin`);
  });
}

startServer().catch(console.error);

// ================= AI 文本分析（基础版） =================
// 提取关键词和词频统计
app.post('/api/ai/analyze-log', async (req, res) => {
  try {
    const { text, topK = 20 } = req.body || {};
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text 不能为空' });
    }

    // 使用 segmentit 分词（纯JS实现，无需编译）
    const tokens = segmenter.doSegment(text, { simple: true })
      .filter(w => w && w.trim().length > 1);
    const freqMap = {};
    for (const w of tokens) {
      freqMap[w] = (freqMap[w] || 0) + 1;
    }
    const wordFrequencies = Object.entries(freqMap)
      .map(([word, count]) => ({ word, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, topK);

    // 用频次代替简易“权重”，并归一化一个权重字段
    const maxCount = wordFrequencies.length > 0 ? wordFrequencies[0].count : 1;
    const keywords = wordFrequencies.map(x => ({ word: x.word, weight: x.count / (maxCount || 1) }));

    return res.json({
      keywords,
      wordFrequencies
    });
  } catch (e) {
    console.error('AI分析失败:', e);
    return res.status(500).json({ error: 'AI分析失败' });
  }
});

// 基于当天个人日志的一键分析（需登录）
app.get('/api/ai/analyze-today', authenticateToken, async (req, res) => {
  try {
    const { topK = 20 } = req.query;
    const userId = req.user.id;

    // 查询当天该用户的个人日志（title+content）
    let [rows] = await db.execute(
      `SELECT title, content
       FROM personal_logs
       WHERE user_id = ?
         AND DATE(created_at) = CURDATE()`,
      [userId]
    );
    let usedRange = 'today';

    if (!rows || rows.length === 0) {
      const [rows7] = await db.execute(
        `SELECT title, content
         FROM personal_logs
         WHERE user_id = ?
           AND created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)`,
        [userId]
      );
      rows = rows7 || [];
      usedRange = 'last7days';
    }

    if (!rows || rows.length === 0) {
      return res.json({ keywords: [], wordFrequencies: [], range: usedRange });
    }

    const combined = rows.map(r => `${r.title || ''} ${r.content || ''}`).join(' \n ');
    const tokens = segmenter.doSegment(combined, { simple: true })
      .filter(w => w && w.trim().length > 1);

    const freqMap = {};
    for (const w of tokens) {
      freqMap[w] = (freqMap[w] || 0) + 1;
    }
    const wordFrequencies = Object.entries(freqMap)
      .map(([word, count]) => ({ word, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, Number(topK));

    const maxCount = wordFrequencies.length > 0 ? wordFrequencies[0].count : 1;
    const keywords = wordFrequencies.map(x => ({ word: x.word, weight: x.count / (maxCount || 1) }));

    return res.json({ keywords, wordFrequencies, range: usedRange });
  } catch (e) {
    console.error('AI当天日志分析失败:', e);
    return res.status(500).json({ error: 'AI当天日志分析失败' });
  }
});
