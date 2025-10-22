const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// 中间件
app.use(cors());
app.use(express.json());

// 静态文件服务 - 提供Web管理端
app.use('/web_admin', express.static('../web_admin'));

// 静态文件服务 - 提供公共资源
app.use('/public', express.static(path.join(__dirname, 'public')));

// 数据库连接
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'asdfgh0625YYH',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4',
  multipleStatements: true
};

let db;

// 初始化数据库连接
async function initDatabase() {
  try {
    db = await mysql.createConnection(dbConfig);
    
    // 设置连接字符集
    await db.query("SET NAMES 'utf8mb4'");
    await db.query("SET CHARACTER SET utf8mb4");
    await db.query("SET character_set_connection=utf8mb4");
    
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

    // 插入任务数据（2025年10月的测试数据）
    const tasks = [
      { 
        id: 'task-001', 
        title: '完成Q4季度报告', 
        description: '整理并提交Q4季度工作总结报告', 
        assignee_id: 'employee-001',
        assignee_name: '陈人事专员',
        department_id: 'dept-001',
        priority: 'p0',
        status: 'in_progress',
        progress_percentage: 60,
        start_time: '2025-10-15 09:00:00',
        end_time: '2025-10-15 18:00:00',
        deadline: '2025-10-20 18:00:00',
        color: '#FF5722',
        is_all_day: false,
        created_by: 'dept-head-001'
      },
      { 
        id: 'task-002', 
        title: '团队会议准备', 
        description: '准备下周团队会议的议程和材料', 
        assignee_id: 'employee-001',
        assignee_name: '陈人事专员',
        department_id: 'dept-001',
        priority: 'p1',
        status: 'pending',
        progress_percentage: 0,
        start_time: '2025-10-18 10:00:00',
        end_time: '2025-10-18 12:00:00',
        deadline: '2025-10-18 12:00:00',
        color: '#2196F3',
        is_all_day: false,
        created_by: 'team-leader-001'
      },
      { 
        id: 'task-003', 
        title: '新员工入职培训', 
        description: '组织新员工入职培训活动', 
        assignee_id: 'employee-001',
        assignee_name: '陈人事专员',
        department_id: 'dept-001',
        priority: 'p1',
        status: 'completed',
        progress_percentage: 100,
        start_time: '2025-10-16 14:00:00',
        end_time: '2025-10-16 17:00:00',
        deadline: '2025-10-16 17:00:00',
        color: '#4CAF50',
        is_all_day: false,
        created_by: 'dept-head-001',
        completed_at: '2025-10-16 16:45:00'
      },
      { 
        id: 'task-004', 
        title: '整理人事档案', 
        description: '整理和归档本月人事档案', 
        assignee_id: 'employee-001',
        assignee_name: '陈人事专员',
        department_id: 'dept-001',
        priority: 'p2',
        status: 'in_progress',
        progress_percentage: 30,
        start_time: '2025-10-19 09:00:00',
        end_time: '2025-10-19 17:00:00',
        deadline: '2025-10-25 18:00:00',
        color: '#FFC107',
        is_all_day: false,
        created_by: 'team-leader-001'
      },
      { 
        id: 'task-005', 
        title: '月度考勤统计', 
        description: '统计本月员工考勤数据', 
        assignee_id: 'employee-001',
        assignee_name: '陈人事专员',
        department_id: 'dept-001',
        priority: 'p1',
        status: 'pending',
        progress_percentage: 0,
        start_time: '2025-10-25 09:00:00',
        end_time: '2025-10-25 17:00:00',
        deadline: '2025-10-31 18:00:00',
        color: '#9C27B0',
        is_all_day: false,
        created_by: 'dept-head-001'
      }
    ];

    for (const task of tasks) {
      await db.execute(
        `INSERT INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, 
         progress_percentage, start_time, end_time, deadline, color, is_all_day, created_by, completed_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [task.id, task.title, task.description, task.assignee_id, task.assignee_name, task.department_id, 
         task.priority, task.status, task.progress_percentage, task.start_time, task.end_time, task.deadline, 
         task.color, task.is_all_day, task.created_by, task.completed_at || null]
      );
    }

    // 插入个人日志数据（2025年10月的测试数据）
    const logs = [
      {
        id: 'log-001',
        user_id: 'employee-001',
        title: '完成新员工培训',
        content: '今天成功组织了新员工入职培训，培训效果良好，新员工反馈积极。',
        category: '工作总结',
        quadrant: 'important_urgent',
        is_completed: true,
        created_at: '2025-10-16 17:30:00',
        related_task_id: 'task-003'
      },
      {
        id: 'log-002',
        user_id: 'employee-001',
        title: '季度报告进度更新',
        content: '完成了季度报告的数据收集工作，正在进行数据分析和报告撰写。预计明天可以完成初稿。',
        category: '工作进展',
        quadrant: 'important_urgent',
        is_completed: false,
        created_at: '2025-10-15 18:00:00',
        related_task_id: 'task-001'
      },
      {
        id: 'log-003',
        user_id: 'employee-001',
        title: '团队沟通会议',
        content: '参加了部门团队沟通会议，讨论了本月工作重点和下月计划。',
        category: '会议记录',
        quadrant: 'important_not_urgent',
        is_completed: true,
        created_at: '2025-10-18 11:30:00',
        related_task_id: null
      },
      {
        id: 'log-004',
        user_id: 'employee-001',
        title: '档案整理工作开始',
        content: '开始整理本月人事档案，完成了大约30%的工作量。',
        category: '工作记录',
        quadrant: 'not_important_urgent',
        is_completed: false,
        created_at: '2025-10-19 16:00:00',
        related_task_id: 'task-004'
      },
      {
        id: 'log-005',
        user_id: 'employee-001',
        title: '学习新的HR系统',
        content: '花时间学习了新的人力资源管理系统，掌握了基本操作。',
        category: '学习笔记',
        quadrant: 'important_not_urgent',
        is_completed: true,
        created_at: '2025-10-17 15:00:00',
        related_task_id: null
      }
    ];

    for (const log of logs) {
      await db.execute(
        `INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, is_completed, created_at, related_task_id) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [log.id, log.user_id, log.title, log.content, log.category, log.quadrant, log.is_completed, log.created_at, log.related_task_id]
      );
    }

    console.log('示例数据插入成功（包含任务和日志）');
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

// API 根路径 - 返回 API 文档页面
app.get('/api', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'api-docs.html'));
});

