const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
const axios = require('axios');
require('dotenv').config();
// const { useDefault, Segment } = require('segmentit');
// const segmenter = useDefault(new Segment());

const app = express();
const PORT = process.env.PORT || 8080;

// DeepSeek API 配置
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const DEEPSEEK_API_URL = process.env.DEEPSEEK_API_URL || 'https://api.deepseek.com/v1/chat/completions';

// 中间件
app.use(cors());
app.use(express.json());

// 静态文件服务 - 提供Web管理端
app.use('/web_admin', express.static('../web_admin'));

// 静态文件服务 - 提供公共资源
app.use('/public', express.static(path.join(__dirname, 'public')));

// 静态文件服务 - 根路径访问public目录
app.use('/', express.static(path.join(__dirname, 'public')));

// 数据库连接
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'Pyx_07091817',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4',
  multipleStatements: true,
  timezone: '+08:00',  // 设置为北京时间
  waitForConnections: true,
  connectionLimit: 20,
  queueLimit: 0,
  connectTimeout: 10000
};

let db; // 连接池

// 时区处理工具函数
// 将MySQL返回的Date对象或字符串转换为北京时间的ISO字符串
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

// 安全解析JSON字段的辅助函数（MySQL 2可能已自动解析JSON字段）
function safeParseJSON(value) {
  if (!value) return null;
  if (typeof value === 'object') return value; // 已经是对象，直接返回
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch (e) {
      console.warn('JSON解析失败:', e.message, 'Value type:', typeof value);
      return value;
    }
  }
  return value;
}

// 初始化数据库连接
async function initDatabase() {
  try {
    db = mysql.createPool(dbConfig);

    // 测试并设置字符集
    const connection = await db.getConnection();
    await connection.query("SET NAMES 'utf8mb4'");
    await connection.query("SET CHARACTER SET utf8mb4");
    await connection.query("SET character_set_connection=utf8mb4");
    connection.release();

    console.log('数据库连接池创建成功');
    
    // 创建表
    await createTables();
  } catch (error) {
    console.error('数据库连接池创建失败:', error);
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
      updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
      location VARCHAR(200) NULL,
      is_all_day BOOLEAN DEFAULT FALSE,
      special_notes TEXT NULL,
      is_request BOOLEAN DEFAULT FALSE,
      request_type VARCHAR(50) NULL,
      request_response VARCHAR(20) NULL,
      related_task_id VARCHAR(36) NULL,
      FOREIGN KEY (parent_task_id) REFERENCES tasks(id),
      FOREIGN KEY (assignee_id) REFERENCES users(id),
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (created_by) REFERENCES users(id),
      FOREIGN KEY (related_task_id) REFERENCES tasks(id)
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
      log_id VARCHAR(36) UNIQUE,
      user_id VARCHAR(36) NOT NULL,
      title VARCHAR(200) NOT NULL DEFAULT '个人日志',
      content TEXT,
      category VARCHAR(50) NOT NULL DEFAULT 'work',
      quadrant ENUM('important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent') DEFAULT 'important_not_urgent',
      related_task_id VARCHAR(36) NULL,
      is_completed BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
      log_date DATE NULL,
      weather VARCHAR(50) NULL,
      keywords VARCHAR(255) NULL,
      log_title VARCHAR(200) NULL,
      log_content TEXT NULL,
      is_archived BOOLEAN DEFAULT FALSE,
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
    )`,

    // MBTI记录表 - 存储用户性格测试结果和AI分析建议
    `CREATE TABLE IF NOT EXISTS mbti_records (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      mbti_type VARCHAR(4) NOT NULL,
      test_scores JSON NOT NULL COMMENT 'MBTI各维度得分详情',
      personality_traits JSON NOT NULL COMMENT '性格特质分析结果',
      ai_analysis JSON NOT NULL COMMENT 'AI智能分析结果',
      work_suggestions JSON NOT NULL COMMENT '工作建议和职业指导',
      improvement_advice JSON COMMENT '个人改进建议',
      personal_info JSON COMMENT '扩展个人信息（姓名、生日、地址等）',
      test_version VARCHAR(20) DEFAULT 'v1.0' COMMENT '测试版本',
      confidence_score DECIMAL(3,2) DEFAULT 0.00 COMMENT '测试可信度(0-1)',
      is_active BOOLEAN DEFAULT TRUE COMMENT '记录是否有效',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_id (user_id),
      INDEX idx_test_date (test_date),
      INDEX idx_mbti_type (mbti_type),
      INDEX idx_is_active (is_active),
      INDEX idx_user_test_date (user_id, test_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='MBTI测试记录表，存储用户性格测试结果和AI分析建议'`,

    // 词云分析表 - 存储用户日志的词云分析结果
    `CREATE TABLE IF NOT EXISTS wordcloud_analysis (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      analysis_date TIMESTAMP NOT NULL,
      keywords JSON NOT NULL COMMENT '关键词列表',
      word_frequencies JSON NOT NULL COMMENT '词频统计',
      description VARCHAR(500) COMMENT '分析描述',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_id (user_id),
      INDEX idx_analysis_date (analysis_date),
      INDEX idx_user_analysis_date (user_id, analysis_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='词云分析表，存储用户日志的词云分析结果'`,

    // 性格分析表 - 存储AI性格分析结果
    `CREATE TABLE IF NOT EXISTS personality_analysis (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      analysis_date TIMESTAMP NOT NULL,
      personality_traits JSON NOT NULL COMMENT '性格特质分析结果',
      mbti_type VARCHAR(4) NOT NULL COMMENT 'MBTI类型',
      work_suggestions JSON NOT NULL COMMENT '工作建议',
      personality_chart JSON NOT NULL COMMENT '性格图表数据',
      ai_analysis_text TEXT COMMENT 'DeepSeek API返回的原始分析文本',
      description VARCHAR(500) COMMENT '分析描述',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_id (user_id),
      INDEX idx_analysis_date (analysis_date),
      INDEX idx_mbti_type (mbti_type),
      INDEX idx_user_analysis_date (user_id, analysis_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='性格分析表，存储AI性格分析结果'`,

    `CREATE TABLE IF NOT EXISTS log_task_linkage (
      id INT AUTO_INCREMENT PRIMARY KEY,
      log_id VARCHAR(36) NOT NULL,
      task_id VARCHAR(36) NOT NULL,
      progress_percentage INT DEFAULT 0,
      task_status VARCHAR(50) DEFAULT 'in_progress',
      linkage_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY log_task_unique (log_id, task_id),
      FOREIGN KEY (log_id) REFERENCES personal_logs(id) ON DELETE CASCADE,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )`
  ];

  for (const table of tables) {
    await db.execute(table);
  }
  // 为已存在数据库补齐缺失字段
  await ensureSchemaCompatibility();

  // 插入示例数据
  await insertSampleData();
}

// 兼容性：为已存在的数据库补齐 personal_logs 与 log_task_linkage 所需字段
async function ensureSchemaCompatibility() {
  try {
    // 兼容性调整（如需 MySQL 8+ 兼容，ALTER ... IF NOT EXISTS，保留原 personal_logs 相关字段）
    
    // tasks表 updated_at 字段检查
    try { await db.execute("ALTER TABLE tasks ADD COLUMN updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP"); } catch(e){}

    // 所有 ALTER TABLE 语句外包裹 try...catch，兼容老MySQL
    // 注意：MySQL 8.0+ 支持 IF NOT EXISTS，老版本会抛出错误但被catch
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN log_id VARCHAR(36) UNIQUE"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN title VARCHAR(200) NOT NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN content TEXT"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN log_date DATE NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN weather VARCHAR(50) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN keywords VARCHAR(255) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN log_title VARCHAR(200) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN log_content TEXT NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN category VARCHAR(50) NOT NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN quadrant ENUM('important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent') DEFAULT 'important_not_urgent'"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN is_archived BOOLEAN DEFAULT FALSE"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN related_task_id VARCHAR(36) NULL"); } catch(e){}
    // 设置默认值（兼容已有库）
    try { await db.execute("ALTER TABLE personal_logs MODIFY title VARCHAR(200) NOT NULL DEFAULT '个人日志'"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs MODIFY category VARCHAR(50) NOT NULL DEFAULT 'work'"); } catch(e){}
    // tasks表邀约相关字段
    try { await db.execute("ALTER TABLE tasks ADD COLUMN is_request BOOLEAN DEFAULT FALSE"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN request_type VARCHAR(50) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN request_response VARCHAR(20) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN related_task_id VARCHAR(36) NULL"); } catch(e){}
    // 索引、关联关系等原有包裹不变
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_personal_logs_user_id ON personal_logs(user_id)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_personal_logs_log_date ON personal_logs(log_date)"); } catch (_) {}
    await db.execute(`CREATE TABLE IF NOT EXISTS log_task_linkage (
      id INT AUTO_INCREMENT PRIMARY KEY,
      log_id VARCHAR(36) NOT NULL,
      task_id VARCHAR(36) NOT NULL,
      progress_percentage INT DEFAULT 0,
      task_status VARCHAR(50) DEFAULT 'in_progress',
      linkage_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY log_task_unique (log_id, task_id),
      FOREIGN KEY (log_id) REFERENCES personal_logs(id) ON DELETE CASCADE,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )`);
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_log_task_linkage_log_id ON log_task_linkage(log_id)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_log_task_linkage_task_id ON log_task_linkage(task_id)"); } catch (_) {}
  } catch (e) {
    console.error('ensureSchemaCompatibility 执行失败:', e.message);
  }
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

/**
 * [新] 异步同步任务状态和进度。
 * 必须在 MySQL 事务中调用。
 * @param {mysql.PoolConnection} connection - 事务连接对象
 * @param {object} taskUpdateData - 包含 { taskId, progress_percentage, task_status } 的对象
 */
async function syncTaskStatusFromLog(connection, taskUpdateData) {
  // 您的 API 路由已使用 task_id, progress_percentage, task_status, 我们将保持一致
  const { task_id, progress_percentage, task_status } = taskUpdateData;

  if (!task_id) {
    console.warn('syncTaskStatusFromLog: Skipping update, task_id is missing.');
    return;
  }

  try {
    // 1. 获取当前任务状态 (FOR UPDATE 用于锁定行，防止事务冲突)
    const [taskRows] = await connection.execute('SELECT progress_percentage, status FROM tasks WHERE id = ? FOR UPDATE', [task_id]);
    if (taskRows.length === 0) {
      console.warn(`Task with ID ${task_id} not found during sync.`);
      return; // 任务不存在
    }

    const currentTask = taskRows[0];
    let finalProgress = currentTask.progress_percentage;
    let finalStatus = currentTask.status;
    let needsUpdate = false;
    const now = new Date();

    // 2. 检查日志中是否有进度更新
    if (progress_percentage !== null && progress_percentage !== undefined) {
      finalProgress = progress_percentage;
      needsUpdate = true;
    }

    // 3. 检查日志中是否有状态更新
    if (task_status !== null && task_status !== undefined) {
      // 确保状态值在 'tasks' 表的 ENUM 范围内
      const validStatuses = ['pending', 'in_progress', 'completed', 'cancelled'];
      finalStatus = validStatuses.includes(task_status) ? task_status : currentTask.status;
      needsUpdate = true;
    }

    // 4. 联动逻辑
    if (finalStatus === 'completed' && finalProgress !== 100) {
      finalProgress = 100;
      needsUpdate = true;
    }
    if (finalProgress === 100 && finalStatus !== 'completed') {
      finalStatus = 'completed';
      needsUpdate = true;
    }

    // 5. 如果有任何更改，则更新 tasks 表
    if (needsUpdate && (finalProgress !== currentTask.progress_percentage || finalStatus !== currentTask.status)) {
      // 检查 updated_at 字段是否存在，如果不存在则不更新该字段
      try {
        const updateSql = `UPDATE tasks SET progress_percentage = ?, status = ?, updated_at = ? WHERE id = ?`;
        await connection.execute(updateSql, [finalProgress, finalStatus, now, task_id]);
      } catch (error) {
        // 如果 updated_at 字段不存在，尝试不更新该字段
        if (error.code === 'ER_BAD_FIELD_ERROR' && error.message.includes('updated_at')) {
          const updateSqlWithoutUpdatedAt = `UPDATE tasks SET progress_percentage = ?, status = ? WHERE id = ?`;
          await connection.execute(updateSqlWithoutUpdatedAt, [finalProgress, finalStatus, task_id]);
        } else {
          throw error; // 重新抛出其他错误
        }
      }
      console.log(`Synced task ${task_id}: Progress=${finalProgress}, Status=${finalStatus}`);
    }
  } catch (error) {
    console.error(`Error syncing task ${task_id}:`, error);
    // 抛出错误以确保事务回滚
    throw new Error(`Failed to sync task ${task_id}: ${error.message}`);
  }
}

// (authenticateToken 函数应该在下面...)
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
             u.department_id, d.name as department_name, u.parent_id, p.name as parent_name
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

// 批量更新重要事项选择状态（用于编辑十大事项）
app.put('/api/company-important-items/batch-select', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { selectedIds } = req.body;
    
    if (!Array.isArray(selectedIds)) {
      return res.status(400).json({ error: 'selectedIds 必须是数组' });
    }

    // 开始事务
    await db.query('START TRANSACTION');
    
    try {
      // 首先将所有事项设为未选择
      await db.execute(
        'UPDATE company_important_items SET is_selected = FALSE, updated_by = ?',
        [req.user.id]
      );
      
      // 然后设置选中的事项
      if (selectedIds.length > 0) {
        const placeholders = selectedIds.map(() => '?').join(',');
        await db.execute(
          `UPDATE company_important_items SET is_selected = TRUE, updated_by = ? WHERE id IN (${placeholders})`,
          [req.user.id, ...selectedIds]
        );
      }
      
      // 提交事务
      await db.query('COMMIT');
      
      res.json({ 
        message: '批量更新成功', 
        selectedCount: selectedIds.length,
        totalCount: selectedIds.length
      });
    } catch (error) {
      // 回滚事务
      await db.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('批量更新重要事项选择状态错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新重要事项（编辑内容）
app.put('/api/company-important-items/:id', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, priority, status, deadline } = req.body;

    await db.execute(
      'UPDATE company_important_items SET title = ?, description = ?, priority = ?, status = ?, deadline = ?, updated_by = ? WHERE id = ?',
      [title, description, priority, status, deadline, req.user.id, id]
    );

    res.json({ message: '更新成功' });
  } catch (error) {
    console.error('更新重要事项错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除重要事项
app.delete('/api/company-important-items/:id', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;

    await db.execute(
      'DELETE FROM company_important_items WHERE id = ?',
      [id]
    );

    res.json({ message: '删除成功' });
  } catch (error) {
    console.error('删除重要事项错误:', error);
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

    // 邀约任务权限过滤：只有创建者（发送邀约的人）和被邀约人（接收人）可以看到
    // 普通任务：所有人都可以看到
    query += ` AND (
      t.is_request = 0
      OR (t.is_request = 1 AND (t.created_by = ? OR t.assignee_id = ?))
    )`;
    params.push(req.user.id, req.user.id);

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

    // 父任务ID过滤（用于获取子任务）
    if (req.query.parent_task_id) {
      query += ' AND t.parent_task_id = ?';
      params.push(req.query.parent_task_id);
    }

    // 排序逻辑：未处理的邀约任务排在最上面，按ddl排序；已处理的邀约任务和普通任务按创建时间排序
    query += ` ORDER BY
      CASE WHEN t.is_request = 1 AND (t.request_response IS NULL OR t.request_response = '') THEN 0 ELSE 1 END,
      CASE WHEN t.is_request = 1 AND (t.request_response IS NULL OR t.request_response = '') THEN t.deadline ELSE NULL END ASC,
      t.created_at DESC`;

    const [rows] = await db.execute(query, params);

    // 处理时区 - 将所有时间字段转换为北京时间格式
    const tasksWithTimezone = rows.map(task => ({
      ...task,
      start_time: formatDateTimeForBeijing(task.start_time),
      end_time: formatDateTimeForBeijing(task.end_time),
      deadline: formatDateTimeForBeijing(task.deadline),
      created_at: formatDateTimeForBeijing(task.created_at),
      updated_at: formatDateTimeForBeijing(task.updated_at)
    }));

    res.json(tasksWithTimezone);
  } catch (error) {
    console.error('获取任务列表错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取单个任务详情
app.get('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    let query = `
      SELECT t.*, d.name as department_name, u.name as created_by_name
      FROM tasks t
      LEFT JOIN departments d ON t.department_id = d.id
      LEFT JOIN users u ON t.created_by = u.id
      WHERE t.id = ?
    `;
    let params = [id];

    // 所有人可以查看所有任务（不限制可见范围）
    const [rows] = await db.execute(query, params);

    if (rows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = rows[0];

    // 邀约任务权限检查：只有创建者（发送邀约的人）和被邀约人（接收人）可以看到
    if (task.is_request) {
      const isCreator = task.created_by === req.user.id;
      const isAssignee = task.assignee_id === req.user.id;

      if (!isCreator && !isAssignee) {
        return res.status(403).json({ error: '无权查看此邀约任务' });
      }
    }

    res.json(task);
    // 处理时区 - 将所有时间字段转换为北京时间格式
    const taskWithTimezone = {
      ...rows[0],
      start_time: formatDateTimeForBeijing(rows[0].start_time),
      end_time: formatDateTimeForBeijing(rows[0].end_time),
      deadline: formatDateTimeForBeijing(rows[0].deadline),
      created_at: formatDateTimeForBeijing(rows[0].created_at),
      updated_at: formatDateTimeForBeijing(rows[0].updated_at)
    };

    res.json(taskWithTimezone);
  } catch (error) {
    console.error('获取任务详情错误:', error);
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

    // 参数验证
    if (!title || !title.trim()) {
      return res.status(400).json({ error: '任务名称不能为空' });
    }
    if (!assignee_id) {
      return res.status(400).json({ error: '必须指定责任人' });
    }
    // department_id 可以为空，将从被分配人信息中获取

    // 权限检查
    if (req.user.role === 'employee') {
      return res.status(403).json({ error: '员工无权创建任务' });
    }

    // 获取被分配人信息（包括部门ID）
    const [assigneeRows] = await db.execute(
      'SELECT name, department_id FROM users WHERE id = ?',
      [assignee_id]
    );

    if (assigneeRows.length === 0) {
      return res.status(400).json({ error: '被分配人不存在' });
    }

    const assignee_name = assigneeRows[0].name;
    // 如果前端没有传递 department_id，从用户信息中获取
    const final_department_id = department_id || assigneeRows[0].department_id;

    if (!final_department_id) {
      return res.status(400).json({ error: '无法确定任务部门，请确保用户有部门信息' });
    }

    const taskId = require('crypto').randomUUID();

    // 将 undefined 和空字符串转换为 null，确保数据库参数有效
    const cleanValue = (value) => {
      if (value === undefined || value === '') return null;
      return value;
    };

    // 获取进度百分比和状态（如果前端传递了）
    const progress_percentage = req.body.progress_percentage !== undefined ? req.body.progress_percentage : 0;
    const status = req.body.status || 'pending';

    await db.execute(
      `INSERT INTO tasks (
        id, title, description, parent_task_id, assignee_id, assignee_name, 
        department_id, priority, deadline, created_by, start_time, end_time, 
        location, is_all_day, progress_percentage, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        taskId,
        title,
        cleanValue(description),
        cleanValue(parent_task_id),
        assignee_id,
        assignee_name,
        final_department_id,
        priority || 'p1',
        cleanValue(deadline),
        req.user.id,
        cleanValue(start_time),
        cleanValue(end_time),
        cleanValue(location),
        is_all_day || false,
        progress_percentage,
        status
      ]
    );

    // 创建任务分配通知
    await createNotification(taskId, req.user.id, assignee_id, 'task_assigned', `您收到了新任务：${title}`);

    // 如果是子任务，需要更新父任务进度
    if (cleanValue(parent_task_id)) {
      await updateParentTaskProgress(parent_task_id);
    }

    res.status(201).json({ message: '任务创建成功', id: taskId });
  } catch (error) {
    console.error('创建任务错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

  // 更新任务状态（进度）
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

    // 权限检查：允许 1) 被分配人 2) 创建者 3) 与创建者同级或下级且同部门 的用户 更新进度
    const [creatorRows] = await db.execute(
      'SELECT id, role, department_id FROM users WHERE id = ?',
      [task.created_by]
    );

    const creator = creatorRows.length > 0 ? creatorRows[0] : null;

    function roleRank(role) {
      switch (role) {
        case 'founder':
          return 5;
        case 'admin':
          return 5;
        case 'department_head':
          return 4;
        case 'team_leader':
          return 3;
        case 'employee':
        default:
          return 1;
      }
    }

    const isAssignee = task.assignee_id === req.user.id;
    const isCreator = task.created_by === req.user.id;
    const isAdminLike = req.user.role === 'admin' || req.user.role === 'founder';
    const sameDept = creator && creator.department_id === req.user.department_id;
    const sameOrLowerThanCreator = creator && roleRank(req.user.role) <= roleRank(creator.role);

    if (!(isAssignee || isCreator || isAdminLike || (sameDept && sameOrLowerThanCreator))) {
      return res.status(403).json({ error: '无权更新此任务进度' });
    }

    const updateData = { status };
    if (progress_percentage !== undefined) updateData.progress_percentage = Number(progress_percentage);
    if (special_notes !== undefined) updateData.special_notes = special_notes;
    if (status === 'completed') updateData.completed_at = new Date();

    let finalProgress = Number.isFinite(updateData.progress_percentage)
      ? Math.max(0, Math.min(100, updateData.progress_percentage))
      : (typeof task.progress_percentage === 'number' ? task.progress_percentage : 0);
    // 若状态为完成且未显式传进度，则强制置为100%
    if (status === 'completed' && !Number.isFinite(updateData.progress_percentage)) {
      finalProgress = 100;
    }
    const finalNotes = updateData.special_notes ?? null;
    const finalCompletedAt = updateData.completed_at ?? null;

    await db.execute(
      `UPDATE tasks SET 
       status = ?, progress_percentage = ?, special_notes = ?, completed_at = ?
       WHERE id = ?`,
      [status, finalProgress, finalNotes, finalCompletedAt, id]
    );

    // 如果这个任务有父任务，更新父任务的进度
    if (task.parent_task_id) {
      await updateParentTaskProgress(task.parent_task_id);

      // 创建进度更新通知
      const [parentTaskRows] = await db.execute('SELECT created_by, title FROM tasks WHERE id = ?', [task.parent_task_id]);
      if (parentTaskRows.length > 0) {
        const parentTask = parentTaskRows[0];
        await createNotification(id, req.user.id, parentTask.created_by, 'task_progress_update', `任务进度更新：${task.title}`);
      }
    }

    res.json({ message: '任务状态更新成功' });
  } catch (error) {
    console.error('更新任务状态错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

  // 更新任务（完整更新，仅允许被分配人编辑）
  app.put('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const {
      title,
      description,
      priority,
      status,
      assignee_id,
      department_id,
      progress_percentage,
      start_time,
      end_time,
      deadline,
      location,
      is_all_day,
      parent_task_id
    } = req.body;

    // 获取任务信息
    const [taskRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    if (taskRows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = taskRows[0];

    // 权限检查：
    // - admin 可编辑所有任务
    // - 其他角色：允许编辑 1) 自己的任务 2) 分配给平级或下级(同部门)的任务
    if (req.user.role !== 'admin') {
      if (task.assignee_id !== req.user.id) {
        // 检查被分配人的角色与部门
        const [assigneeRows] = await db.execute('SELECT role, department_id FROM users WHERE id = ?', [task.assignee_id]);
        if (assigneeRows.length === 0) {
          return res.status(400).json({ error: '被分配人不存在' });
        }
        const assignee = assigneeRows[0];

        function roleRank(role) {
          switch (role) {
            case 'founder':
            case 'admin':
              return 5;
            case 'department_head':
              return 4;
            case 'team_leader':
              return 3;
            case 'employee':
            default:
              return 1;
          }
        }

        const sameDept = assignee.department_id === req.user.department_id;
        const canEditSubOrPeer = sameDept && roleRank(req.user.role) >= roleRank(assignee.role);
        if (!canEditSubOrPeer) {
          return res.status(403).json({ error: '无权更新此任务' });
        }
      }
    }

    // 辅助函数：清理值（将undefined和空字符串转为null）
    const cleanValue = (val) => {
      if (val === undefined || val === '' || val === null) return null;
      return val;
    };

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

    if (assignee_id !== undefined) {
      updates.push('assignee_id = ?');
      values.push(assignee_id);
    }

    if (department_id !== undefined) {
      updates.push('department_id = ?');
      values.push(cleanValue(department_id));
    }

    if (progress_percentage !== undefined) {
      updates.push('progress_percentage = ?');
      values.push(progress_percentage);
    } else if (status === 'completed') {
      // 状态改为完成且未显式给进度，则强制置为100
      updates.push('progress_percentage = ?');
      values.push(100);
    }

    if (start_time !== undefined) {
      updates.push('start_time = ?');
      values.push(cleanValue(start_time));
    }

    if (end_time !== undefined) {
      updates.push('end_time = ?');
      values.push(cleanValue(end_time));
    }

    if (deadline !== undefined) {
      updates.push('deadline = ?');
      values.push(cleanValue(deadline));
    }

    if (location !== undefined) {
      updates.push('location = ?');
      values.push(cleanValue(location));
    }

    if (is_all_day !== undefined) {
      updates.push('is_all_day = ?');
      values.push(is_all_day);
    }

    if (parent_task_id !== undefined) {
      updates.push('parent_task_id = ?');
      values.push(cleanValue(parent_task_id));
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '没有要更新的字段' });
    }

    values.push(id);
    
    await db.execute(
      `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    // 如果更新了progress_percentage或status，且该任务有父任务，更新父任务进度
    if ((progress_percentage !== undefined || status !== undefined) && task.parent_task_id) {
      await updateParentTaskProgress(task.parent_task_id);
    }

    // 如果更新了父任务ID或创建了子任务，更新父任务进度
    if (parent_task_id !== undefined && cleanValue(parent_task_id)) {
      await updateParentTaskProgress(parent_task_id);
    }

    // 返回更新后的任务信息
    const [updatedRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    res.json(updatedRows.length > 0 ? updatedRows[0] : { message: '任务更新成功' });
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

    // 权限检查：
    // - admin 可删除所有任务
    // - 其他角色：只能删除自己创建的任务、分配给自己的任务，或分配给下属的任务
    if (req.user.role !== 'admin') {
      // 1. 自己创建的任务，可以删除
      const isCreator = task.created_by === req.user.id;

      // 2. 分配给自己的任务，可以删除
      const isAssignee = task.assignee_id === req.user.id;

      // 3. 检查任务的责任人是否是自己的下属
      let isSubordinate = false;
      if (!isCreator && !isAssignee && task.assignee_id) {
        try {
          const [assigneeRows] = await db.execute('SELECT role, department_id, parent_id FROM users WHERE id = ?', [task.assignee_id]);
          if (assigneeRows.length === 0) {
            // 被分配人不存在，不允许删除
            return res.status(403).json({ error: '无权删除此任务，被分配人不存在' });
          }
          const assignee = assigneeRows[0];

          // 判断是否为下属：通过parent_id直接关系或递归查找，或同部门且角色等级更低
          function roleRank(role) {
            switch (role) {
              case 'founder':
              case 'admin':
                return 5;
              case 'department_head':
                return 4;
              case 'team_leader':
                return 3;
              case 'employee':
              default:
                return 1;
            }
          }

          // 直接下属（parent_id指向自己）
          const isDirectSubordinate = assignee.parent_id === req.user.id;

          // 同部门且角色等级更低（间接下属）
          const sameDept = assignee.department_id && req.user.department_id && assignee.department_id === req.user.department_id;
          const isLowerRank = sameDept && roleRank(req.user.role) > roleRank(assignee.role);

          // 递归查找：检查assignee的parent_id链中是否有req.user.id
          let foundInChain = false;
          if (assignee.parent_id) {
            let currentParentId = assignee.parent_id;
            const checkedIds = new Set([task.assignee_id]);

            while (currentParentId && !foundInChain && checkedIds.size < 100) {
              if (currentParentId === req.user.id) {
                foundInChain = true;
                break;
              }
              if (checkedIds.has(currentParentId)) {
                // 检测到循环，停止查找
                break;
              }
              checkedIds.add(currentParentId);

              try {
                const [parentRows] = await db.execute('SELECT parent_id FROM users WHERE id = ?', [currentParentId]);
                if (parentRows.length > 0 && parentRows[0].parent_id) {
                  currentParentId = parentRows[0].parent_id;
                } else {
                  break;
                }
              } catch (err) {
                console.error('递归查找父级用户时出错:', err);
                break;
              }
            }
          }

          isSubordinate = isDirectSubordinate || isLowerRank || foundInChain;
        } catch (err) {
          console.error('检查下属关系时出错:', err);
          // 如果检查下属关系时出错，不允许删除
          return res.status(403).json({ error: '无权删除此任务，权限检查失败' });
        }
      }

      // 如果都不满足，则无权删除
      if (!isCreator && !isAssignee && !isSubordinate) {
        return res.status(403).json({ error: '无权删除此任务，只能删除自己创建的任务、分配给自己的任务，或分配给下属的任务' });
      }
    }

    // 删除任务前，先处理关联数据

    // 1. 处理子任务：将子任务的parent_task_id设置为NULL，保留子任务
    try {
      await db.execute('UPDATE tasks SET parent_task_id = NULL WHERE parent_task_id = ?', [id]);
    } catch (err) {
      console.error('更新子任务parent_task_id时出错:', err);
      // 如果更新失败，尝试删除子任务
      try {
        await db.execute('DELETE FROM tasks WHERE parent_task_id = ?', [id]);
      } catch (deleteErr) {
        console.error('删除子任务时出错:', deleteErr);
        // 如果都失败，返回错误
        return res.status(500).json({ error: '删除任务失败，无法处理子任务' });
      }
    }

    // 2. 删除任务相关的通知
    try {
      await db.execute('DELETE FROM task_notifications WHERE task_id = ?', [id]);
    } catch (err) {
      console.error('删除任务通知时出错:', err);
      // 通知删除失败不影响任务删除，继续执行
    }

    // 3. 删除任务
    await db.execute('DELETE FROM tasks WHERE id = ?', [id]);

    res.json({ message: '任务删除成功' });
  } catch (error) {
    console.error('删除任务错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 创建向上邀约请求
app.post('/api/tasks/request', authenticateToken, async (req, res) => {
  try {
    const {
      request_type,
      assignee_id,
      description,
      deadline,
      related_task_id
    } = req.body;

    // 允许的请求类型
    const allowedRequestTypes = [
      '修改任务',
      '删除任务',
      '重新安排任务',
      '请假',
      '请来办公室',
      '其他'
    ];

    // 参数验证
    if (!request_type || !request_type.trim()) {
      return res.status(400).json({ error: '请求类型不能为空' });
    }

    // 验证请求类型是否在允许列表中
    if (!allowedRequestTypes.includes(request_type.trim())) {
      return res.status(400).json({
        error: `请求类型无效。允许的类型：${allowedRequestTypes.join('、')}`
      });
    }

    if (!assignee_id) {
      return res.status(400).json({ error: '必须指定接收人' });
    }

    if (!description || !description.trim()) {
      return res.status(400).json({ error: '请求详情不能为空' });
    }

    // 对于需要关联任务的请求类型，验证是否提供了关联任务ID
    const requiresRelatedTask = ['修改任务', '删除任务', '重新安排任务'];
    if (requiresRelatedTask.includes(request_type.trim()) && !related_task_id) {
      return res.status(400).json({
        error: `${request_type}类型的邀约请求必须关联一个任务`
      });
    }

    // 如果提供了关联任务ID，验证任务是否存在
    let relatedTaskTitle = null;
    if (related_task_id) {
      const [taskRows] = await db.execute(
        'SELECT id, title, assignee_id, is_request FROM tasks WHERE id = ?',
        [related_task_id]
      );

      if (taskRows.length === 0) {
        return res.status(400).json({ error: '关联的任务不存在' });
      }

      // 验证关联的任务不是邀约任务
      if (taskRows[0].is_request) {
        return res.status(400).json({ error: '不能关联邀约任务' });
      }

      relatedTaskTitle = taskRows[0].title;
    }

    // 获取接收人信息
    const [assigneeRows] = await db.execute(
      'SELECT name, department_id FROM users WHERE id = ?',
      [assignee_id]
    );

    if (assigneeRows.length === 0) {
      return res.status(400).json({ error: '接收人不存在' });
    }

    const assignee_name = assigneeRows[0].name;
    const department_id = assigneeRows[0].department_id;

    if (!department_id) {
      return res.status(400).json({ error: '无法确定接收人部门，请确保用户有部门信息' });
    }

    // 验证不能向自己发送邀约
    if (assignee_id === req.user.id) {
      return res.status(400).json({ error: '不能向自己发送邀约请求' });
    }

    // 生成任务标题
    const taskTitle = `邀约请求：${request_type}`;

    const taskId = require('crypto').randomUUID();

    // 将 undefined 和空字符串转换为 null
    const cleanValue = (value) => {
      if (value === undefined || value === '') return null;
      return value;
    };

    // 格式化deadline
    let formattedDeadline = null;
    if (deadline) {
      try {
        // 支持多种日期格式
        const deadlineDate = new Date(deadline);
        if (isNaN(deadlineDate.getTime())) {
          return res.status(400).json({ error: '期望回复时间格式无效' });
        }
        formattedDeadline = deadlineDate.toISOString().slice(0, 19).replace('T', ' ');
      } catch (e) {
        return res.status(400).json({ error: '期望回复时间格式无效' });
      }
    }

    // 计算默认结束时间（如果没有deadline，默认3天后）
    const defaultEndTime = formattedDeadline
      ? new Date(formattedDeadline)
      : new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

    // 创建邀约任务：状态为pending（待处理），进度为0%
    await db.execute(
      `INSERT INTO tasks (
        id, title, description, assignee_id, assignee_name,
        department_id, priority, deadline, created_by,
        start_time, end_time, is_all_day, progress_percentage, status,
        is_request, request_type, related_task_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        taskId,
        taskTitle,
        description.trim(),
        assignee_id,
        assignee_name,
        department_id,
        'p0', // 邀约请求优先级为p0（重要且紧急）
        formattedDeadline,
        req.user.id,
        new Date(),
        defaultEndTime,
        false,
        0, // 进度为0%
        'pending', // 状态为pending（待处理）
        true, // 标记为邀约任务
        request_type.trim(),
        cleanValue(related_task_id)
      ]
    );

    // 创建通知
    const notificationMessage = related_task_id && relatedTaskTitle
      ? `您收到了邀约请求：${request_type}（关联任务：${relatedTaskTitle}）`
      : `您收到了邀约请求：${request_type}`;
    await createNotification(taskId, req.user.id, assignee_id, 'task_assigned', notificationMessage);

    res.status(201).json({
      message: '邀约请求创建成功',
      id: taskId,
      task: {
        id: taskId,
        title: taskTitle,
        request_type: request_type.trim(),
        status: 'pending'
      }
    });
  } catch (error) {
    console.error('创建邀约请求错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 处理邀约请求（批准/拒绝）
app.put('/api/tasks/:id/request-response', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { action, notes } = req.body; // action: 'approve' 或 'reject'

    // 参数验证
    if (!action || !['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'action必须是approve或reject' });
    }

    // 获取任务信息
    const [taskRows] = await db.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [id]
    );

    if (taskRows.length === 0) {
      return res.status(404).json({ error: '任务不存在' });
    }

    const task = taskRows[0];

    // 检查是否为邀约任务
    if (!task.is_request) {
      return res.status(400).json({ error: '此任务不是邀约任务' });
    }

    // 权限检查：只有被邀约人可以处理
    if (task.assignee_id !== req.user.id) {
      return res.status(403).json({ error: '只有被邀约人可以处理此邀约请求' });
    }

    // 检查是否已处理
    if (task.request_response) {
      return res.status(400).json({ error: '此邀约请求已被处理' });
    }

    // 更新任务状态：处理后任务状态变成已完成，进度变成100%
    const requestResponse = action === 'approve' ? 'approve' : 'reject';
    const newStatus = 'completed'; // 处理后状态统一为已完成
    const specialNotes = notes ? notes.trim() : null;
    const progressPercentage = 100; // 进度统一为100%

    await db.execute(
      `UPDATE tasks SET
       request_response = ?, status = ?, progress_percentage = ?, special_notes = ?, completed_at = ?
       WHERE id = ?`,
      [requestResponse, newStatus, progressPercentage, specialNotes, new Date(), id]
    );

    // 创建通知给创建者（发送邀约的人）
    const responseText = action === 'approve' ? '批准' : '拒绝';
    await createNotification(id, req.user.id, task.created_by, 'task_progress_update',
      `您的邀约请求"${task.title}"已被${responseText}${specialNotes ? '，备注：' + specialNotes : ''}`);

    res.json({
      message: `邀约请求已${responseText}`,
      task: {
        id: id,
        status: newStatus,
        progress_percentage: progressPercentage,
        request_response: requestResponse
      }
    });
  } catch (error) {
    console.error('处理邀约请求错误:', error);
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
  // 兼容旧形态：{ log, linkages }；也支持直接平铺字段
  const userId = req.user.id;
  const payload = req.body && req.body.log ? req.body.log : req.body;
  const linkages = Array.isArray(req.body && req.body.linkages) ? req.body.linkages : (payload.linkages || []);

  // 校验必填字段
  if (!payload || !payload.title || !payload.category) {
    return res.status(400).json({ error: '缺少必填字段 (title, category)' });
  }

  const id = require('crypto').randomUUID();
  const businessLogId = require('crypto').randomUUID(); // 存入 personal_logs.log_id

  // 归一化字段
  function formatDateOnly(dateLike) {
    if (!dateLike) return null;
    const d = new Date(dateLike);
    if (Number.isNaN(d.getTime())) return null;
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
  const title = payload.title;
  const content = payload.content || null;
  const is_completed = Boolean(payload.is_completed);
  const created_at = payload.created_at ? new Date(payload.created_at) : (payload.log_date ? new Date(payload.log_date) : new Date());
  const log_date = payload.log_date ? formatDateOnly(payload.log_date) : formatDateOnly(created_at);
  const weather = payload.weather || null;
  const keywords = Array.isArray(payload.keywords) ? payload.keywords.join(',') : (payload.keywords || null);
  const log_title = payload.log_title || null;
  const log_content = payload.log_content || null;
  const category = payload.category;
  const quadrant = payload.quadrant || 'important_not_urgent';
  const is_archived = Boolean(payload.is_archived);
  const related_task_id = payload.related_task_id || null;

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();

    // 1) 插入 personal_logs
    const insertSql = `
      INSERT INTO personal_logs (
        id, log_id, user_id, title, content, is_completed, created_at, log_date, weather, keywords,
        log_title, log_content, category, quadrant, is_archived, related_task_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await connection.execute(insertSql, [
      id, businessLogId, userId, title, content, is_completed, created_at, log_date, weather, keywords,
      log_title, log_content, category, quadrant, is_archived, related_task_id
    ]);

    // 2) 插入任务关联并同步（可选）
    if (Array.isArray(linkages) && linkages.length > 0) {
      const insertLinkSql = `
        INSERT INTO log_task_linkage (log_id, task_id, progress_percentage, task_status, linkage_time)
        VALUES (?, ?, ?, ?, ?)
      `;
      for (const update of linkages) {
        if (update && update.task_id) {
          const taskUpdateData = {
            task_id: update.task_id,
            progress_percentage: update.progress_percentage || 0,
            task_status: update.task_status || 'in_progress'
          };
          await connection.execute(insertLinkSql, [
            id,
            taskUpdateData.task_id,
            taskUpdateData.progress_percentage,
            taskUpdateData.task_status,
            created_at
          ]);
          await syncTaskStatusFromLog(connection, taskUpdateData);
        }
      }
    }

    await connection.commit();

    // 3) 查询并返回
    const [rows] = await connection.execute('SELECT * FROM personal_logs WHERE id = ?', [id]);
    const [links] = await connection.execute(
      `SELECT l.task_id, t.title as task_name, l.progress_percentage, l.task_status
       FROM log_task_linkage l LEFT JOIN tasks t ON l.task_id = t.id
       WHERE l.log_id = ?`,
      [id]
    );

    const taskUpdates = links.map(link => ({
      taskId: link.task_id,
      taskName: link.task_name,
      progress_percentage: link.progress_percentage,
      task_status: link.task_status
    }));

    return res.status(201).json({ ...rows[0], taskUpdates });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('创建个人日志错误:', error);
    return res.status(500).json({ error: '服务器内部错误', details: error.message });
  } finally {
    if (connection) connection.release();
  }
});

// [新] 获取个人日志 (Read)
app.get('/api/personal-logs', authenticateToken, async (req, res) => {
  try {
    const [logs] = await db.execute(
      `SELECT * FROM personal_logs WHERE user_id = ? ORDER BY created_at DESC`,
      [req.user.id]
    );

    // 并行获取所有日志的任务关联
    const result = await Promise.all(logs.map(async (log) => {
      const [links] = await db.execute(
        `SELECT l.task_id, t.title as task_name, l.progress_percentage, l.task_status
         FROM log_task_linkage l
         LEFT JOIN tasks t ON l.task_id = t.id
         WHERE l.log_id = ?`,
        [log.id]
      );

      return {
        ...log,
        // 转换为 camelCase 以匹配 Flutter 模型
        taskUpdates: links.map(link => ({
           taskId: link.task_id,
           taskName: link.task_name,
           progress_percentage: link.progress_percentage,
           task_status: link.task_status
        }))
      };
    }));

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

// [新] 更新个人日志 (Update)
app.put('/api/personal-logs/:id', authenticateToken, async (req, res) => {
  const { id: logId } = req.params;
  const userId = req.user.id;
  const payload = req.body && req.body.log ? req.body.log : req.body;
  const linkages = Array.isArray(req.body && req.body.linkages) ? req.body.linkages : (payload.linkages || []);

  if (!payload || !payload.title || !payload.category) {
    return res.status(400).json({ error: '缺少必填字段 (title, category)' });
  }

  function formatDateOnly(dateLike) {
    if (!dateLike) return null;
    const d = new Date(dateLike);
    if (Number.isNaN(d.getTime())) return null;
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
  const updatedCreatedAt = payload.created_at ? new Date(payload.created_at) : (payload.log_date ? new Date(payload.log_date) : null);
  const dbKeywords = Array.isArray(payload.keywords) ? payload.keywords.join(',') : (payload.keywords || null);

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();

    // 权限校验
    const [logRows] = await connection.execute('SELECT id FROM personal_logs WHERE id = ? AND user_id = ?', [logId, userId]);
    if (logRows.length === 0) {
      throw new Error('Log not found or access denied.');
    }

    // 更新主记录（仅设置提供的字段）
    const updates = [];
    const values = [];
    const fields = {
      title: payload.title,
      content: payload.content ?? null,
      category: payload.category,
      is_completed: payload.is_completed ?? false,
      log_date: payload.log_date ? formatDateOnly(payload.log_date) : null,
      weather: payload.weather ?? null,
      keywords: dbKeywords,
      log_title: payload.log_title ?? null,
      log_content: payload.log_content ?? null,
      quadrant: payload.quadrant || 'important_not_urgent',
      is_archived: payload.is_archived ? 1 : 0,
      related_task_id: payload.related_task_id ?? null
    };
    if (updatedCreatedAt) {
      fields.created_at = updatedCreatedAt;
    }
    for (const [k, v] of Object.entries(fields)) {
      updates.push(`${k} = ?`);
      values.push(v);
    }
    values.push(logId);
    await connection.execute(`UPDATE personal_logs SET ${updates.join(', ')}, updated_at = NOW() WHERE id = ?`, values);

    // 重新应用任务关联
    await connection.execute('DELETE FROM log_task_linkage WHERE log_id = ?', [logId]);
    if (Array.isArray(linkages) && linkages.length > 0) {
      const insertLinkSql = `INSERT INTO log_task_linkage (log_id, task_id, progress_percentage, task_status, linkage_time) VALUES (?, ?, ?, ?, ?)`;
      const linkageTime = updatedCreatedAt || new Date();
      for (const update of linkages) {
        if (update && update.task_id) {
          const taskUpdateData = {
            task_id: update.task_id,
            progress_percentage: update.progress_percentage || 0,
            task_status: update.task_status || 'in_progress'
          };
          await connection.execute(insertLinkSql, [logId, taskUpdateData.task_id, taskUpdateData.progress_percentage, taskUpdateData.task_status, linkageTime]);
          await syncTaskStatusFromLog(connection, taskUpdateData);
        }
      }
    }

    await connection.commit();

    const [newLogRows] = await connection.execute('SELECT * FROM personal_logs WHERE id = ?', [logId]);
    const [newLinks] = await connection.execute(
      `SELECT l.task_id, t.title as task_name, l.progress_percentage, l.task_status
       FROM log_task_linkage l LEFT JOIN tasks t ON l.task_id = t.id
       WHERE l.log_id = ?`,
      [logId]
    );
    const finalLinks = newLinks.map(link => ({
      taskId: link.task_id,
      taskName: link.task_name,
      progress_percentage: link.progress_percentage,
      task_status: link.task_status
    }));
    return res.status(200).json({ ...newLogRows[0], taskUpdates: finalLinks });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('更新个人日志错误:', error);
    return res.status(500).json({ error: '服务器内部错误', details: error.message });
  } finally {
    if (connection) connection.release();
  }
});

// [新] 删除个人日志 (Delete)
app.delete('/api/personal-logs/:id', authenticateToken, async (req, res) => {
  const { id: logId } = req.params;
  const userId = req.user.id;

  try {
    // 1. 验证权限
    const [logRows] = await db.execute('SELECT id FROM personal_logs WHERE id = ? AND user_id = ?', [logId, userId]);
    if (logRows.length === 0) {
      return res.status(404).json({ error: 'Log not found or access denied.' });
    }

    // 2. 删除 (ON DELETE CASCADE 会自动删除 log_task_linkage)
    await db.execute('DELETE FROM personal_logs WHERE id = ?', [logId]);

    res.status(204).send(); // 成功，无内容
  } catch (error) {
    console.error(`删除日志 ${logId} 错误:`, error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新父任务进度（基于子任务进度）
async function updateParentTaskProgress(parentTaskId) {
  try {
    // 获取所有子任务
    const [subtasks] = await db.execute(
      'SELECT id, progress_percentage, status FROM tasks WHERE parent_task_id = ?',
      [parentTaskId]
    );

    if (subtasks.length === 0) {
      // 没有子任务，不需要更新
      return;
    }

    // 计算子任务的平均进度
    let totalProgress = 0;
    let completedCount = 0;

    for (const subtask of subtasks) {
      totalProgress += subtask.progress_percentage || 0;
      if (subtask.status === 'completed') {
        completedCount++;
      }
    }

    const averageProgress = Math.round(totalProgress / subtasks.length);
    const allCompleted = completedCount === subtasks.length;

    // 更新父任务
    if (allCompleted) {
      // 所有子任务完成，父任务设为100%并标记为已完成
      await db.execute(
        `UPDATE tasks SET
         progress_percentage = 100,
         status = 'completed',
         completed_at = ?
         WHERE id = ?`,
        [new Date(), parentTaskId]
      );
    } else {
      // 更新父任务进度
      await db.execute(
        'UPDATE tasks SET progress_percentage = ? WHERE id = ?',
        [averageProgress, parentTaskId]
      );
    }

    // 如果父任务本身也有父任务，递归更新
    const [parentTask] = await db.execute(
      'SELECT parent_task_id FROM tasks WHERE id = ?',
      [parentTaskId]
    );

    if (parentTask.length > 0 && parentTask[0].parent_task_id) {
      await updateParentTaskProgress(parentTask[0].parent_task_id);
    }
  } catch (error) {
    console.error('更新父任务进度错误:', error);
  }
}

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

// ==================== MBTI记录管理API ====================

// AI分析生成函数
function generateAiAnalysis(mbtiType, testScores, personalityTraits) {
  const analysisTemplates = {
    'ENFP': {
      strengths: ['创新思维', '团队合作', '沟通能力', '适应性强'],
      weaknesses: ['细节处理', '时间管理', '决策果断性'],
      career_suitability: ['市场营销', '人力资源', '创意设计', '教育培训'],
      leadership_style: '民主型领导，善于激励团队',
      work_environment: '适合开放、灵活的工作环境',
      team_role: '团队协调者和创新推动者'
    },
    'INTJ': {
      strengths: ['战略思维', '独立性强', '逻辑分析', '执行力强'],
      weaknesses: ['人际交往', '情感表达', '灵活性'],
      career_suitability: ['战略规划', '技术研发', '管理咨询', '投资分析'],
      leadership_style: '愿景型领导，注重长远规划',
      work_environment: '适合独立、安静的工作环境',
      team_role: '战略规划者和技术专家'
    },
    'ISFJ': {
      strengths: ['责任心强', '细心周到', '团队合作', '稳定性'],
      weaknesses: ['创新思维', '决策果断性', '自我表达'],
      career_suitability: ['行政管理', '客户服务', '医疗护理', '教育培训'],
      leadership_style: '服务型领导，注重团队和谐',
      work_environment: '适合稳定、有序的工作环境',
      team_role: '支持者和协调者'
    },
    'ISTJ': {
      strengths: ['责任心强', '逻辑思维', '执行力强', '稳定性'],
      weaknesses: ['创新思维', '灵活性', '人际交往'],
      career_suitability: ['财务管理', '审计', '法律', '工程'],
      leadership_style: '任务型领导，注重效率和结果',
      work_environment: '适合安静、有序的工作环境',
      team_role: '执行者和监督者'
    },
    'ENFJ': {
      strengths: ['领导能力', '沟通技巧', '同理心', '组织能力'],
      weaknesses: ['批判思维', '独立性', '客观性'],
      career_suitability: ['人力资源管理', '教育培训', '心理咨询', '市场营销'],
      leadership_style: '变革型领导，善于激励和启发他人',
      work_environment: '适合开放、协作的工作环境',
      team_role: '领导者和激励者'
    },
    'INFP': {
      strengths: ['深度思考', '价值观驱动', '创造力', '同理心'],
      weaknesses: ['过度理想化', '避免冲突', '完美主义'],
      career_suitability: ['心理咨询', '写作编辑', '艺术设计', '社会服务'],
      leadership_style: '服务型领导，注重团队价值观和成长',
      work_environment: '适合安静、有意义的独立工作环境',
      team_role: '价值观守护者和创意贡献者'
    },
    'ESTJ': {
      strengths: ['组织能力', '执行力强', '责任心强', '领导力'],
      weaknesses: ['灵活性', '创新思维', '情感表达'],
      career_suitability: ['管理岗位', '行政管理', '项目管理', '运营管理'],
      leadership_style: '任务型领导，注重效率和结果',
      work_environment: '适合结构化、目标导向的工作环境',
      team_role: '组织者和执行者'
    }
  };

  const template = analysisTemplates[mbtiType] || analysisTemplates['ENFP'];

  return {
    strengths: template.strengths,
    weaknesses: template.weaknesses,
    career_suitability: template.career_suitability,
    leadership_style: template.leadership_style,
    work_environment: template.work_environment,
    team_role: template.team_role,
    development_focus: [
      '提高专注力',
      '加强时间规划',
      '培养决策能力'
    ],
    learning_suggestions: [
      '学习项目管理',
      '培养批判性思维',
      '提升执行力'
    ],
    career_advice: `基于您的${mbtiType}性格类型，建议考虑从事需要${template.strengths[0]}和${template.strengths[1]}的工作`
  };
}

function generateWorkSuggestions(mbtiType, aiAnalysis) {
  return {
    work_environment: aiAnalysis?.work_environment || '适合开放、灵活的工作环境',
    team_role: aiAnalysis?.team_role || '团队协调者和创新推动者',
    development_focus: aiAnalysis?.development_focus || ['提高专注力', '加强时间规划', '培养决策能力'],
    communication_style: '热情、富有感染力，善于激励他人',
    career_path: aiAnalysis?.career_suitability || ['市场营销', '人力资源', '创意设计', '教育培训'],
    leadership_style: aiAnalysis?.leadership_style || '民主型领导，善于激励团队'
  };
}

function generateImprovementAdvice(mbtiType, aiAnalysis) {
  return {
    improvement_areas: aiAnalysis?.weaknesses || ['细节处理', '时间管理', '决策果断性'],
    learning_suggestions: aiAnalysis?.learning_suggestions || ['学习项目管理', '培养批判性思维', '提升执行力'],
    career_advice: aiAnalysis?.career_advice || `基于您的${mbtiType}性格类型，建议考虑从事需要创新和人际交往的工作`,
    personal_development: '建议定期进行自我反思，持续提升个人能力',
    team_work: '在团队中发挥优势，同时注意弥补不足'
  };
}

// 创建MBTI记录
app.post('/api/mbti-records', authenticateToken, async (req, res) => {
  try {
    const {
      mbti_type,
      test_scores,
      personality_traits,
      personal_info,
      test_version = 'v1.0'
    } = req.body;

    // 验证必填字段
    if (!mbti_type || !test_scores || !personality_traits) {
      return res.status(400).json({ error: '缺少必填字段' });
    }

    // 确保所有参数都有默认值
    const safeTestVersion = test_version || 'v1.0';
    const safePersonalInfo = personal_info || null;

    // 验证MBTI类型格式
    if (!/^[EI][NS][TF][JP]$/.test(mbti_type)) {
      return res.status(400).json({ error: 'MBTI类型格式不正确，应为4个字符的组合，如ENFP' });
    }

    // 验证测试分数
    if (!test_scores || typeof test_scores !== 'object') {
      return res.status(400).json({ error: '测试分数数据格式不正确' });
    }

    // 验证所有8个维度的分数都存在且为数字
    const requiredScores = ['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P'];
    for (const scoreKey of requiredScores) {
      if (typeof test_scores[scoreKey] !== 'number' || test_scores[scoreKey] < 0) {
        return res.status(400).json({ error: `${scoreKey}维度分数必须是非负数` });
      }
    }

    // 验证性格特质
    if (!personality_traits || typeof personality_traits !== 'object') {
      return res.status(400).json({ error: '性格特质数据格式不正确' });
    }

    const id = `mbti-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const userId = req.user?.id;

    // 验证userId存在
    if (!userId) {
      return res.status(401).json({ error: '用户未认证' });
    }

    // 计算置信度分数
    const scores = Object.values(test_scores).filter(score => typeof score === 'number');
    let confidence_score = 0.5; // 默认值
    if (scores.length > 0) {
      const mean = scores.reduce((sum, score) => sum + score, 0) / scores.length;
      const variance = scores.reduce((sum, score) => sum + Math.pow(score - mean, 2), 0) / scores.length;
      confidence_score = Math.max(0, Math.min(1, 1 - (variance / 2500)));
    }

    // 确保confidence_score是有效数字
    if (isNaN(confidence_score)) {
      confidence_score = 0.5;
    }

    // 生成AI分析结果
    const ai_analysis = generateAiAnalysis(mbti_type, test_scores, personality_traits);
    const work_suggestions = generateWorkSuggestions(mbti_type, ai_analysis);
    const improvement_advice = generateImprovementAdvice(mbti_type, ai_analysis);

    // 确保所有生成的数据都不为undefined，且所有值都转换为null而不是undefined
    const safeAiAnalysis = ai_analysis || {};
    const safeWorkSuggestions = work_suggestions || {};
    const safeImprovementAdvice = improvement_advice || {};

    const [result] = await db.execute(
      `INSERT INTO mbti_records (
        id, user_id, mbti_type, test_scores, personality_traits,
        ai_analysis, work_suggestions, improvement_advice,
        personal_info, test_version, confidence_score
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id || null,
        userId || null,
        mbti_type || null,
        JSON.stringify(test_scores || {}),
        JSON.stringify(personality_traits || {}),
        JSON.stringify(safeAiAnalysis || {}),
        JSON.stringify(safeWorkSuggestions || {}),
        safeImprovementAdvice ? JSON.stringify(safeImprovementAdvice) : null,
        safePersonalInfo ? JSON.stringify(safePersonalInfo) : null,
        safeTestVersion || 'v1.0',
        confidence_score || 0.5
      ].map(param => param === undefined ? null : param)
    );

    // 记录系统日志
    await db.execute(
      `INSERT INTO system_logs (id, user_id, user_name, action, description, category)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        `log-${Date.now()}`,
        userId || null,
        req.user?.name || '未知用户',
        'create_mbti_record',
        `创建MBTI记录: ${mbti_type || '未知类型'}`,
        'mbti'
      ].map(param => param === undefined ? null : param)
    );

    res.status(201).json({
      message: 'MBTI记录创建成功',
      id: id,
      mbti_type: mbti_type,
      confidence_score: confidence_score
    });
  } catch (error) {
    console.error('创建MBTI记录错误:', error);
    console.error('错误堆栈:', error.stack);
    console.error('请求数据:', JSON.stringify(req.body, null, 2));
    res.status(500).json({
      error: '服务器内部错误',
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// 获取用户的MBTI记录列表
app.get('/api/mbti-records', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10, mbti_type } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT id, mbti_type, test_date, confidence_score, created_at
      FROM mbti_records
      WHERE user_id = ? AND is_active = TRUE
    `;
    let params = [userId];

    if (mbti_type) {
      query += ' AND mbti_type = ?';
      params.push(mbti_type);
    }

    // LIMIT 和 OFFSET 不能使用参数绑定，需要直接拼接（已确保值是整数）
    const limitValue = parseInt(limit) || 10;
    const offsetValue = parseInt(offset) || 0;
    query += ` ORDER BY test_date DESC LIMIT ${limitValue} OFFSET ${offsetValue}`;

    const [records] = await db.execute(query, params);

    // 获取总数
    let countQuery = 'SELECT COUNT(*) as total FROM mbti_records WHERE user_id = ? AND is_active = TRUE';
    let countParams = [userId];
    if (mbti_type) {
      countQuery += ' AND mbti_type = ?';
      countParams.push(mbti_type);
    }
    const [countResult] = await db.execute(countQuery, countParams);

    res.json({
      records: records,
      total: countResult[0].total,
      page: parseInt(page),
      limit: parseInt(limit)
    });
  } catch (error) {
    console.error('获取MBTI记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取用户最新的MBTI记录
app.get('/api/mbti-records/latest', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const [rows] = await db.execute(
      `SELECT * FROM mbti_records
       WHERE user_id = ? AND is_active = TRUE
       ORDER BY test_date DESC
       LIMIT 1`,
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: '未找到MBTI记录' });
    }

    const record = rows[0];

    // 解析JSON字段（使用安全解析函数）
    record.test_scores = safeParseJSON(record.test_scores);
    record.personality_traits = safeParseJSON(record.personality_traits);
    record.ai_analysis = safeParseJSON(record.ai_analysis);
    record.work_suggestions = safeParseJSON(record.work_suggestions);
    if (record.improvement_advice) {
      record.improvement_advice = safeParseJSON(record.improvement_advice);
    }
    if (record.personal_info) {
      record.personal_info = safeParseJSON(record.personal_info);
    }

    res.json(record);
  } catch (error) {
    console.error('获取最新MBTI记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取特定MBTI记录详情
app.get('/api/mbti-records/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const [rows] = await db.execute(
      `SELECT * FROM mbti_records
       WHERE id = ? AND user_id = ? AND is_active = TRUE`,
      [id, userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'MBTI记录不存在' });
    }

    const record = rows[0];

    // 解析JSON字段（使用安全解析函数）
    record.test_scores = safeParseJSON(record.test_scores);
    record.personality_traits = safeParseJSON(record.personality_traits);
    record.ai_analysis = safeParseJSON(record.ai_analysis);
    record.work_suggestions = safeParseJSON(record.work_suggestions);
    if (record.improvement_advice) {
      record.improvement_advice = safeParseJSON(record.improvement_advice);
    }
    if (record.personal_info) {
      record.personal_info = safeParseJSON(record.personal_info);
    }

    res.json(record);
  } catch (error) {
    console.error('获取MBTI记录详情错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新MBTI记录
app.put('/api/mbti-records/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const updateData = req.body;

    // 检查记录是否存在且属于当前用户
    const [existing] = await db.execute(
      `SELECT id FROM mbti_records
       WHERE id = ? AND user_id = ? AND is_active = TRUE`,
      [id, userId]
    );

    if (existing.length === 0) {
      return res.status(404).json({ error: 'MBTI记录不存在' });
    }

    // 构建更新字段
    const updateFields = [];
    const updateValues = [];

    if (updateData.mbti_type) {
      updateFields.push('mbti_type = ?');
      updateValues.push(updateData.mbti_type);
    }
    if (updateData.test_scores) {
      updateFields.push('test_scores = ?');
      updateValues.push(JSON.stringify(updateData.test_scores));
    }
    if (updateData.personality_traits) {
      updateFields.push('personality_traits = ?');
      updateValues.push(JSON.stringify(updateData.personality_traits));
    }
    if (updateData.ai_analysis) {
      updateFields.push('ai_analysis = ?');
      updateValues.push(JSON.stringify(updateData.ai_analysis));
    }
    if (updateData.work_suggestions) {
      updateFields.push('work_suggestions = ?');
      updateValues.push(JSON.stringify(updateData.work_suggestions));
    }
    if (updateData.improvement_advice) {
      updateFields.push('improvement_advice = ?');
      updateValues.push(JSON.stringify(updateData.improvement_advice));
    }
    if (updateData.personal_info) {
      updateFields.push('personal_info = ?');
      updateValues.push(JSON.stringify(updateData.personal_info));
    }
    if (updateData.confidence_score !== undefined) {
      updateFields.push('confidence_score = ?');
      updateValues.push(updateData.confidence_score);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: '没有提供更新数据' });
    }

    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    updateValues.push(id, userId);

    await db.execute(
      `UPDATE mbti_records SET ${updateFields.join(', ')}
       WHERE id = ? AND user_id = ?`,
      [...updateValues]
    );

    // 记录系统日志
    await db.execute(
      `INSERT INTO system_logs (id, user_id, user_name, action, description, category)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        `log-${Date.now()}`,
        userId,
        req.user.name,
        'update_mbti_record',
        `更新MBTI记录: ${id}`,
        'mbti'
      ]
    );

    res.json({ message: 'MBTI记录更新成功' });
  } catch (error) {
    console.error('更新MBTI记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除MBTI记录（软删除）
app.delete('/api/mbti-records/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const [result] = await db.execute(
      `UPDATE mbti_records SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
       WHERE id = ? AND user_id = ? AND is_active = TRUE`,
      [id, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'MBTI记录不存在' });
    }

    // 记录系统日志
    await db.execute(
      `INSERT INTO system_logs (id, user_id, user_name, action, description, category)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        `log-${Date.now()}`,
        userId,
        req.user.name,
        'delete_mbti_record',
        `删除MBTI记录: ${id}`,
        'mbti'
      ]
    );

    res.json({ message: 'MBTI记录删除成功' });
  } catch (error) {
    console.error('删除MBTI记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取MBTI统计信息（管理员权限）
app.get('/api/mbti-records/statistics', authenticateToken, async (req, res) => {
  try {
    // 检查管理员权限
    if (!['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '权限不足' });
    }

    const [stats] = await db.execute(`
      SELECT
        mbti_type,
        COUNT(*) as total_count,
        AVG(confidence_score) as avg_confidence,
        COUNT(DISTINCT user_id) as unique_users,
        MAX(test_date) as latest_test
      FROM mbti_records
      WHERE is_active = TRUE
      GROUP BY mbti_type
      ORDER BY total_count DESC
    `);

    res.json(stats);
  } catch (error) {
    console.error('获取MBTI统计错误:', error);
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

// ================= AI 文本分析（基础版） =================
// 提取关键词和词频统计
app.post('/api/ai/analyze-log', async (req, res) => {
  try {
    const { text, topK = 20 } = req.body || {};
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text 不能为空' });
    }

    // 临时使用简单分词（等segmentit安装后恢复）
    const tokens = text.split(/[\s\n\r\t,，。！？；：""''（）()【】\[\]{}]+/)
      .filter(w => w && w.trim().length > 1);
    const freqMap = {};
    for (const w of tokens) {
      freqMap[w] = (freqMap[w] || 0) + 1;
    }
    const wordFrequencies = Object.entries(freqMap)
      .map(([word, count]) => ({ word, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, topK);

    // 用频次代替简易"权重"，并归一化一个权重字段
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
    // 临时使用简单分词（等segmentit安装后恢复）
    const tokens = combined.split(/[\s\n\r\t,，。！？；：""''（）()【】\[\]{}]+/)
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

// ==================== DeepSeek API 性格分析 ====================

// 保存词云分析结果
app.post('/api/ai/save-wordcloud', authenticateToken, async (req, res) => {
  try {
    const { analysisDate, keywords, wordFrequencies, description } = req.body;
    const userId = req.user.id;

    const [result] = await db.execute(
      `INSERT INTO wordcloud_analysis (user_id, analysis_date, keywords, word_frequencies, description, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [userId, analysisDate, JSON.stringify(keywords), JSON.stringify(wordFrequencies), description]
    );

    const analysis = {
      id: result.insertId.toString(),
      userId: userId,
      analysisDate: analysisDate,
      keywords: keywords,
      wordFrequencies: wordFrequencies,
      createdAt: new Date(),
      description: description,
    };

    res.json(analysis);
  } catch (error) {
    console.error('保存词云分析失败:', error);
    res.status(500).json({ error: '保存词云分析失败' });
  }
});

// 获取词云分析历史
app.get('/api/ai/wordcloud-history', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await db.execute(
      `SELECT id, user_id, analysis_date, keywords, word_frequencies, description, created_at
       FROM wordcloud_analysis
       WHERE user_id = ?
       ORDER BY created_at DESC`,
      [userId]
    );

    const history = rows.map(row => ({
      id: row.id.toString(),
      userId: row.user_id,
      analysisDate: row.analysis_date,
      keywords: JSON.parse(row.keywords),
      wordFrequencies: JSON.parse(row.word_frequencies),
      createdAt: row.created_at,
      description: row.description,
    }));

    res.json(history);
  } catch (error) {
    console.error('获取词云历史失败:', error);
    res.status(500).json({ error: '获取词云历史失败' });
  }
});

// DeepSeek API 性格分析
app.post('/api/ai/personality-analysis', authenticateToken, async (req, res) => {
  try {
    const { logText, mbtiType, useDeepSeek } = req.body;
    const userId = req.user.id;

    let analysisResult;

    if (useDeepSeek && DEEPSEEK_API_KEY) {
      // 使用DeepSeek API进行性格分析
      analysisResult = await analyzePersonalityWithDeepSeek(logText, mbtiType);
    } else {
      // 使用本地算法进行性格分析
      analysisResult = await analyzePersonalityLocally(logText, mbtiType);
    }

    const [result] = await db.execute(
      `INSERT INTO personality_analysis (user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, ai_analysis_text, description, created_at)
       VALUES (?, NOW(), ?, ?, ?, ?, ?, ?, NOW())`,
      [
        userId,
        JSON.stringify(analysisResult.personalityTraits),
        analysisResult.mbtiType,
        JSON.stringify(analysisResult.workSuggestions),
        JSON.stringify(analysisResult.personalityChart),
        analysisResult.aiAnalysisText || null,
        'AI性格分析报告'
      ]
    );

    const analysis = {
      id: result.insertId.toString(),
      userId: userId,
      analysisDate: new Date(),
      personalityTraits: analysisResult.personalityTraits,
      mbtiType: analysisResult.mbtiType,
      workSuggestions: analysisResult.workSuggestions,
      personalityChart: analysisResult.personalityChart,
      aiAnalysisText: analysisResult.aiAnalysisText,
      createdAt: new Date(),
      description: 'AI性格分析报告',
    };

    res.json(analysis);
  } catch (error) {
    console.error('性格分析失败:', error);
    res.status(500).json({ error: '性格分析失败' });
  }
});

// 获取性格分析历史
app.get('/api/ai/personality-history', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await db.execute(
      `SELECT id, user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, ai_analysis_text, description, created_at
       FROM personality_analysis
       WHERE user_id = ?
       ORDER BY created_at DESC`,
      [userId]
    );

    const history = rows.map(row => ({
      id: row.id.toString(),
      userId: row.user_id,
      analysisDate: row.analysis_date,
      personalityTraits: safeParseJSON(row.personality_traits),
      mbtiType: row.mbti_type,
      workSuggestions: safeParseJSON(row.work_suggestions),
      personalityChart: safeParseJSON(row.personality_chart),
      aiAnalysisText: row.ai_analysis_text,
      createdAt: row.created_at,
      description: row.description,
    }));

    res.json(history);
  } catch (error) {
    console.error('获取性格分析历史失败:', error);
    res.status(500).json({ error: '获取性格分析历史失败' });
  }
});

// ==================== DeepSeek API 分析函数 ====================

// DeepSeek API 性格分析函数
async function analyzePersonalityWithDeepSeek(logText, mbtiType) {
  const prompt = `
请基于以下日志内容进行性格分析：

日志内容：${logText}

${mbtiType ? `已知MBTI类型：${mbtiType}` : ''}

请分析并返回以下格式的JSON数据：
{
  "personalityTraits": {
    "外向性": 0.8,
    "宜人性": 0.6,
    "尽责性": 0.9,
    "神经质": 0.3,
    "开放性": 0.7
  },
  "mbtiType": "ENFP",
  "workSuggestions": {
    "适合职业": ["产品经理", "市场营销", "创意总监"],
    "工作环境": "开放、创新、团队合作",
    "发展建议": "发挥创造力，加强执行力",
    "沟通风格": "热情、富有感染力"
  },
  "personalityChart": {
    "traits": {
      "外向性": 0.8,
      "宜人性": 0.6,
      "尽责性": 0.9,
      "神经质": 0.3,
      "开放性": 0.7
    },
    "dimensions": {
      "领导力": 0.8,
      "创造力": 0.7,
      "沟通能力": 0.9,
      "分析能力": 0.6,
      "团队合作": 0.8
    }
  }
}
`;

  try {
    const response = await axios.post(DEEPSEEK_API_URL, {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'system',
          content: '你是一个专业的性格分析师，擅长基于日志内容进行MBTI性格分析和职业建议。请返回有效的JSON格式数据。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 2000
    }, {
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: 30000 // 30秒超时
    });

    const content = response.data.choices[0].message.content;

    // 尝试解析JSON响应
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsedData = JSON.parse(jsonMatch[0]);
        // 返回解析后的数据和原始文本
        return {
          ...parsedData,
          aiAnalysisText: content // 保存原始AI分析文本
        };
      }
    } catch (parseError) {
      console.error('JSON解析失败:', parseError);
    }

    // 如果解析失败，返回默认分析结果（包含原始文本）
    return {
      ...getDefaultPersonalityAnalysis(),
      aiAnalysisText: content || 'AI分析结果解析失败，使用默认数据'
    };

  } catch (error) {
    console.error('DeepSeek API调用失败:', error);
    return {
      ...getDefaultPersonalityAnalysis(),
      aiAnalysisText: `AI分析失败: ${error.message}`
    };
  }
}

// 本地性格分析函数（备用方案）
async function analyzePersonalityLocally(logText, mbtiType) {
  // 基于关键词的简单性格分析
  const text = logText.toLowerCase();

  // 分析外向性
  const extroversionKeywords = ['团队', '合作', '沟通', '交流', '社交', '会议', '讨论'];
  const extroversionScore = extroversionKeywords.filter(keyword => text.includes(keyword)).length / extroversionKeywords.length;

  // 分析开放性
  const opennessKeywords = ['创新', '创意', '想法', '探索', '学习', '新', '尝试'];
  const opennessScore = opennessKeywords.filter(keyword => text.includes(keyword)).length / opennessKeywords.length;

  // 分析尽责性
  const conscientiousnessKeywords = ['完成', '任务', '计划', '目标', '责任', '认真', '仔细'];
  const conscientiousnessScore = conscientiousnessKeywords.filter(keyword => text.includes(keyword)).length / conscientiousnessKeywords.length;

  // 分析宜人性
  const agreeablenessKeywords = ['帮助', '支持', '关心', '理解', '友好', '和谐'];
  const agreeablenessScore = agreeablenessKeywords.filter(keyword => text.includes(keyword)).length / agreeablenessKeywords.length;

  // 分析神经质
  const neuroticismKeywords = ['压力', '焦虑', '担心', '紧张', '困难', '问题'];
  const neuroticismScore = Math.max(0, 1 - neuroticismKeywords.filter(keyword => text.includes(keyword)).length / neuroticismKeywords.length);

  // 基于MBTI类型调整分析结果
  const mbtiBasedAdjustments = getMbtiBasedAdjustments(mbtiType);

  return {
    personalityTraits: {
      '外向性': Math.min(1, Math.max(0, extroversionScore + mbtiBasedAdjustments.extroversion)),
      '宜人性': Math.min(1, Math.max(0, agreeablenessScore + mbtiBasedAdjustments.agreeableness)),
      '尽责性': Math.min(1, Math.max(0, conscientiousnessScore + mbtiBasedAdjustments.conscientiousness)),
      '神经质': Math.min(1, Math.max(0, neuroticismScore + mbtiBasedAdjustments.neuroticism)),
      '开放性': Math.min(1, Math.max(0, opennessScore + mbtiBasedAdjustments.openness)),
    },
    mbtiType: mbtiType || 'ENFP',
    workSuggestions: mbtiBasedAdjustments.workSuggestions,
    personalityChart: {
      traits: {
        '外向性': Math.min(1, Math.max(0, extroversionScore + mbtiBasedAdjustments.extroversion)),
        '宜人性': Math.min(1, Math.max(0, agreeablenessScore + mbtiBasedAdjustments.agreeableness)),
        '尽责性': Math.min(1, Math.max(0, conscientiousnessScore + mbtiBasedAdjustments.conscientiousness)),
        '神经质': Math.min(1, Math.max(0, neuroticismScore + mbtiBasedAdjustments.neuroticism)),
        '开放性': Math.min(1, Math.max(0, opennessScore + mbtiBasedAdjustments.openness)),
      },
      dimensions: mbtiBasedAdjustments.dimensions,
    },
    aiAnalysisText: `基于本地算法和MBTI类型(${mbtiType})的分析：通过关键词匹配分析日志内容，结合MBTI性格类型特征，评估五大人格特质和职业倾向。建议使用DeepSeek API获得更精确的分析结果。`,
  };
}

// 根据MBTI类型获取调整参数
function getMbtiBasedAdjustments(mbtiType) {
  const adjustments = {
    // 外向性调整 (E vs I)
    extroversion: mbtiType && mbtiType.startsWith('E') ? 0.3 : -0.2,
    // 开放性调整 (N vs S)
    openness: mbtiType && mbtiType[1] === 'N' ? 0.3 : -0.1,
    // 尽责性调整 (J vs P)
    conscientiousness: mbtiType && mbtiType[3] === 'J' ? 0.2 : -0.1,
    // 宜人性调整 (F vs T)
    agreeableness: mbtiType && mbtiType[2] === 'F' ? 0.2 : -0.1,
    // 神经质调整 (基于MBTI类型特征)
    neuroticism: mbtiType && ['INFP', 'ISFP', 'ENFP', 'ESFP'].includes(mbtiType) ? 0.1 : -0.1,
  };

  // 工作建议
  const workSuggestions = getWorkSuggestionsByMbti(mbtiType);

  // 维度调整
  const dimensions = {
    '领导力': mbtiType && ['ENTJ', 'ESTJ', 'ENFJ', 'ESFJ'].includes(mbtiType) ? 0.8 : 0.6,
    '创造力': mbtiType && ['ENFP', 'INFP', 'ENFJ', 'INFJ'].includes(mbtiType) ? 0.8 : 0.6,
    '沟通能力': mbtiType && mbtiType.startsWith('E') ? 0.8 : 0.6,
    '分析能力': mbtiType && ['INTJ', 'INTP', 'ENTJ', 'ENTP'].includes(mbtiType) ? 0.8 : 0.6,
    '团队合作': mbtiType && mbtiType[2] === 'F' ? 0.8 : 0.6,
  };

  return {
    ...adjustments,
    workSuggestions,
    dimensions,
  };
}

// 根据MBTI类型获取工作建议
function getWorkSuggestionsByMbti(mbtiType) {
  const suggestions = {
    'ENFP': {
      '适合职业': ['产品经理', '市场营销', '创意总监', '培训师', '心理咨询师'],
      '工作环境': '开放、创新、团队合作',
      '发展建议': '发挥创造力，加强执行力',
      '沟通风格': '热情、富有感染力',
    },
    'INFP': {
      '适合职业': ['作家', '心理咨询师', '艺术指导', '翻译', '社会工作者'],
      '工作环境': '安静、有创意空间、价值观一致',
      '发展建议': '保持理想主义，提升实际执行力',
      '沟通风格': '温和、富有同理心',
    },
    'ESTJ': {
      '适合职业': ['项目经理', '行政主管', '财务经理', '运营总监', '律师'],
      '工作环境': '结构化、目标明确、有权威',
      '发展建议': '保持高效执行，提升灵活性',
      '沟通风格': '直接、务实、有组织性',
    },
    'ISTJ': {
      '适合职业': ['会计师', '审计师', '系统管理员', '质量经理', '公务员'],
      '工作环境': '稳定、有序、传统',
      '发展建议': '保持可靠性，适度创新',
      '沟通风格': '谨慎、准确、注重细节',
    },
    // 可以添加更多MBTI类型...
  };

  return suggestions[mbtiType] || {
    '适合职业': ['通用职业', '需要根据个人兴趣选择'],
    '工作环境': '根据个人偏好调整',
    '发展建议': '发挥个人优势，改进不足',
    '沟通风格': '根据性格特点调整',
  };
}

// 默认性格分析结果
function getDefaultPersonalityAnalysis() {
  return {
    personalityTraits: {
      '外向性': 0.8,
      '宜人性': 0.6,
      '尽责性': 0.9,
      '神经质': 0.3,
      '开放性': 0.7,
    },
    mbtiType: 'ENFP',
    workSuggestions: {
      '适合职业': ['产品经理', '市场营销', '创意总监', '培训师'],
      '工作环境': '开放、创新、团队合作',
      '发展建议': '发挥创造力，加强执行力',
      '沟通风格': '热情、富有感染力',
    },
    personalityChart: {
      traits: {
        '外向性': 0.8,
        '宜人性': 0.6,
        '尽责性': 0.9,
        '神经质': 0.3,
        '开放性': 0.7,
      },
      dimensions: {
        '领导力': 0.8,
        '创造力': 0.7,
        '沟通能力': 0.9,
        '分析能力': 0.6,
        '团队合作': 0.8,
      },
    },
    aiAnalysisText: '使用默认分析结果。请配置DeepSeek API Key以获得AI分析。',
  };
}