// API 根路径（旧版本 - 保留以防需要）
app.get('/api/old', (req, res) => {
  const html = `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>企业管理系统 API 文档与测试</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 40px 20px;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      border-radius: 20px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 40px;
      text-align: center;
    }
    .header h1 {
      font-size: 2.5em;
      margin-bottom: 10px;
    }
    .header .status {
      display: inline-block;
      background: rgba(255,255,255,0.2);
      padding: 8px 20px;
      border-radius: 20px;
      font-size: 0.9em;
      margin-top: 10px;
    }
    .status-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      background: #4ade80;
      border-radius: 50%;
      margin-right: 8px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    .content {
      padding: 40px;
    }
    .section {
      margin-bottom: 40px;
    }
    .section-title {
      font-size: 1.8em;
      color: #333;
      margin-bottom: 20px;
      padding-bottom: 10px;
      border-bottom: 3px solid #667eea;
    }
    .endpoint-group {
      background: #f8f9fa;
      border-radius: 10px;
      padding: 20px;
      margin-bottom: 20px;
    }
    .endpoint-group h3 {
      color: #667eea;
      font-size: 1.3em;
      margin-bottom: 15px;
      display: flex;
      align-items: center;
    }
    .endpoint-group h3:before {
      content: "📁";
      margin-right: 10px;
    }
    .endpoint {
      background: white;
      padding: 15px 20px;
      margin-bottom: 10px;
      border-radius: 8px;
      border-left: 4px solid #667eea;
      display: flex;
      align-items: center;
      transition: all 0.3s;
    }
    .endpoint:hover {
      transform: translateX(5px);
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .method {
      display: inline-block;
      padding: 6px 12px;
      border-radius: 5px;
      font-weight: bold;
      font-size: 0.85em;
      margin-right: 15px;
      min-width: 60px;
      text-align: center;
    }
    .method.get { background: #10b981; color: white; }
    .method.post { background: #3b82f6; color: white; }
    .method.put { background: #f59e0b; color: white; }
    .method.delete { background: #ef4444; color: white; }
    .endpoint-path {
      flex: 1;
      font-family: 'Courier New', monospace;
      color: #333;
      font-size: 1em;
    }
    .quick-links {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-top: 20px;
    }
    .quick-link {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 25px;
      border-radius: 10px;
      text-decoration: none;
      text-align: center;
      transition: all 0.3s;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .quick-link:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 24px rgba(0,0,0,0.2);
    }
    .quick-link h3 {
      font-size: 1.2em;
      margin-bottom: 8px;
    }
    .quick-link p {
      font-size: 0.9em;
      opacity: 0.9;
    }
    .footer {
      text-align: center;
      padding: 30px;
      background: #f8f9fa;
      color: #666;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚀 企业管理系统 API</h1>
      <div class="status">
        <span class="status-dot"></span>
        <span>服务运行中 · v1.0.0</span>
      </div>
    </div>
    
    <div class="content">
      <div class="section">
        <h2 class="section-title">🔗 快速访问</h2>
        <div class="quick-links">
          <a href="/web_admin" class="quick-link">
            <h3>🖥️ Web 管理端</h3>
            <p>访问 Web 管理界面</p>
          </a>
          <a href="http://localhost:8080" class="quick-link">
            <h3>🏠 主页</h3>
            <p>返回系统主页</p>
          </a>
        </div>
      </div>

      <div class="section">
        <h2 class="section-title">📡 API 端点</h2>
        
        <div class="endpoint-group">
          <h3>用户认证</h3>
          <div class="endpoint">
            <span class="method post">POST</span>
            <span class="endpoint-path">/api/auth/login</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>用户管理</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/user/profile</span>
          </div>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/users</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>部门管理</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/departments</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>公司重要事项</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/company-important-items</span>
          </div>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/company-important-items/all</span>
          </div>
          <div class="endpoint">
            <span class="method post">POST</span>
            <span class="endpoint-path">/api/company-important-items</span>
          </div>
          <div class="endpoint">
            <span class="method put">PUT</span>
            <span class="endpoint-path">/api/company-important-items/:id/select</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>重要事项库</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/important-items</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>任务管理</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/tasks</span>
          </div>
          <div class="endpoint">
            <span class="method post">POST</span>
            <span class="endpoint-path">/api/tasks</span>
          </div>
          <div class="endpoint">
            <span class="method put">PUT</span>
            <span class="endpoint-path">/api/tasks/:id/status</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>通知管理</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/notifications</span>
          </div>
          <div class="endpoint">
            <span class="method put">PUT</span>
            <span class="endpoint-path">/api/notifications/:id/read</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>个人日志</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/personal-logs</span>
          </div>
          <div class="endpoint">
            <span class="method post">POST</span>
            <span class="endpoint-path">/api/personal-logs</span>
          </div>
          <div class="endpoint">
            <span class="method put">PUT</span>
            <span class="endpoint-path">/api/personal-logs/:id/complete</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>系统日志</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/logs</span>
          </div>
        </div>

        <div class="endpoint-group">
          <h3>个人信息</h3>
          <div class="endpoint">
            <span class="method get">GET</span>
            <span class="endpoint-path">/api/personal-info/:userId</span>
          </div>
        </div>
      </div>
    </div>
    
    <div class="footer">
      <p>© 2024 企业管理系统 · API v1.0.0 · 运行在 http://localhost:8080</p>
    </div>
  </div>
</body>
</html>
  `;
  res.send(html);
});

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

// 更新任务（完整更新，用于日历编辑）
app.put('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, priority, status } = req.body;

    // 获取任务信息
    const [taskRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    if (taskRows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = taskRows[0];

    // 权限检查：只有被分配人或创建者才能更新任务
    if (task.assignee_id !== req.user.id && task.created_by !== req.user.id) {
      return res.status(403).json({ error: '无权更新此任务' });
    }

    // 构建更新语句
    const updates = [];
    const values = [];
    
    if (title !== undefined) {
      updates.push('title = ?');
      values.push(title);
    }
    
    if (description !== undefined) {
      updates.push('description = ?');
      values.push(description);
    }
    
    if (priority !== undefined) {
      updates.push('priority = ?');
      values.push(priority);
    }
    
    if (status !== undefined) {
      updates.push('status = ?');
      values.push(status);
      
      // 如果状态改为已完成，记录完成时间
      if (status === 'completed') {
        updates.push('completed_at = ?');
        values.push(new Date());
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '没有要更新的字段' });
    }

    values.push(id);
    
    await db.execute(
      `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: '任务更新成功' });
  } catch (error) {
    console.error('更新任务错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除任务
app.delete('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // 获取任务信息
    const [taskRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    if (taskRows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = taskRows[0];

    // 权限检查：只有创建者才能删除任务
    if (task.created_by !== req.user.id) {
      return res.status(403).json({ error: '无权删除此任务' });
    }

    // 删除任务
    await db.execute('DELETE FROM tasks WHERE id = ?', [id]);

    res.json({ message: '任务删除成功' });
  } catch (error) {
    console.error('删除任务错误:', error);
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
  const connection = db; // 单连接环境
  try {
    const { log, linkages } = req.body || {};
    if (!log) {
      return res.status(400).json({ error: '缺少日志数据' });
    }

    const logId = log.log_id || require('crypto').randomUUID();
    const userId = req.user.id;
    const logDate = log.log_date;
    const weather = log.weather;
    const keywords = log.keywords || null;
    const logTitle = log.log_title || '个人日志';
    const logContent = log.log_content || null;
    const category = log.category || 'work';
    const quadrant = log.quadrant || 'important_not_urgent';
    const isArchived = !!log.is_archived;

    await connection.execute(
      `INSERT INTO personal_logs (log_id, user_id, log_date, weather, keywords, log_title, log_content, category, quadrant, is_archived)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [logId, userId, logDate, weather, keywords, logTitle, logContent, category, quadrant, isArchived]
    );

    if (Array.isArray(linkages) && linkages.length > 0) {
      for (const l of linkages) {
        const taskId = l.task_id;
        const progress = Number(l.progress_percentage ?? 0);
        const status = l.task_status || 'in_progress';
        await connection.execute(
          `INSERT INTO log_task_linkage (log_id, task_id, progress_percentage, task_status)
           VALUES (?, ?, ?, ?)`,
          [logId, taskId, progress, status]
        );
        // 可选：同步更新任务表的进度/状态
        await connection.execute(
          `UPDATE tasks SET progress_percentage = ?, status = ? WHERE id = ?`,
          [progress, status === 'interrupted' ? 'cancelled' : status, taskId]
        );
      }
    }

    res.status(201).json({ message: '日志创建成功', id: logId });
  } catch (error) {
    console.error('创建个人日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取个人日志（主表+关联）
app.get('/api/personal-logs', authenticateToken, async (req, res) => {
  try {
    const [logs] = await db.execute(
      `SELECT * FROM personal_logs WHERE user_id = ? ORDER BY created_at DESC`,
      [req.user.id]
    );

    const result = [];
    for (const row of logs) {
      const [links] = await db.execute(
        `SELECT log_id, task_id, progress_percentage, task_status, linkage_time FROM log_task_linkage WHERE log_id = ?`,
        [row.log_id]
      );
      result.push({
        ...row,
        linkages: links,
      });
    }

    res.json(result);
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

// 更新个人日志（完整更新，用于日历编辑）
app.put('/api/logs/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content } = req.body;

    // 获取日志信息
    const [logRows] = await db.execute(
      'SELECT * FROM personal_logs WHERE id = ?',
      [id]
    );

    if (logRows.length === 0) {
      return res.status(404).json({ error: '日志不存在' });
    }

    const log = logRows[0];

    // 权限检查：只有创建者才能更新日志
    if (log.user_id !== req.user.id) {
      return res.status(403).json({ error: '无权更新此日志' });
    }

    // 构建更新语句
    const updates = [];
    const values = [];
    
    if (title !== undefined) {
      updates.push('title = ?');
      values.push(title);
    }
    
    if (content !== undefined) {
      updates.push('content = ?');
      values.push(content);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '没有要更新的字段' });
    }

    values.push(id);
    
    await db.execute(
      `UPDATE personal_logs SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: '日志更新成功' });
  } catch (error) {
    console.error('更新日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除个人日志
app.delete('/api/logs/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // 获取日志信息
    const [logRows] = await db.execute(
      'SELECT * FROM personal_logs WHERE id = ?',
      [id]
    );

    if (logRows.length === 0) {
      return res.status(404).json({ error: '日志不存在' });
    }

    const log = logRows[0];

    // 权限检查：只有创建者才能删除日志
    if (log.user_id !== req.user.id) {
      return res.status(403).json({ error: '无权删除此日志' });
    }

    // 删除日志
    await db.execute('DELETE FROM personal_logs WHERE id = ?', [id]);

    res.json({ message: '日志删除成功' });
  } catch (error) {
    console.error('删除日志错误:', error);
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

// ==================== 月视图 API ====================

// 获取指定月份的任务和日志（用于月视图日历）
app.get('/api/calendar/month-view', authenticateToken, async (req, res) => {
  try {
    const { year, month } = req.query;
    
    if (!year || !month) {
      return res.status(400).json({ error: '请提供年份(year)和月份(month)参数' });
    }
    
    // 计算月份的开始和结束日期
    const startDate = `${year}-${String(month).padStart(2, '0')}-01 00:00:00`;
    const lastDay = new Date(year, month, 0).getDate();
    const endDate = `${year}-${String(month).padStart(2, '0')}-${lastDay} 23:59:59`;
    
    // 获取任务
    let taskQuery = `
      SELECT DISTINCT
        t.id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.color,
        t.start_time,
        t.end_time,
        t.deadline,
        t.is_all_day,
        t.assignee_name,
        DATE_FORMAT(COALESCE(t.start_time, t.deadline), '%Y-%m-%d') as task_date
      FROM tasks t
      WHERE t.assignee_id = ?
      AND (
        DATE(t.start_time) BETWEEN ? AND ?
        OR DATE(t.end_time) BETWEEN ? AND ?
        OR DATE(t.deadline) BETWEEN ? AND ?
      )
      ORDER BY t.start_time, t.priority
    `;
    
    const startDateOnly = `${year}-${String(month).padStart(2, '0')}-01`;
    const endDateOnly = `${year}-${String(month).padStart(2, '0')}-${lastDay}`;
    
    const [tasks] = await db.execute(taskQuery, [
      req.user.id, 
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly
    ]);
    
    // 获取个人日志
    let logQuery = `
      SELECT 
        pl.id,
        pl.title,
        pl.content,
        pl.category,
        pl.quadrant,
        pl.is_completed,
        pl.created_at,
        DATE_FORMAT(pl.created_at, '%Y-%m-%d') as log_date
      FROM personal_logs pl
      WHERE pl.user_id = ?
      AND pl.created_at >= ?
      AND pl.created_at <= ?
      ORDER BY pl.created_at DESC
    `;
    
    const [logs] = await db.execute(logQuery, [
      req.user.id,
      startDate,
      endDate
    ]);
    
    console.log(`[月视图] 用户 ${req.user.id} (${req.user.username}) 请求 ${year}年${month}月 的数据: ${tasks.length} 个任务, ${logs.length} 个日志`);
    
    // 按日期分组
    const calendar = {};
    
    // 初始化整个月的日期
    for (let day = 1; day <= lastDay; day++) {
      const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      calendar[dateKey] = {
        date: dateKey,
        tasks: [],
        logs: [],
        hasData: false
      };
    }
    
    // 填充任务数据
    tasks.forEach(task => {
      if (task.task_date) {
        const dateKey = task.task_date;
        console.log(`  任务 "${task.title}" 的日期: ${dateKey}, 日历中是否存在: ${!!calendar[dateKey]}`);
        if (calendar[dateKey]) {
          calendar[dateKey].tasks.push({
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            color: task.color,
            start_time: task.start_time,
            end_time: task.end_time,
            deadline: task.deadline,
            is_all_day: task.is_all_day,
            assignee_name: task.assignee_name
          });
          calendar[dateKey].hasData = true;
        }
      }
    });
    
    // 填充日志数据
    logs.forEach(log => {
      if (log.log_date) {
        const dateKey = log.log_date;
        console.log(`  日志 "${log.title}" 的日期: ${dateKey}, 日历中是否存在: ${!!calendar[dateKey]}`);
        if (calendar[dateKey]) {
          calendar[dateKey].logs.push({
            id: log.id,
            title: log.title,
            content: log.content,
            category: log.category,
            quadrant: log.quadrant,
            is_completed: log.is_completed,
            created_at: log.created_at
          });
          calendar[dateKey].hasData = true;
        }
      }
    });
    
    // 转换为数组格式
    const calendarArray = Object.values(calendar);
    
    res.json({
      year: parseInt(year),
      month: parseInt(month),
      days: calendarArray,
      summary: {
        totalTasks: tasks.length,
        totalLogs: logs.length,
        daysWithData: calendarArray.filter(d => d.hasData).length
      }
    });
    
  } catch (error) {
    console.error('获取月视图数据错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 测试API: 获取指定用户和月份的任务和日志（无需认证，用于测试）
app.get('/api/month-view/:userId/:year/:month', async (req, res) => {
  try {
    const { userId, year, month } = req.params;
    
    if (!userId || !year || !month) {
      return res.status(400).json({ error: '请提供userId、year和month参数' });
    }
    
    // 计算月份的开始和结束日期
    const startDate = `${year}-${String(month).padStart(2, '0')}-01 00:00:00`;
    const lastDay = new Date(year, month, 0).getDate();
    const endDate = `${year}-${String(month).padStart(2, '0')}-${lastDay} 23:59:59`;
    
    // 获取任务
    let taskQuery = `
      SELECT DISTINCT
        t.id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.color,
        t.start_time,
        t.end_time,
        t.deadline,
        t.is_all_day,
        t.assignee_name,
        DATE_FORMAT(COALESCE(t.start_time, t.deadline), '%Y-%m-%d') as task_date
      FROM tasks t
      WHERE t.assignee_id = ?
      AND (
        DATE(t.start_time) BETWEEN ? AND ?
        OR DATE(t.end_time) BETWEEN ? AND ?
        OR DATE(t.deadline) BETWEEN ? AND ?
      )
      ORDER BY t.start_time, t.priority
    `;
    
    const startDateOnly = `${year}-${String(month).padStart(2, '0')}-01`;
    const endDateOnly = `${year}-${String(month).padStart(2, '0')}-${lastDay}`;
    
    const [tasks] = await db.execute(taskQuery, [
      userId, 
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly
    ]);
    
    // 获取个人日志
    let logQuery = `
      SELECT 
        pl.id,
        pl.title,
        pl.content,
        pl.category,
        pl.quadrant,
        pl.is_completed,
        pl.created_at,
        DATE_FORMAT(pl.created_at, '%Y-%m-%d') as log_date
      FROM personal_logs pl
      WHERE pl.user_id = ?
      AND pl.created_at >= ?
      AND pl.created_at <= ?
      ORDER BY pl.created_at DESC
    `;
    
    const [logs] = await db.execute(logQuery, [
      userId,
      startDate,
      endDate
    ]);
    
    console.log(`[测试-月视图] 用户 ${userId} 请求 ${year}年${month}月 的数据: ${tasks.length} 个任务, ${logs.length} 个日志`);
    
    // 统计信息
    const completedTasks = tasks.filter(t => t.status === 'completed').length;
    const inProgressTasks = tasks.filter(t => t.status === 'in_progress').length;
    const pendingTasks = tasks.filter(t => t.status === 'pending').length;
    const completedLogs = logs.filter(l => l.is_completed === 1).length;
    
    // 返回简化的数据格式
    res.json({
      month: `${year}-${String(month).padStart(2, '0')}`,
      userId: userId,
      logs: logs.map(log => ({
        id: log.id,
        title: log.title,
        content: log.content,
        category: log.category,
        quadrant: log.quadrant,
        isCompleted: log.is_completed === 1,
        date: log.log_date,
        createdAt: log.created_at
      })),
      tasks: tasks.map(task => ({
        id: task.id,
        title: task.title,
        description: task.description,
        status: task.status,
        priority: task.priority,
        color: task.color,
        startTime: task.start_time,
        endTime: task.end_time,
        deadline: task.deadline,
        isAllDay: task.is_all_day === 1,
        assigneeName: task.assignee_name,
        date: task.task_date
      })),
      statistics: {
        totalTasks: tasks.length,
        completedTasks: completedTasks,
        inProgressTasks: inProgressTasks,
        pendingTasks: pendingTasks,
        totalLogs: logs.length,
        completedLogs: completedLogs
      }
    });
    
  } catch (error) {
    console.error('获取月视图数据错误:', error);
    res.status(500).json({ error: '服务器内部错误', message: error.message });
  }
});

// 获取指定日期的详细任务和日志（用于点击日期时弹窗显示）
app.get('/api/calendar/day-detail', authenticateToken, async (req, res) => {
  try {
    const { date } = req.query; // 格式: YYYY-MM-DD
    
    if (!date) {
      return res.status(400).json({ error: '请提供日期(date)参数，格式: YYYY-MM-DD' });
    }
    
    const startDate = `${date} 00:00:00`;
    const endDate = `${date} 23:59:59`;
    
    // 获取该日期的所有任务
    let taskQuery = `
      SELECT 
        t.*,
        d.name as department_name,
        u.name as creator_name
      FROM tasks t
      LEFT JOIN departments d ON t.department_id = d.id
      LEFT JOIN users u ON t.created_by = u.id
      WHERE t.assignee_id = ?
      AND (
        (t.start_time >= ? AND t.start_time <= ?)
        OR (t.end_time >= ? AND t.end_time <= ?)
        OR (t.deadline >= ? AND t.deadline <= ?)
        OR (DATE(t.start_time) = ? OR DATE(t.end_time) = ? OR DATE(t.deadline) = ?)
      )
      ORDER BY t.start_time, t.priority
    `;
    
    const [tasks] = await db.execute(taskQuery, [
      req.user.id,
      startDate, endDate,
      startDate, endDate,
      startDate, endDate,
      date, date, date
    ]);
    
    // 获取该日期的所有日志
    let logQuery = `
      SELECT 
        pl.*,
        t.title as task_title
      FROM personal_logs pl
      LEFT JOIN tasks t ON pl.related_task_id = t.id
      WHERE pl.user_id = ?
      AND DATE(pl.created_at) = ?
      ORDER BY pl.created_at DESC
    `;
    
    const [logs] = await db.execute(logQuery, [
      req.user.id,
      date
    ]);
    
    console.log(`[日期详情] 用户 ${req.user.id} 请求 ${date} 的数据: ${tasks.length} 个任务, ${logs.length} 个日志`);
    
    res.json({
      date: date,
      tasks: tasks.map(t => ({
        id: t.id,
        title: t.title,
        description: t.description,
        status: t.status,
        priority: t.priority,
        color: t.color,
        start_time: t.start_time,
        end_time: t.end_time,
        deadline: t.deadline,
        is_all_day: t.is_all_day,
        assignee_name: t.assignee_name
      })),
      logs: logs.map(l => ({
        id: l.id,
        title: l.title,
        content: l.content,
        category: l.category,
        quadrant: l.quadrant,
        is_completed: l.is_completed,
        created_at: l.created_at
      })),
      summary: {
        totalTasks: tasks.length,
        totalLogs: logs.length,
        completedTasks: tasks.filter(t => t.status === 'completed').length,
        completedLogs: logs.filter(l => l.is_completed).length
      }
    });
    
  } catch (error) {
    console.error('获取日期详情错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

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
