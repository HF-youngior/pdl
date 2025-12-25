const fs = require('fs');
const https = require('https');
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
const axios = require('axios');
const multer = require('multer');
const swaggerUi = require('swagger-ui-express');
const swaggerDocument = require('./swagger.json');
require('dotenv').config();
// const { useDefault, Segment } = require('segmentit');
// const segmenter = useDefault(new Segment());
const { sendPush } = require('./push_jiguang');

// 高德地图API配置 - 用于经纬度转地址
const AMAP_API_KEY = process.env.AMAP_API_KEY || 'your_amap_api_key_here';
const AMAP_GEOCODE_URL = 'https://restapi.amap.com/v3/geocode/regeo';

// 经纬度转中文地址函数
async function convertToAddress(latitude, longitude) {
  if (!latitude || !longitude) return null;

  try {
    const response = await axios.get(AMAP_GEOCODE_URL, {
      params: {
        key: AMAP_API_KEY,
        location: `${longitude},${latitude}`, // 注意：高德API使用经度,纬度的顺序
        poitype: '',
        radius: 1000,
        extensions: 'all',
        batch: 'false',
        roadlevel: 0
      }
    });

    if (response.data.status === '1' && response.data.regeocode) {
      const addressComponent = response.data.regeocode.addressComponent;
      const formattedAddress = response.data.regeocode.formatted_address;

      // 构建详细地址信息
      const addressInfo = {
        formatted_address: formattedAddress,
        country: addressComponent.country || '',
        province: addressComponent.province || '',
        city: addressComponent.city || addressComponent.district || '',
        district: addressComponent.district || '',
        township: addressComponent.township || '',
        street: addressComponent.streetNumber?.street || '',
        street_number: addressComponent.streetNumber?.number || ''
      };

      return addressInfo;
    } else {
      console.warn('经纬度转地址失败:', response.data.info);
      // 如果是API Key平台不匹配的错误，返回原始坐标信息
      if (response.data.infocode === '10009') {
        console.warn('API Key平台不匹配，请在高德地图控制台添加Web服务API Key');
        return {
          formatted_address: `纬度: ${latitude}, 经度: ${longitude}`,
          country: '',
          province: '',
          city: '',
          district: '',
          township: '',
          street: '',
          street_number: '',
          note: 'API Key平台不匹配，显示原始坐标'
        };
      }
      return null;
    }
  } catch (error) {
    console.error('经纬度转地址异常:', error.message);
    // 如果是API Key平台不匹配的错误，返回原始坐标信息
    if (error.response && error.response.data && error.response.data.infocode === '10009') {
      console.warn('API Key平台不匹配，请在高德地图控制台添加Web服务API Key');
      return {
        formatted_address: `纬度: ${latitude}, 经度: ${longitude}`,
        country: '',
        province: '',
        city: '',
        district: '',
        township: '',
        street: '',
        street_number: '',
        note: 'API Key平台不匹配，显示原始坐标'
      };
    }
    return null;
  }
}

const app = express();
const PORT = process.env.PORT || 8080;

// ========= 密码工具 =========
const BCRYPT_ROUNDS = 10;
const isBcryptHash = (value) => typeof value === 'string' && value.startsWith('$2');
const hashPassword = async (plain) => bcrypt.hash(plain.trim(), BCRYPT_ROUNDS);

// DeepSeek API 配置
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const DEEPSEEK_API_URL = process.env.DEEPSEEK_API_URL || 'https://api.deepseek.com/v1/chat/completions';

// 中间件
app.use(cors());
app.use(express.json());

// 静态文件服务 - 提供Web管理端
app.use('/web_admin', express.static('../web_admin'));

// 静态文件服务 - 提供公共资源
const publicDir = path.join(__dirname, 'public');
app.use('/public', express.static(publicDir));

// 静态文件服务 - 根路径访问public目录
app.use('/', express.static(publicDir));

// Swagger UI 文档（基于 OpenAPI）
// 访问地址示例：http://localhost:8080/swagger
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 确保uploads目录存在
const uploadsDir = path.join(publicDir, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// 直接暴露上传目录，方便通过 http://host:port/uploads/xxx 访问
app.use('/uploads', express.static(uploadsDir));

// 配置multer用于图片上传
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadsDir);
  },
  filename: function (req, file, cb) {
    // 生成唯一文件名：时间戳 + 随机数 + 原始扩展名
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'img-' + uniqueSuffix + ext);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 限制文件大小为10MB
  },
  fileFilter: function (req, file, cb) {
    // 只允许图片文件
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('只允许上传图片文件 (jpeg, jpg, png, gif, webp)'));
    }
  }
});

// 数据库连接配置
const dbConfig = {
  host: process.env.DB_HOST || 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl123',
  password: process.env.DB_PASSWORD || 'Pdl1234567',
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

const allowedUserRoles = ['admin', 'founder', 'department_head', 'team_leader', 'employee'];

let db; // 连接池

// 时区处理工具函数（固定使用北京时间，避免依赖宿主机时区）
const BEIJING_OFFSET_MINUTES = 8 * 60;

function normalizeDateInput(dateTime) {
  if (!dateTime) return null;
  if (dateTime instanceof Date) {
    return new Date(dateTime.getTime());
  }
  const parsed = new Date(dateTime);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

function shiftToBeijing(date) {
  const utcMillis = date.getTime();
  return new Date(utcMillis + BEIJING_OFFSET_MINUTES * 60 * 1000);
}

// 将数据库中的时间统一转换为北京时间 ISO 字符串
function formatDateTimeForBeijing(dateTime) {
  const date = normalizeDateInput(dateTime);
  if (!date) return null;
  const beijingDate = shiftToBeijing(date);
  const year = beijingDate.getUTCFullYear();
  const month = String(beijingDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(beijingDate.getUTCDate()).padStart(2, '0');
  const hours = String(beijingDate.getUTCHours()).padStart(2, '0');
  const minutes = String(beijingDate.getUTCMinutes()).padStart(2, '0');
  const seconds = String(beijingDate.getUTCSeconds()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}+08:00`;
}

// 将任意时间转换为北京时间的 MySQL DATETIME 字符串
function formatDateTimeForMySQL(dateTime) {
  const date = normalizeDateInput(dateTime);
  if (!date) return null;
  const beijingDate = shiftToBeijing(date);
  const year = beijingDate.getUTCFullYear();
  const month = String(beijingDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(beijingDate.getUTCDate()).padStart(2, '0');
  const hours = String(beijingDate.getUTCHours()).padStart(2, '0');
  const minutes = String(beijingDate.getUTCMinutes()).padStart(2, '0');
  const seconds = String(beijingDate.getUTCSeconds()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

function formatDateOnlyForBeijing(dateTime) {
  const date = normalizeDateInput(dateTime);
  if (!date) return null;
  const beijingDate = shiftToBeijing(date);
  const year = beijingDate.getUTCFullYear();
  const month = String(beijingDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(beijingDate.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
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

// 将数据库中的关键词字段统一转换为字符串数组
function normalizeKeywordList(value) {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value
      .map(item => (typeof item === 'string' ? item.trim() : ''))
      .filter(Boolean);
  }
  if (typeof value === 'string') {
    return value
      .split(',')
      .map(item => item.trim())
      .filter(Boolean);
  }
  return [];
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,
    
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
      points INT DEFAULT 0,
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_login_at TIMESTAMP NULL,
      focus_duration INT DEFAULT 0 COMMENT '累计专注时长（秒）',
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (parent_id) REFERENCES users(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,
    
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,
    
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
      attachments JSON NULL,
      is_request BOOLEAN DEFAULT FALSE,
      request_type VARCHAR(50) NULL,
      request_response VARCHAR(20) NULL,
      related_task_id VARCHAR(36) NULL,
      FOREIGN KEY (parent_task_id) REFERENCES tasks(id),
      FOREIGN KEY (assignee_id) REFERENCES users(id),
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (created_by) REFERENCES users(id),
      FOREIGN KEY (related_task_id) REFERENCES tasks(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,
    
    // 任务通知表
    `CREATE TABLE IF NOT EXISTS task_notifications (
      id VARCHAR(36) PRIMARY KEY,
      task_id VARCHAR(36) NOT NULL,
      from_user_id VARCHAR(36) NOT NULL,
      to_user_id VARCHAR(36) NOT NULL,
      notification_type ENUM('task_assigned', 'task_progress_update', 'task_completed', 'task_cancelled', 'special_notes', 'deadline_warning') NOT NULL,
      message TEXT NOT NULL,
      is_read BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (task_id) REFERENCES tasks(id),
      FOREIGN KEY (from_user_id) REFERENCES users(id),
      FOREIGN KEY (to_user_id) REFERENCES users(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,
    
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
      images JSON NULL,
      location_name VARCHAR(200) NULL,
      location_latitude DECIMAL(10,7) NULL,
      location_longitude DECIMAL(10,7) NULL,
      is_archived BOOLEAN DEFAULT FALSE,
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (related_task_id) REFERENCES tasks(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,
    
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='MBTI测试记录表，存储用户性格测试结果和AI分析建议';`,

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='词云分析表，存储用户日志的词云分析结果';`,

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='性格分析表，存储AI性格分析结果';`,

    `CREATE TABLE IF NOT EXISTS task_assignees (
      id INT AUTO_INCREMENT PRIMARY KEY,
      task_id VARCHAR(36) NOT NULL,
      assignee_id VARCHAR(36) NOT NULL,
      assignee_name VARCHAR(100) NOT NULL,
      progress_percentage INT DEFAULT 0,
      status VARCHAR(50) DEFAULT 'pending',
      assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      completed_at TIMESTAMP NULL,
      UNIQUE KEY task_assignee_unique (task_id, assignee_id),
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
      FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`,

    // 签到记录表
    `CREATE TABLE IF NOT EXISTS checkin_records (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      checkin_date DATE NOT NULL,
      points_earned INT DEFAULT 5,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY user_checkin_date (user_id, checkin_date),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_id (user_id),
      INDEX idx_checkin_date (checkin_date),
      INDEX idx_user_date (user_id, checkin_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='签到记录表';`,

    // 积分流水表（包含获取与消耗）
    `CREATE TABLE IF NOT EXISTS points_transactions (
      id VARCHAR(64) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      type VARCHAR(20) NOT NULL, -- earn / spend
      amount INT NOT NULL,
      description VARCHAR(255),
      related_id VARCHAR(64),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_points_user_created (user_id, created_at),
      INDEX idx_points_type (type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分流水表（获取/消耗记录）';`,

    `CREATE TABLE IF NOT EXISTS user_devices (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      registration_id VARCHAR(128) NOT NULL,
      platform VARCHAR(20) DEFAULT 'android',
      last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_registration (registration_id),
      INDEX idx_user_id (user_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='极光推送设备注册表';`
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
    try { await db.execute("ALTER TABLE users ADD COLUMN focus_duration INT DEFAULT 0"); } catch(e){}

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
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN images JSON NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN location_name VARCHAR(200) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN location_latitude DECIMAL(10,7) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE personal_logs ADD COLUMN location_longitude DECIMAL(10,7) NULL"); } catch(e){}
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
    try { await db.execute("ALTER TABLE tasks ADD COLUMN request_start_time TIMESTAMP NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN request_end_time TIMESTAMP NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN request_response VARCHAR(20) NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN related_task_id VARCHAR(36) NULL"); } catch(e){}
    
    // users表积分字段
    try { await db.execute("ALTER TABLE users ADD COLUMN points INT DEFAULT 0"); } catch(e){}
    try { await db.execute("ALTER TABLE tasks ADD COLUMN attachments JSON NULL"); } catch(e){}
    try { await db.execute("ALTER TABLE mbti_records ADD COLUMN personal_info JSON NULL"); } catch(e){}
    // 索引、关联关系等原有包裹不变
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_personal_logs_user_id ON personal_logs(user_id)"); } catch (_) {}
    try { await db.execute("CREATE INDEX IF NOT EXISTS idx_personal_logs_log_date ON personal_logs(log_date)"); } catch (_) {}
    try {
      await db.execute(`ALTER TABLE task_notifications MODIFY notification_type ENUM(
        'task_assigned',
        'task_progress_update',
        'task_completed',
        'task_cancelled',
        'special_notes',
        'deadline_warning',
        'focus_invite'
      ) NOT NULL`);
    } catch (_) {}
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
    let isValidPassword = false;

    // 支持老的明文 -> 新的 bcrypt：若存储为明文且匹配，登录成功后回写为哈希
    if (isBcryptHash(user.password)) {
      isValidPassword = await bcrypt.compare(password, user.password);
    } else {
      isValidPassword = password === user.password;
      if (isValidPassword) {
        // 将旧明文密码升级为 bcrypt 哈希
        const hashed = await hashPassword(password);
        await db.execute('UPDATE users SET password = ? WHERE id = ?', [hashed, user.id]);
        user.password = hashed;
      }
    }

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
      { id: user.id, username: user.username, name: user.name, role: user.role, department_id: user.department_id },
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

app.post('/api/push/register', authenticateToken, async (req, res) => {
  try {
    const { registrationId, platform } = req.body || {};
    if (!registrationId || typeof registrationId !== 'string') {
      return res.status(400).json({ error: 'registrationId 必填' });
    }
    await db.execute(
      `INSERT INTO user_devices (user_id, registration_id, platform, last_seen)
       VALUES (?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE user_id = VALUES(user_id),
                               platform = VALUES(platform),
                               last_seen = NOW()`,
      [req.user.id, registrationId.trim(), (platform || 'android').trim()]
    );
    res.json({ ok: true });
  } catch (error) {
    console.error('注册推送设备失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

app.post('/api/push/broadcast-logout', authenticateToken, async (req, res) => {
  try {
    const { excludeRegistrationId } = req.body || {};
    const [rows] = await db.execute(
      'SELECT registration_id FROM user_devices WHERE user_id = ?',
      [req.user.id]
    );
    let sent = 0;
    for (const row of rows) {
      const regId = row.registration_id;
      if (excludeRegistrationId && regId === excludeRegistrationId) continue;
      const ok = await sendPush(
        regId,
        '账号通知',
        '该账号在另一设备退出登录',
        { type: 'account_logout', userId: String(req.user.id) }
      );
      if (ok) sent++;
    }
    res.json({ ok: true, sent });
  } catch (error) {
    console.error('广播登出通知失败:', error);
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

// 累加用户番茄钟专注时长
app.post('/api/user/focus-duration', authenticateToken, async (req, res) => {
  try {
    const duration = Number(req.body?.duration ?? 0);
    if (!Number.isFinite(duration) || duration <= 0) {
      return res.status(400).json({ error: 'duration 必须为大于0的数字' });
    }

    await db.execute(
      'UPDATE users SET focus_duration = IFNULL(focus_duration, 0) + ? WHERE id = ?',
      [duration, req.user.id]
    );

    const [rows] = await db.execute(
      'SELECT focus_duration FROM users WHERE id = ?',
      [req.user.id]
    );
    const totalFocusDuration = Number(rows?.[0]?.focus_duration ?? 0);

    res.json({
      message: '专注时长已更新',
      durationAdded: duration,
      totalFocusDuration,
    });
  } catch (error) {
    console.error('更新专注时长错误:', error);
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

// 创建用户
app.post('/api/users', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { username, password, name, position, department_id, role, parent_id } = req.body || {};

    if (!username || !password || !name || !position || !department_id || !role) {
      return res.status(400).json({ error: '用户名、密码、姓名、职位、部门和角色为必填项' });
    }

    if (!allowedUserRoles.includes(role)) {
      return res.status(400).json({ error: '不支持的角色类型' });
    }

    const [[existingUser]] = await db.execute('SELECT id FROM users WHERE username = ?', [username]);
    if (existingUser) {
      return res.status(409).json({ error: '该用户名已被使用' });
    }

    const [[departmentExists]] = await db.execute('SELECT id FROM departments WHERE id = ?', [department_id]);
    if (!departmentExists) {
      return res.status(400).json({ error: '部门不存在，请重新选择' });
    }

    let parentToUse = parent_id || null;
    if (parentToUse) {
      const [[parentExists]] = await db.execute('SELECT id FROM users WHERE id = ?', [parentToUse]);
      if (!parentExists) {
        return res.status(400).json({ error: '指定的上级用户不存在' });
      }
    }

    const userId = require('crypto').randomUUID();
    await db.execute(
      `INSERT INTO users (id, username, password, name, position, department_id, role, parent_id, is_active, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE, NOW())`,
      [userId, username.trim(), await hashPassword(password), name.trim(), position.trim(), department_id, role, parentToUse]
    );

    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.name, u.position, u.role, u.department_id, d.name as department_name, u.parent_id
       FROM users u
       LEFT JOIN departments d ON u.department_id = d.id
       WHERE u.id = ?`,
      [userId]
    );

    res.status(201).json({ message: '用户创建成功', user: rows[0] });
  } catch (error) {
    console.error('创建用户错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 更新用户
app.put('/api/users/:id', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;
    const { password, name, position, department_id, role, parent_id } = req.body || {};

    const [existingRows] = await db.execute('SELECT * FROM users WHERE id = ? AND is_active = TRUE', [id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ error: '用户不存在或已被删除' });
    }

    const updates = [];
    const values = [];

    if (password && password.trim()) {
      updates.push('password = ?');
      values.push(await hashPassword(password));
    }
    if (name && name.trim()) {
      updates.push('name = ?');
      values.push(name.trim());
    }
    if (position && position.trim()) {
      updates.push('position = ?');
      values.push(position.trim());
    }
    if (typeof department_id === 'string' && department_id.trim()) {
      const [[departmentExists]] = await db.execute('SELECT id FROM departments WHERE id = ?', [department_id.trim()]);
      if (!departmentExists) {
        return res.status(400).json({ error: '部门不存在，请重新选择' });
      }
      updates.push('department_id = ?');
      values.push(department_id.trim());
    }
    if (role) {
      if (!allowedUserRoles.includes(role)) {
        return res.status(400).json({ error: '不支持的角色类型' });
      }
      updates.push('role = ?');
      values.push(role);
    }
    if (parent_id !== undefined) {
      if (parent_id) {
        const [[parentExists]] = await db.execute('SELECT id FROM users WHERE id = ?', [parent_id]);
        if (!parentExists) {
          return res.status(400).json({ error: '指定的上级用户不存在' });
        }
        updates.push('parent_id = ?');
        values.push(parent_id);
      } else {
        updates.push('parent_id = NULL');
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '没有可更新的字段' });
    }

    const updateSql = `UPDATE users SET ${updates.join(', ')} WHERE id = ?`;
    values.push(id);
    await db.execute(updateSql, values);

    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.name, u.position, u.role, u.department_id, d.name as department_name, u.parent_id
       FROM users u
       LEFT JOIN departments d ON u.department_id = d.id
       WHERE u.id = ?`,
      [id]
    );

    res.json({ message: '用户更新成功', user: rows[0] });
  } catch (error) {
    console.error('更新用户错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除用户（软删除）
app.delete('/api/users/:id', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;

    if (id === req.user.id) {
      return res.status(400).json({ error: '不能删除当前登录的账号' });
    }

    const [existingRows] = await db.execute('SELECT id FROM users WHERE id = ? AND is_active = TRUE', [id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ error: '用户不存在或已被删除' });
    }

    await db.execute('UPDATE users SET is_active = FALSE WHERE id = ?', [id]);
    res.json({ message: '用户已删除' });
  } catch (error) {
    console.error('删除用户错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 用户自己修改密码（需要验证旧密码）
app.put('/api/auth/change-password', authenticateToken, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: '请提供旧密码和新密码' });
    }

    if (newPassword.trim().length < 6) {
      return res.status(400).json({ error: '新密码长度至少为6位' });
    }

    // 获取当前用户信息
    const [users] = await db.execute('SELECT id, password FROM users WHERE id = ? AND is_active = TRUE', [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ error: '用户不存在或已被删除' });
    }

    const user = users[0];

    // 验证旧密码
    let oldOk = false;
    if (isBcryptHash(user.password)) {
      oldOk = await bcrypt.compare(oldPassword.trim(), user.password);
    } else {
      oldOk = user.password === oldPassword.trim();
    }
    if (!oldOk) return res.status(401).json({ error: '旧密码不正确' });

    // 更新密码
    const newHashed = await hashPassword(newPassword.trim());
    await db.execute('UPDATE users SET password = ? WHERE id = ?', [newHashed, req.user.id]);

    res.json({ message: '密码修改成功' });
  } catch (error) {
    console.error('修改密码错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 仪表盘统计数据
app.get('/api/admin/dashboard-stats', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const [
      [userRows],
      [importantRows],
      [pendingRows],
      [todayLogRows]
    ] = await Promise.all([
      db.execute('SELECT COUNT(*) AS total FROM users WHERE is_active = TRUE'),
      db.execute('SELECT COUNT(*) AS total FROM company_important_items WHERE is_selected = TRUE'),
      db.execute(`SELECT COUNT(*) AS total FROM tasks WHERE status IN ('pending', 'in_progress')`),
      db.execute(`SELECT COUNT(*) AS total FROM system_logs WHERE DATE(created_at) = CURDATE()`)
    ]);

    res.json({
      totalUsers: Number(userRows?.[0]?.total || 0),
      totalImportantItems: Number(importantRows?.[0]?.total || 0),
      pendingTasks: Number(pendingRows?.[0]?.total || 0),
      todayLogs: Number(todayLogRows?.[0]?.total || 0)
    });
  } catch (error) {
    console.error('获取仪表盘统计数据错误:', error);
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
// 兼容两种用法：
// 1）旧版：直接传入 title/description/priority/deadline 创建一条新记录
// 2）新版（文档示例）：传入 item_id，从重要事项库中选择并标记为公司重要事项
app.post('/api/company-important-items', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { item_id, title, description, priority, deadline } = req.body;

    // 新版用法：从重要事项库中选择
    if (item_id) {
      try {
        // 检查记录是否存在
        const [rows] = await db.execute(
          'SELECT id FROM company_important_items WHERE id = ?',
          [item_id]
        );

        if (!rows || rows.length === 0) {
          return res.status(404).json({ error: '指定的重要事项不存在' });
        }

        // 标记为已选择
        await db.execute(
          'UPDATE company_important_items SET is_selected = TRUE, updated_by = ? WHERE id = ?',
          [req.user.id, item_id]
        );

        return res.status(200).json({ message: '重要事项添加成功', id: item_id });
      } catch (innerError) {
        console.error('根据 item_id 创建公司重要事项错误:', innerError);
        return res.status(500).json({ error: '服务器内部错误' });
      }
    }

    // 旧版用法：直接创建新记录，做一下基本参数校验，避免插入 NULL 导致 500
    if (!title || !description) {
      return res.status(400).json({ error: 'title 和 description 为必填字段' });
    }

    const safePriority = priority || 'p1';
    const id = require('crypto').randomUUID();

    await db.execute(
      'INSERT INTO company_important_items (id, title, description, priority, deadline, created_by) VALUES (?, ?, ?, ?, ?, ?)',
      [id, title, description, safePriority, deadline || null, req.user.id]
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
// 支持部分字段更新，避免未传字段被写成 NULL 导致 500
app.put('/api/company-important-items/:id', authenticateToken, checkPermission(['admin', 'founder']), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, priority, status, deadline } = req.body;

    const fields = [];
    const params = [];

    if (title !== undefined) {
      fields.push('title = ?');
      params.push(title);
    }
    if (description !== undefined) {
      fields.push('description = ?');
      params.push(description);
    }
    if (priority !== undefined) {
      fields.push('priority = ?');
      params.push(priority);
    }
    if (status !== undefined) {
      fields.push('status = ?');
      params.push(status);
    }
    if (deadline !== undefined) {
      fields.push('deadline = ?');
      params.push(deadline);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: '没有提供需要更新的字段' });
    }

    fields.push('updated_by = ?');
    params.push(req.user.id);
    params.push(id);

    const sql = `UPDATE company_important_items SET ${fields.join(', ')} WHERE id = ?`;
    const [result] = await db.execute(sql, params);

    if (!result || result.affectedRows === 0) {
      return res.status(404).json({ error: '公司重要事项不存在' });
    }

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
    const tasksWithTimezone = await Promise.all(rows.map(async (task) => {
      const taskWithTimezone = {
        ...task,
        start_time: formatDateTimeForBeijing(task.start_time),
        end_time: formatDateTimeForBeijing(task.end_time),
        deadline: formatDateTimeForBeijing(task.deadline),
        created_at: formatDateTimeForBeijing(task.created_at),
        updated_at: formatDateTimeForBeijing(task.updated_at),
        request_start_time: formatDateTimeForBeijing(task.request_start_time),
        request_end_time: formatDateTimeForBeijing(task.request_end_time)
      };

      // 检查是否为多负责人任务
      const [assignees] = await db.execute(
        `SELECT assignee_id, assignee_name, progress_percentage, status FROM task_assignees WHERE task_id = ?`,
        [task.id]
      );

      if (assignees.length > 0) {
        taskWithTimezone.assignees = assignees;
      }

      return taskWithTimezone;
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

    // 处理时区 - 将所有时间字段转换为北京时间格式
    const taskWithTimezone = {
      ...rows[0],
      start_time: formatDateTimeForBeijing(rows[0].start_time),
      end_time: formatDateTimeForBeijing(rows[0].end_time),
      deadline: formatDateTimeForBeijing(rows[0].deadline),
      created_at: formatDateTimeForBeijing(rows[0].created_at),
      updated_at: formatDateTimeForBeijing(rows[0].updated_at),
      request_start_time: formatDateTimeForBeijing(rows[0].request_start_time),
      request_end_time: formatDateTimeForBeijing(rows[0].request_end_time),
      related_task_id: rows[0].related_task_id // 确保返回related_task_id字段
    };

    // 检查是否为多负责人任务
    const [assignees] = await db.execute(
      `SELECT assignee_id, assignee_name, progress_percentage, status FROM task_assignees WHERE task_id = ?`,
      [id]
    );

    if (assignees.length > 0) {
      taskWithTimezone.assignees = assignees;
    }

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
      assignee_ids, // 支持多个负责人
      department_id,
      priority,
      deadline,
      start_time,
      end_time,
      location,
      is_all_day,
      parent_task_id
    } = req.body;
    const attachments = Array.isArray(req.body.attachments)
      ? req.body.attachments.filter(item => typeof item === 'string' && item.trim().length > 0)
      : [];

    // 处理多负责人逻辑
    let assigneeIds = [];
    if (assignee_ids && Array.isArray(assignee_ids) && assignee_ids.length > 0) {
      // 使用多负责人列表
      assigneeIds = assignee_ids;
    } else if (assignee_id) {
      // 使用单个负责人
      assigneeIds = [assignee_id];
    } else {
      return res.status(400).json({ error: '必须指定至少一个责任人' });
    }

    // 参数验证
    if (!title || !title.trim()) {
      return res.status(400).json({ error: '任务名称不能为空' });
    }
    if (assigneeIds.length === 0) {
      return res.status(400).json({ error: '必须指定至少一个责任人' });
    }
    // department_id 可以为空，将从被分配人信息中获取

    // 权限检查
    if (req.user.role === 'employee') {
      return res.status(403).json({ error: '员工无权创建任务' });
    }

    // 获取第一个被分配人信息（用于主负责人和部门信息）
    const [firstAssigneeRows] = await db.execute(
      'SELECT name, department_id FROM users WHERE id = ?',
      [assigneeIds[0]]
    );

    if (firstAssigneeRows.length === 0) {
      return res.status(400).json({ error: '第一个被分配人不存在' });
    }

    const firstAssigneeName = firstAssigneeRows[0].name;
    // 如果前端没有传递 department_id，从用户信息中获取
    const final_department_id = department_id || firstAssigneeRows[0].department_id;

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

    // 创建主任务记录（使用第一个负责人作为主负责人）
    await db.execute(
      `INSERT INTO tasks (
        id, title, description, parent_task_id, assignee_id, assignee_name,
        department_id, priority, deadline, created_by, start_time, end_time,
        location, is_all_day, progress_percentage, status, attachments
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        taskId,
        title,
        cleanValue(description),
        cleanValue(parent_task_id),
        assigneeIds[0], // 第一个负责人作为主负责人
        firstAssigneeName,
        final_department_id,
        priority || 'p1',
        cleanValue(deadline),
        req.user.id,
        cleanValue(start_time),
        cleanValue(end_time),
        cleanValue(location),
        is_all_day || false,
        0, // 初始进度为0
        status,
        attachments.length ? JSON.stringify(attachments) : JSON.stringify([])
      ]
    );

    // 为每个负责人创建分配记录
    for (const assigneeId of assigneeIds) {
      // 获取负责人信息
      const [assigneeInfo] = await db.execute(
        'SELECT name FROM users WHERE id = ?',
        [assigneeId]
      );

      if (assigneeInfo.length > 0) {
        // 插入分配记录
        await db.execute(
          `INSERT INTO task_assignees (task_id, assignee_id, assignee_name)
           VALUES (?, ?, ?)`,
          [taskId, assigneeId, assigneeInfo[0].name]
        );

        // 为每个负责人创建任务分配通知
        await createNotification(taskId, req.user.id, assigneeId, 'task_assigned', `您收到了新任务：${title}`);
      }
    }

    // 创建任务时，如果截止时间在24小时内，立刻发送截止时间通知
    if (cleanValue(deadline)) {
      await checkAndSendDeadlineNotification(taskId, assignee_id, cleanValue(deadline));
    }

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

    // 检查是否为多负责人任务
    const [assigneeCount] = await db.execute(
      `SELECT COUNT(*) as count FROM task_assignees WHERE task_id = ?`,
      [id]
    );

    if (assigneeCount[0].count > 0) {
      // 多负责人任务：更新该用户在任务分配表中的进度
      await db.execute(
        `UPDATE task_assignees SET
         status = ?, progress_percentage = ?, completed_at = ?
         WHERE task_id = ? AND assignee_id = ?`,
        [status, finalProgress, finalCompletedAt, id, req.user.id]
      );

      // 更新主任务的总体进度
      await updateMultiAssigneeTaskProgress(id);
    } else {
      // 单负责人任务：更新主任务进度
      await db.execute(
        `UPDATE tasks SET
         status = ?, progress_percentage = ?, special_notes = ?, completed_at = ?
         WHERE id = ?`,
        [status, finalProgress, finalNotes, finalCompletedAt, id]
      );
    }

    // 如果这个任务有父任务，更新父任务的进度
    if (task.parent_task_id) {
      await updateParentTaskProgress(task.parent_task_id);

      // 当子任务完成时，通知对应的上司或任务总支
      if (status === 'completed') {
        // 获取父任务信息
        const [parentTaskRows] = await db.execute('SELECT created_by, title, assignee_id FROM tasks WHERE id = ?', [task.parent_task_id]);
        if (parentTaskRows.length > 0) {
          const parentTask = parentTaskRows[0];
          const notifiedUserIds = new Set(); // 用于避免重复通知

          // 1. 通知父任务的负责人（assignee_id）
          if (parentTask.assignee_id && !notifiedUserIds.has(parentTask.assignee_id)) {
            await createNotification(
              id,
              req.user.id,
              parentTask.assignee_id,
              'task_completed',
              `子任务《${task.title}》已完成（父任务：${parentTask.title}）`
            );
            notifiedUserIds.add(parentTask.assignee_id);
          }

          // 2. 通知父任务的创建者（任务总支），如果与负责人不同
          if (parentTask.created_by && !notifiedUserIds.has(parentTask.created_by)) {
            await createNotification(
              id,
              req.user.id,
              parentTask.created_by,
              'task_completed',
              `子任务《${task.title}》已完成（父任务：${parentTask.title}）`
            );
            notifiedUserIds.add(parentTask.created_by);
          }

          // 3. 通知子任务的创建者（直接上司），如果与父任务负责人和创建者不同
          if (task.created_by && !notifiedUserIds.has(task.created_by)) {
            await createNotification(
              id,
              req.user.id,
              task.created_by,
              'task_completed',
              `子任务《${task.title}》已完成（父任务：${parentTask.title}）`
            );
            notifiedUserIds.add(task.created_by);
          }
        }
      } else {
        // 非完成状态，只发送进度更新通知（保持原有逻辑）
        const [parentTaskRows] = await db.execute('SELECT created_by, title FROM tasks WHERE id = ?', [task.parent_task_id]);
        if (parentTaskRows.length > 0) {
          const parentTask = parentTaskRows[0];
          await createNotification(id, req.user.id, parentTask.created_by, 'task_progress_update', `任务进度更新：${task.title}`);
        }
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

    // 检查截止时间是否变动
    let deadlineChanged = false;
    let newDeadline = null;
    if (deadline !== undefined) {
      const oldDeadline = task.deadline ? new Date(task.deadline).getTime() : null;
      newDeadline = cleanValue(deadline);
      const newDeadlineTime = newDeadline ? new Date(newDeadline).getTime() : null;

      // 判断截止时间是否真的变动了（考虑null的情况）
      if (oldDeadline !== newDeadlineTime) {
        deadlineChanged = true;
      }

      updates.push('deadline = ?');
      values.push(newDeadline);
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
    if (req.body.attachments !== undefined) {
      const updatedAttachments = Array.isArray(req.body.attachments)
        ? req.body.attachments.filter(item => typeof item === 'string' && item.trim().length > 0)
        : [];
      updates.push('attachments = ?');
      values.push(JSON.stringify(updatedAttachments));
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '没有要更新的字段' });
    }

    values.push(id);
    
    await db.execute(
      `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    // 如果截止时间变动了，清除之前的截止时间通知记录，重新检测
    if (deadlineChanged) {
      const assigneeId = task.assignee_id;
      // 删除该任务之前的截止时间通知，重新检测
      try {
        await db.execute(
          `DELETE FROM task_notifications
           WHERE task_id = ?
           AND to_user_id = ?
           AND notification_type = 'deadline_warning'`,
          [id, assigneeId]
        );
      } catch (err) {
        console.error('清除旧通知失败:', err);
      }

      // 如果新的截止时间存在，重新检测是否在24小时内
      if (newDeadline) {
        await checkAndSendDeadlineNotification(id, assigneeId, newDeadline);
      }
    }

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
      related_task_id,
      request_start_time,
      request_end_time
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

    // 格式化邀约时间
    let formattedRequestStartTime = null;
    let formattedRequestEndTime = null;
    if (request_start_time) {
      try {
        const requestStartTimeDate = new Date(request_start_time);
        if (isNaN(requestStartTimeDate.getTime())) {
          return res.status(400).json({ error: '邀约开始时间格式无效' });
        }
        formattedRequestStartTime = requestStartTimeDate.toISOString().slice(0, 19).replace('T', ' ');
      } catch (e) {
        return res.status(400).json({ error: '邀约开始时间格式无效' });
      }
    }
    if (request_end_time) {
      try {
        const requestEndTimeDate = new Date(request_end_time);
        if (isNaN(requestEndTimeDate.getTime())) {
          return res.status(400).json({ error: '邀约结束时间格式无效' });
        }
        formattedRequestEndTime = requestEndTimeDate.toISOString().slice(0, 19).replace('T', ' ');
      } catch (e) {
        return res.status(400).json({ error: '邀约结束时间格式无效' });
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
        is_request, request_type, related_task_id, request_start_time, request_end_time
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
        cleanValue(related_task_id),
        formattedRequestStartTime,
        formattedRequestEndTime
      ]
    );

    // 创建通知
    const notificationMessage = related_task_id && relatedTaskTitle
      ? `您收到了邀约请求：${request_type}（关联任务：${relatedTaskTitle}）`
      : `您收到了邀约请求：${request_type}`;
    await createNotification(taskId, req.user.id, assignee_id, 'task_assigned', notificationMessage);

    // 创建邀约请求时，如果截止时间在24小时内，立刻发送截止时间通知
    if (formattedDeadline) {
      await checkAndSendDeadlineNotification(taskId, assignee_id, formattedDeadline);
    }

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

// 更新向上邀约请求
app.put('/api/tasks/:id/request', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const {
      request_type,
      assignee_id,
      description,
      deadline,
      related_task_id,
      request_start_time,
      request_end_time
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

    // 检查是否为邀约任务
    if (!task.is_request) {
      return res.status(400).json({ error: '此任务不是邀约任务' });
    }

    // 检查是否为创建者
    if (task.created_by !== req.user.id && task.created_by !== req.user.username) {
      return res.status(403).json({ error: '只有创建者可以修改邀约请求' });
    }

    // 检查是否已被审批
    if (task.status === 'completed' || task.request_response) {
      return res.status(400).json({ error: '已被审批的邀约请求不能修改' });
    }

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

    // 格式化邀约时间
    let formattedRequestStartTime = null;
    let formattedRequestEndTime = null;
    if (request_start_time) {
      try {
        const requestStartTimeDate = new Date(request_start_time);
        if (isNaN(requestStartTimeDate.getTime())) {
          return res.status(400).json({ error: '邀约开始时间格式无效' });
        }
        formattedRequestStartTime = requestStartTimeDate.toISOString().slice(0, 19).replace('T', ' ');
      } catch (e) {
        return res.status(400).json({ error: '邀约开始时间格式无效' });
      }
    }
    if (request_end_time) {
      try {
        const requestEndTimeDate = new Date(request_end_time);
        if (isNaN(requestEndTimeDate.getTime())) {
          return res.status(400).json({ error: '邀约结束时间格式无效' });
        }
        formattedRequestEndTime = requestEndTimeDate.toISOString().slice(0, 19).replace('T', ' ');
      } catch (e) {
        return res.status(400).json({ error: '邀约结束时间格式无效' });
      }
    }

    // 生成任务标题
    const taskTitle = `邀约请求：${request_type}`;

    // 检查截止时间是否变动
    const oldDeadline = task.deadline ? new Date(task.deadline).getTime() : null;
    const newDeadlineTime = formattedDeadline ? new Date(formattedDeadline).getTime() : null;
    const deadlineChanged = oldDeadline !== newDeadlineTime;

    // 更新邀约任务
    await db.execute(
      `UPDATE tasks SET
        title = ?,
        description = ?,
        assignee_id = ?,
        assignee_name = ?,
        department_id = ?,
        deadline = ?,
        request_type = ?,
        related_task_id = ?,
        request_start_time = ?,
        request_end_time = ?
      WHERE id = ?`,
      [
        taskTitle,
        description.trim(),
        assignee_id,
        assignee_name,
        department_id,
        formattedDeadline,
        request_type.trim(),
        cleanValue(related_task_id),
        formattedRequestStartTime,
        formattedRequestEndTime,
        id
      ]
    );

    // 如果截止时间变动了，清除之前的截止时间通知记录，重新检测
    if (deadlineChanged) {
      // 删除该任务之前的截止时间通知，重新检测
      try {
        await db.execute(
          `DELETE FROM task_notifications
           WHERE task_id = ?
           AND to_user_id = ?
           AND notification_type = 'deadline_warning'`,
          [id, assignee_id]
        );
      } catch (err) {
        console.error('清除旧通知失败:', err);
      }

      // 如果新的截止时间存在，重新检测是否在24小时内
      if (formattedDeadline) {
        await checkAndSendDeadlineNotification(id, assignee_id, formattedDeadline);
      }
    }

    // 如果截止时间变动了，清除之前的截止时间通知记录，重新检测
    if (deadlineChanged) {
      // 删除该任务之前的截止时间通知，重新检测
      try {
        await db.execute(
          `DELETE FROM task_notifications
           WHERE task_id = ?
           AND to_user_id = ?
           AND notification_type = 'deadline_warning'`,
          [id, assignee_id]
        );
      } catch (err) {
        console.error('清除旧通知失败:', err);
      }

      // 如果新的截止时间存在，重新检测是否在24小时内
      if (formattedDeadline) {
        await checkAndSendDeadlineNotification(id, assignee_id, formattedDeadline);
      }
    }

    res.status(200).json({
      message: '邀约请求更新成功',
      id: id,
      task: {
        id: id,
        title: taskTitle,
        request_type: request_type.trim(),
        status: task.status
      }
    });
  } catch (error) {
    console.error('更新邀约请求错误:', error);
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
      `SELECT tn.*, t.title as task_title, t.deadline as task_deadline, u.name as from_user_name
       FROM task_notifications tn
       LEFT JOIN tasks t ON tn.task_id = t.id
       LEFT JOIN users u ON tn.from_user_id = u.id
       WHERE tn.to_user_id = ?
       ORDER BY tn.created_at DESC`,
      [req.user.id]
    );

    // 将时间字段转换为北京时间格式
    const formattedRows = rows.map(row => {
      const formatted = { ...row };
      if (row.created_at) {
        formatted.created_at = formatDateTimeForBeijing(row.created_at);
      }
      if (row.task_deadline) {
        formatted.task_deadline = formatDateTimeForBeijing(row.task_deadline);
      }
      return formatted;
    });

    res.json(formattedRows);
  } catch (error) {
    console.error('获取通知错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 登录会话内触发的截止时间提醒
app.post('/api/notifications/deadline-reminders', authenticateToken, async (req, res) => {
  try {
    const rawHours = Number(req.body?.hoursBefore ?? 24);
    const hoursBefore = Number.isFinite(rawHours)
      ? Math.min(Math.max(Math.round(rawHours), 1), 168)
      : 24;

    const now = new Date();
    const upcomingThreshold = new Date(now.getTime() + hoursBefore * 60 * 60 * 1000);
    const dedupeThreshold = new Date(now.getTime() - hoursBefore * 60 * 60 * 1000);
    const assigneeName = req.user.name || req.user.username || '';

    const [tasks] = await db.execute(
      `SELECT id, title, deadline, priority, status
       FROM tasks
       WHERE deadline IS NOT NULL
         AND status NOT IN ('completed', 'cancelled')
         AND (assignee_id = ? OR assignee_name = ?)
         AND deadline BETWEEN ? AND ?
       ORDER BY deadline ASC`,
      [
        req.user.id,
        assigneeName,
        formatDateTimeForMySQL(now),
        formatDateTimeForMySQL(upcomingThreshold),
      ]
    );

    const reminders = [];
    for (const task of tasks) {
      const [existing] = await db.execute(
        `SELECT id FROM task_notifications
         WHERE task_id = ?
           AND to_user_id = ?
           AND notification_type = 'deadline_warning'
           AND created_at >= ?`,
        [task.id, req.user.id, formatDateTimeForMySQL(dedupeThreshold)]
      );

      if (existing.length > 0) continue;

      const message = `系统提醒：任务《${task.title}》将在${hoursBefore}小时内到期，请及时处理。`;
      const notificationId = await createNotification(
        task.id,
        req.user.id,
        req.user.id,
        'deadline_warning',
        message
      );

      if (!notificationId) continue;

      reminders.push({
        notification_id: notificationId,
        task_id: task.id,
        title: task.title,
        deadline: formatDateTimeForBeijing(task.deadline),
        priority: task.priority,
        status: task.status,
        message,
      });
    }

    res.json({
      reminders,
      checkedTasks: tasks.length,
      hoursBefore,
      nextCheckSuggestedInMinutes: Math.max(1, Math.min(15, Math.round(hoursBefore / 6))),
    });
  } catch (error) {
    console.error('截止时间提醒检查失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 删除通知
app.delete('/api/notifications/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // 验证通知是否属于当前用户
    const [notificationRows] = await db.execute(
      'SELECT to_user_id FROM task_notifications WHERE id = ?',
      [id]
    );

    if (notificationRows.length === 0) {
      return res.status(404).json({ error: '通知不存在' });
    }

    if (notificationRows[0].to_user_id !== req.user.id) {
      return res.status(403).json({ error: '无权删除此通知' });
    }

    await db.execute('DELETE FROM task_notifications WHERE id = ?', [id]);

    res.json({ message: '通知删除成功' });
  } catch (error) {
    console.error('删除通知错误:', error);
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

// 批量/全部标记通知为已读
app.put('/api/notifications/mark-all-read', authenticateToken, async (req, res) => {
  try {
    const ids = Array.isArray(req.body?.notification_ids)
      ? req.body.notification_ids.filter(id => typeof id === 'string' && id.trim().length > 0)
      : [];

    if (ids.length > 0) {
      const placeholders = ids.map(() => '?').join(',');
      await db.execute(
        `UPDATE task_notifications SET is_read = TRUE WHERE to_user_id = ? AND id IN (${placeholders})`,
        [req.user.id, ...ids]
      );
    } else {
      await db.execute(
        'UPDATE task_notifications SET is_read = TRUE WHERE to_user_id = ?',
        [req.user.id]
      );
    }

    res.json({ message: '通知已全部标记为已读' });
  } catch (error) {
    console.error('批量标记通知已读错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 标记通知为未读
app.put('/api/notifications/:id/unread', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    await db.execute(
      'UPDATE task_notifications SET is_read = FALSE WHERE id = ? AND to_user_id = ?',
      [id, req.user.id]
    );
    res.json({ message: '通知已标记为未读' });
  } catch (error) {
    console.error('标记通知未读错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 批量/全部标记通知为未读
app.put('/api/notifications/mark-all-unread', authenticateToken, async (req, res) => {
  try {
    const ids = Array.isArray(req.body?.notification_ids)
      ? req.body.notification_ids.filter(id => typeof id === 'string' && id.trim().length > 0)
      : [];

    if (ids.length > 0) {
      const placeholders = ids.map(() => '?').join(',');
      await db.execute(
        `UPDATE task_notifications SET is_read = FALSE WHERE to_user_id = ? AND id IN (${placeholders})`,
        [req.user.id, ...ids]
      );
    } else {
      await db.execute(
        'UPDATE task_notifications SET is_read = FALSE WHERE to_user_id = ?',
        [req.user.id]
      );
    }

    res.json({ message: '通知已全部标记为未读' });
  } catch (error) {
    console.error('批量标记通知未读错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// ==================== 签到相关API ====================

// 获取用户积分（兼容是否带 /api 前缀的两种路由）
app.get(['/api/checkin/points', '/checkin/points'], authenticateToken, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.id;
    
    // 验证权限：只能查询自己的积分，或者管理员/创始人可以查询其他人的
    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权查询该用户的积分' });
    }

    const [rows] = await db.execute(
      'SELECT points FROM users WHERE id = ?',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: '用户不存在' });
    }

    res.json({ points: rows[0].points || 0 });
  } catch (error) {
    console.error('获取积分错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取签到记录（按月查询，兼容是否带 /api 前缀）
app.get(['/api/checkin/records', '/checkin/records'], authenticateToken, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.id;
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = parseInt(req.query.month) || (new Date().getMonth() + 1);
    
    // 验证权限
    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权查询该用户的签到记录' });
    }

    // 查询该月的签到记录
    const [rows] = await db.execute(
      `SELECT checkin_date, points_earned, created_at
       FROM checkin_records
       WHERE user_id = ? 
         AND YEAR(checkin_date) = ?
         AND MONTH(checkin_date) = ?
       ORDER BY checkin_date ASC`,
      [userId, year, month]
    );

    // 格式化日期为 YYYY-MM-DD 格式
    const records = rows.map(row => ({
      checkin_date: formatDateOnlyForBeijing(row.checkin_date),
      points_earned: row.points_earned,
      created_at: formatDateTimeForBeijing(row.created_at)
    }));

    res.json({ records });
  } catch (error) {
    console.error('获取签到记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取积分获取/消耗记录
// type=earn 使用 checkin_records；type=spend 使用 points_transactions
// 兼容是否带 /api 前缀
app.get(['/api/checkin/points-history', '/checkin/points-history'], authenticateToken, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.id;
    const type = req.query.type || 'earn'; // earn | spend
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = parseInt(req.query.month) || (new Date().getMonth() + 1);

    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权查询该用户的积分记录' });
    }

    let rows;

    if (type === 'spend') {
      // 消耗记录：来自积分流水表
      [rows] = await db.execute(
        `SELECT DATE(created_at) AS date, amount, description, created_at
         FROM points_transactions
         WHERE user_id = ?
           AND type = 'spend'
           AND YEAR(created_at) = ?
           AND MONTH(created_at) = ?
         ORDER BY created_at DESC`,
        [userId, year, month]
      );
    } else {
      // 获取记录：来自签到记录表
      [rows] = await db.execute(
        `SELECT checkin_date AS date, points_earned AS amount, '每日签到' AS description, created_at
         FROM checkin_records
         WHERE user_id = ?
           AND YEAR(checkin_date) = ?
           AND MONTH(checkin_date) = ?
         ORDER BY checkin_date DESC`,
        [userId, year, month]
      );
    }

    const records = rows.map(row => ({
      date: formatDateOnlyForBeijing(row.date),
      amount: row.amount,
      description: row.description,
      created_at: formatDateTimeForBeijing(row.created_at)
    }));

    res.json({ records });
  } catch (error) {
    console.error('获取积分记录错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取连续签到天数
app.get('/api/checkin/consecutive', authenticateToken, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.id;
    
    // 验证权限
    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权查询该用户的连续签到天数' });
    }

    // 获取所有签到日期，按日期降序排列
    const [rows] = await db.execute(
      `SELECT checkin_date
       FROM checkin_records
       WHERE user_id = ?
       ORDER BY checkin_date DESC`,
      [userId]
    );

    if (rows.length === 0) {
      return res.json({ consecutiveDays: 0 });
    }

    // 计算连续签到天数
    let consecutiveDays = 0;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    // 将日期格式化为 YYYY-MM-DD 并转换为Date对象进行比较
    const checkinDates = rows.map(row => {
      const date = new Date(row.checkin_date);
      date.setHours(0, 0, 0, 0);
      return date;
    });

    // 检查今天是否签到
    let expectedDate = new Date(today);
    let checkIndex = 0;
    
    // 如果今天已签到，从今天开始计算；否则从昨天开始
    if (checkinDates.length > 0 && checkinDates[0].getTime() === expectedDate.getTime()) {
      consecutiveDays = 1;
      checkIndex = 1;
      expectedDate = new Date(today);
      expectedDate.setDate(expectedDate.getDate() - 1);
    } else {
      // 从昨天开始检查
      expectedDate = new Date(today);
      expectedDate.setDate(expectedDate.getDate() - 1);
    }

    // 检查连续签到
    while (checkIndex < checkinDates.length) {
      const expectedTime = expectedDate.getTime();
      const checkinTime = checkinDates[checkIndex].getTime();
      
      if (checkinTime === expectedTime) {
        consecutiveDays++;
        expectedDate.setDate(expectedDate.getDate() - 1);
        checkIndex++;
      } else if (checkinTime < expectedTime) {
        // 日期不连续，停止计算
        break;
      } else {
        // 跳过更早的签到记录（理论上不应该出现）
        checkIndex++;
      }
    }

    res.json({ consecutiveDays });
  } catch (error) {
    console.error('获取连续签到天数错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 每日签到
app.post('/api/checkin', authenticateToken, async (req, res) => {
  try {
    const userId = req.body.userId || req.user.id;
    
    // 验证权限：只能为自己签到，或者管理员/创始人可以为其他人签到
    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权为该用户签到' });
    }

    // 获取今天的日期（北京时间）
    const today = new Date();
    const beijingDate = shiftToBeijing(today);
    const todayStr = formatDateOnlyForBeijing(beijingDate);

    // 检查今天是否已经签到
    const [existing] = await db.execute(
      'SELECT id FROM checkin_records WHERE user_id = ? AND checkin_date = ?',
      [userId, todayStr]
    );

    if (existing.length > 0) {
      return res.status(400).json({ error: '今天已经签到过了' });
    }

    // 计算连续签到天数（用于可能的奖励）
    // 先检查昨天是否签到
    const yesterday = new Date(beijingDate);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = formatDateOnlyForBeijing(yesterday);
    
    const [lastCheckin] = await db.execute(
      `SELECT checkin_date
       FROM checkin_records
       WHERE user_id = ?
       ORDER BY checkin_date DESC
       LIMIT 1`,
      [userId]
    );

    let consecutiveDays = 1; // 今天签到至少是1天
    
    if (lastCheckin.length > 0 && lastCheckin[0].checkin_date === yesterdayStr) {
      // 昨天签到了，需要计算之前的连续天数
      const [allCheckins] = await db.execute(
        `SELECT checkin_date
         FROM checkin_records
         WHERE user_id = ?
         ORDER BY checkin_date DESC`,
        [userId]
      );

      // 从昨天开始往前计算连续天数
      let expectedDate = new Date(yesterday);
      let count = 1; // 包括昨天
      
      for (let i = 0; i < allCheckins.length; i++) {
        const checkinDate = new Date(allCheckins[i].checkin_date);
        checkinDate.setHours(0, 0, 0, 0);
        expectedDate.setHours(0, 0, 0, 0);
        
        if (checkinDate.getTime() === expectedDate.getTime()) {
          count++;
          expectedDate.setDate(expectedDate.getDate() - 1);
        } else {
          break;
        }
      }
      
      consecutiveDays = count; // 加上今天
    } else if (lastCheckin.length === 0) {
      // 第一次签到
      consecutiveDays = 1;
    }
    // 如果昨天没签到，但之前有签到记录，则连续天数重置为1（已经设置）

    // 基础积分
    let pointsEarned = 5;
    
    // 连续签到奖励（可选）
    if (consecutiveDays >= 30) {
      pointsEarned = 20; // 连续30天额外奖励
    } else if (consecutiveDays >= 7) {
      pointsEarned = 10; // 连续7天额外奖励
    }

    // 开始事务
    const connection = await db.getConnection();
    await connection.beginTransaction();

    try {
      // 生成签到记录ID
      const checkinId = `checkin-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      
      // 插入签到记录
      await connection.execute(
        `INSERT INTO checkin_records (id, user_id, checkin_date, points_earned, created_at)
         VALUES (?, ?, ?, ?, NOW())`,
        [checkinId, userId, todayStr, pointsEarned]
      );

      // 写入积分流水（获取）
      const txnId = `ptx-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      await connection.execute(
        `INSERT INTO points_transactions (id, user_id, type, amount, description, related_id, created_at)
         VALUES (?, ?, 'earn', ?, '每日签到', ?, NOW())`,
        [txnId, userId, pointsEarned, checkinId]
      );

      // 更新用户积分
      await connection.execute(
        'UPDATE users SET points = COALESCE(points, 0) + ? WHERE id = ?',
        [pointsEarned, userId]
      );

      // 获取更新后的积分
      const [userRows] = await connection.execute(
        'SELECT points FROM users WHERE id = ?',
        [userId]
      );

      await connection.commit();
      connection.release();

      res.json({
        message: '签到成功',
        pointsEarned,
        points: userRows[0].points || 0,
        consecutiveDays,
        checkinDate: todayStr
      });
    } catch (error) {
      await connection.rollback();
      connection.release();
      throw error;
    }
  } catch (error) {
    console.error('签到错误:', error);
    res.status(500).json({ error: error.message || '服务器内部错误' });
  }
});

// 使用积分兑换奖励（例如 Loopy 装扮），兼容是否带 /api 前缀
app.post(['/api/checkin/redeem', '/checkin/redeem'], authenticateToken, async (req, res) => {
  try {
    const userId = req.body.userId || req.user.id;
    const cost = parseInt(req.body.cost, 10);
    const itemName = (req.body.itemName || '').toString().trim();

    if (!Number.isFinite(cost) || cost <= 0) {
      return res.status(400).json({ error: '无效的兑换积分消耗值' });
    }

    // 只能为自己兑换，或者管理员/创始人可以为其他人兑换
    if (userId !== req.user.id && !['admin', 'founder'].includes(req.user.role)) {
      return res.status(403).json({ error: '无权为该用户进行积分兑换' });
    }

    // 查询当前积分
    const [rows] = await db.execute(
      'SELECT points FROM users WHERE id = ?',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: '用户不存在' });
    }

    const currentPoints = rows[0].points || 0;
    if (currentPoints < cost) {
      return res.status(400).json({ error: '积分不足，无法兑换该奖励' });
    }

    const newPoints = currentPoints - cost;

    // 开启简单事务，确保扣减积分与流水记录一致
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      await connection.execute(
        'UPDATE users SET points = ? WHERE id = ?',
        [newPoints, userId]
      );

      const txnId = `ptx-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      const desc = itemName
        ? `兑换：${itemName}`
        : '兑换积分商城奖励';

      await connection.execute(
        `INSERT INTO points_transactions (id, user_id, type, amount, description, related_id, created_at)
         VALUES (?, ?, 'spend', ?, ?, NULL, NOW())`,
        [txnId, userId, cost, desc]
      );

      await connection.commit();
      connection.release();

      res.json({
        message: '兑换成功',
        points: newPoints
      });
    } catch (innerErr) {
      await connection.rollback();
      connection.release();
      throw innerErr;
    }
  } catch (error) {
    console.error('积分兑换错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 图片上传API
app.post('/api/upload-image', authenticateToken, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '没有上传文件' });
    }

    // 返回图片URL（相对于public目录）
    const imageUrl = `/uploads/${req.file.filename}`;

    // 如果需要完整URL，可以这样构建：
    // const baseUrl = req.protocol + '://' + req.get('host');
    // const fullUrl = baseUrl + imageUrl;

    res.json({
      success: true,
      url: imageUrl,
      filename: req.file.filename
    });
  } catch (error) {
    console.error('图片上传错误:', error);
    res.status(500).json({ error: '图片上传失败', details: error.message });
  }
});

// 批量图片上传API
app.post('/api/upload-images', authenticateToken, upload.array('images', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: '没有上传文件' });
    }

    const imageUrls = req.files.map(file => ({
      url: `/uploads/${file.filename}`,
      filename: file.filename
    }));

    res.json({
      success: true,
      images: imageUrls
    });
  } catch (error) {
    console.error('批量图片上传错误:', error);
    res.status(500).json({ error: '图片上传失败', details: error.message });
  }
});

// 创建个人日志
async function convertPersonalLogForResponse(log, taskUpdates = []) {
  if (!log) return null;

  // 如果有经纬度信息，转换为中文地址
  let locationAddress = null;
  if (log.location_latitude && log.location_longitude) {
    const addressInfo = await convertToAddress(log.location_latitude, log.location_longitude);
    // 提取格式化地址作为字符串，同时保留完整信息供前端使用
    locationAddress = addressInfo ? addressInfo.formatted_address : null;
  }

  return {
    ...log,
    created_at: formatDateTimeForBeijing(log.created_at),
    updated_at: formatDateTimeForBeijing(log.updated_at),
    log_date: log.log_date ? formatDateOnlyForBeijing(log.log_date) : null,
    location_address: locationAddress,
    taskUpdates
  };
}

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
  const images = Array.isArray(payload.images)
    ? payload.images.filter(item => typeof item === 'string' && item.trim().length > 0)
    : [];
  const locationPayload = payload.location || {};
  const location_name = locationPayload.name || payload.location_name || null;
  const location_latitude = locationPayload.latitude ?? payload.location_latitude ?? null;
  const location_longitude = locationPayload.longitude ?? payload.location_longitude ?? null;

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();

    // 1) 插入 personal_logs
    const insertSql = `
      INSERT INTO personal_logs (
        id, log_id, user_id, title, content, is_completed, created_at, log_date, weather, keywords,
        log_title, log_content, category, quadrant, is_archived, related_task_id,
        images, location_name, location_latitude, location_longitude
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    await connection.execute(insertSql, [
      id, businessLogId, userId, title, content, is_completed, created_at, log_date, weather, keywords,
      log_title, log_content, category, quadrant, is_archived, related_task_id,
      images.length ? JSON.stringify(images) : JSON.stringify([]),
      location_name,
      location_latitude,
      location_longitude
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

    const logRecord = rows[0];
    const response = await convertPersonalLogForResponse(logRecord, taskUpdates);
    return res.status(201).json(response);
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

      return await convertPersonalLogForResponse(log, links.map(link => ({
        taskId: link.task_id,
        taskName: link.task_name,
        progress_percentage: link.progress_percentage,
        task_status: link.task_status
      })));
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
    const converted = rows.map(log => ({
      ...log,
      created_at: formatDateTimeForBeijing(log.created_at)
    }));
    res.json(converted);
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
      weather: payload.weather ?? null,
      keywords: dbKeywords,
      log_title: payload.log_title ?? null,
      log_content: payload.log_content ?? null,
      quadrant: payload.quadrant || 'important_not_urgent',
      is_archived: payload.is_archived ? 1 : 0,
      related_task_id: payload.related_task_id ?? null
    };

    // 只有在前端明确传入 log_date 字段时才更新数据库中的 log_date，
    // 避免用户仅修改天气等其它字段时把原来的日期覆盖为 NULL。
    if (Object.prototype.hasOwnProperty.call(payload, 'log_date')) {
      fields.log_date = payload.log_date ? formatDateOnly(payload.log_date) : null;
    }
    if (payload.images !== undefined) {
      const updatedImages = Array.isArray(payload.images)
        ? payload.images.filter(item => typeof item === 'string' && item.trim().length > 0)
        : [];
      fields.images = JSON.stringify(updatedImages);
    }
    if (payload.location !== undefined || payload.location_name !== undefined) {
      const locPayload = payload.location || {};
      fields.location_name = locPayload.name || payload.location_name || null;
      fields.location_latitude = locPayload.latitude ?? payload.location_latitude ?? null;
      fields.location_longitude = locPayload.longitude ?? payload.location_longitude ?? null;
    }
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
    return res.status(200).json(await convertPersonalLogForResponse(newLogRows[0], finalLinks));
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
    // 对于 focus_invite 类型，task_id 可以为 null
    const finalTaskId = (type === 'focus_invite' || !taskId) ? null : taskId;
    
    console.log(`   [createNotification] 创建通知: type=${type}, fromUserId=${fromUserId}, toUserId=${toUserId}, taskId=${finalTaskId}`);
    
    await db.execute(
      'INSERT INTO task_notifications (id, task_id, from_user_id, to_user_id, notification_type, message) VALUES (?, ?, ?, ?, ?, ?)',
      [notificationId, taskId, fromUserId, toUserId, type, message]
    );
    
    console.log(`   [createNotification] ✅ 通知已插入数据库: ${notificationId}`);

    // 通过极光推送发送到接收者的所有设备（后台/锁屏可见）
    try {
      const [devices] = await db.execute(
        'SELECT registration_id FROM user_devices WHERE user_id = ?',
        [toUserId]
      );
      const titleMap = {
        task_assigned: '新任务分配',
        task_completed: '任务完成',
        task_progress_update: '任务进度更新',
        task_cancelled: '任务取消',
        special_notes: '特别备注',
        deadline_warning: '截止时间提醒',
        focus_invite: '专注邀约'
      };
      const title = titleMap[type] || '通知';
      let sentCount = 0;
      for (const row of devices) {
        const regId = row.registration_id;
        if (!regId) continue;
        const ok = await sendPush(regId, title, message, {
          type,
          notificationId,
          taskId: finalTaskId || '',
          toUserId: String(toUserId)
        });
        if (ok) sentCount++;
      }
      console.log(`   [createNotification] 已通过极光推送发送到设备: ${sentCount}/${devices.length}`);
    } catch (pushErr) {
      console.error('   [createNotification] 极光推送发送失败:', pushErr?.message || pushErr);
    }

    return notificationId;
  } catch (error) {
    console.error('创建通知失败:', error);
    console.error('错误详情:', error.message);
    console.error('错误堆栈:', error.stack);
    return null;
  }
}

// 检查并发送截止时间通知（当截止时间在24小时内时）
// oldDeadline: 旧的截止日期（用于比较是否变动），如果为null则从数据库获取
async function checkAndSendDeadlineNotification(taskId, assigneeId, deadline, hoursBefore = 24, oldDeadline = null) {
  if (!deadline) return;

  try {
    const deadlineDate = new Date(deadline);
    if (isNaN(deadlineDate.getTime())) return;

    const now = new Date();
    const upcomingThreshold = new Date(now.getTime() + hoursBefore * 60 * 60 * 1000);

    // 检查截止时间是否在24小时内
    if (deadlineDate > now && deadlineDate <= upcomingThreshold) {
      // 检查是否已经发送过通知（避免重复通知）
      const dedupeThreshold = new Date(now.getTime() - hoursBefore * 60 * 60 * 1000);
      const [existing] = await db.execute(
        `SELECT id, created_at FROM task_notifications
         WHERE task_id = ?
           AND to_user_id = ?
           AND notification_type = 'deadline_warning'
           AND created_at >= ?
         ORDER BY created_at DESC
         LIMIT 1`,
        [taskId, assigneeId, formatDateTimeForMySQL(dedupeThreshold)]
      );

      // 如果24小时内已发送过通知，则不重复发送
      // 注意：编辑任务时，会在更新前清除旧通知，所以这里不会重复
      if (existing.length > 0) {
        return;
      }

      // 获取任务标题，确保通知消息中包含正确的任务标题
      const [taskRows] = await db.execute(
        'SELECT title FROM tasks WHERE id = ?',
        [taskId]
      );
      const taskTitle = taskRows.length > 0 ? taskRows[0].title : '任务';

      // 发送通知（24小时内未发送过，或截止日期已变动）
      const message = `系统提醒：任务《${taskTitle}》截止时间已更新，将在${hoursBefore}小时内到期，请及时处理。`;
      await createNotification(
        taskId,
        assigneeId,
        assigneeId,
        'deadline_warning',
        message
      );
    }
  } catch (error) {
    console.error('检查截止时间通知失败:', error);
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
    
    // 年份必须是四位整数，例如 2025
    const yearNum = parseInt(year, 10);
    if (!/^\d{4}$/.test(String(year)) || !Number.isInteger(yearNum)) {
      return res.status(400).json({ error: '年份(year)必须是四位整数，例如2025' });
    }

    // 月份必须是 1-12 的整数
    const monthNum = parseInt(month, 10);
    if (!Number.isInteger(monthNum) || monthNum < 1 || monthNum > 12) {
      return res.status(400).json({ error: '月份(month)必须是1-12之间的整数' });
    }
    
    // 计算月份的开始和结束日期
    const startDate = `${yearNum}-${String(monthNum).padStart(2, '0')}-01 00:00:00`;
    const lastDay = new Date(yearNum, monthNum, 0).getDate();
    const endDate = `${yearNum}-${String(monthNum).padStart(2, '0')}-${lastDay} 23:59:59`;
    
    // 获取任务（包含跨月跨度任务：与当月有任意重叠即纳入）
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
        t.attachments,
        t.request_start_time,
        t.request_end_time,
        DATE_FORMAT(COALESCE(t.start_time, t.deadline), '%Y-%m-%d') as task_date
      FROM tasks t
      WHERE t.assignee_id = ?
      AND (
        -- 有明确开始结束时间，且时间段与当月有重叠
        (t.start_time IS NOT NULL AND t.end_time IS NOT NULL AND t.start_time <= ? AND t.end_time >= ?)
        OR DATE(t.start_time) BETWEEN ? AND ?
        OR DATE(t.end_time) BETWEEN ? AND ?
        OR DATE(t.deadline) BETWEEN ? AND ?
      )
      ORDER BY t.start_time, t.priority
    `;
    
    const startDateOnly = `${yearNum}-${String(monthNum).padStart(2, '0')}-01`;
    const endDateOnly = `${yearNum}-${String(monthNum).padStart(2, '0')}-${lastDay}`;
    
    const [tasks] = await db.execute(taskQuery, [
      req.user.id,
      endDate, startDate,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly
    ]);
    
    // 获取个人日志
    // 使用 CONVERT_TZ 将时间转换为北京时间，然后格式化日期
    let logQuery = `
      SELECT 
        pl.id,
        pl.title,
        pl.content,
        pl.category,
        pl.quadrant,
        pl.is_completed,
        pl.created_at,
        pl.images,
        pl.weather,
        pl.keywords,
        pl.location_name,
        pl.location_latitude,
        pl.location_longitude,
        DATE_FORMAT(
          CASE 
            WHEN pl.log_date IS NOT NULL THEN pl.log_date
            ELSE CONVERT_TZ(pl.created_at, @@session.time_zone, '+08:00')
          END,
          '%Y-%m-%d'
        ) as log_date
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
    
    // 填充任务数据（处理跨天任务）
    for (const task of tasks) {
      // 获取多负责人信息
      const [assignees] = await db.execute(
        `SELECT assignee_id, assignee_name, progress_percentage, status FROM task_assignees WHERE task_id = ?`,
        [task.id]
      );

      // 既有开始又有结束：按天展开
      if (task.start_time && task.end_time) {
        const rangeStart = new Date(task.start_time);
        const rangeEnd = new Date(task.end_time);
        const cur = new Date(rangeStart);
        cur.setHours(0, 0, 0, 0);
        rangeEnd.setHours(23, 59, 59, 999);

        while (cur <= rangeEnd) {
          const y = cur.getFullYear();
          const m = String(cur.getMonth() + 1).padStart(2, '0');
          const d = String(cur.getDate()).padStart(2, '0');
          const key = `${y}-${m}-${d}`;

          if (calendar[key]) {
            const exists = calendar[key].tasks.some(t => t.id === task.id);
            if (!exists) {
              const taskObj = {
                id: task.id,
                title: task.title,
                description: task.description,
                status: task.status,
                priority: task.priority,
                color: task.color,
                start_time: formatDateTimeForBeijing(task.start_time),
                end_time: formatDateTimeForBeijing(task.end_time),
                deadline: formatDateTimeForBeijing(task.deadline),
                is_all_day: task.is_all_day,
                assignee_name: task.assignee_name,
                attachments: safeParseJSON(task.attachments) || [],
                request_start_time: formatDateTimeForBeijing(task.request_start_time),
                request_end_time: formatDateTimeForBeijing(task.request_end_time)
              };

              if (assignees.length > 0) {
                taskObj.assignees = assignees;
              }

              calendar[key].tasks.push(taskObj);
              calendar[key].hasData = true;
            }
          }
          cur.setDate(cur.getDate() + 1);
        }
      }
      // 只有截止日期：显示在截止当天
      else if (task.deadline) {
        const deadlineDate = new Date(task.deadline);
        const y = deadlineDate.getFullYear();
        const m = String(deadlineDate.getMonth() + 1).padStart(2, '0');
        const d = String(deadlineDate.getDate()).padStart(2, '0');
        const key = `${y}-${m}-${d}`;
        if (calendar[key]) {
          const exists = calendar[key].tasks.some(t => t.id === task.id);
          if (!exists) {
            const taskObj = {
              id: task.id,
              title: task.title,
              description: task.description,
              status: task.status,
              priority: task.priority,
              color: task.color,
              start_time: formatDateTimeForBeijing(task.start_time),
              end_time: formatDateTimeForBeijing(task.end_time),
              deadline: formatDateTimeForBeijing(task.deadline),
              is_all_day: task.is_all_day,
              assignee_name: task.assignee_name,
              attachments: safeParseJSON(task.attachments) || [],
              request_start_time: formatDateTimeForBeijing(task.request_start_time),
              request_end_time: formatDateTimeForBeijing(task.request_end_time)
            };

            if (assignees.length > 0) {
              taskObj.assignees = assignees;
            }

            calendar[key].tasks.push(taskObj);
            calendar[key].hasData = true;
          }
        }
      }
      // 只有开始（或SQL提供的 task_date）
      else if (task.task_date) {
        const key = task.task_date;
        if (calendar[key]) {
          const exists = calendar[key].tasks.some(t => t.id === task.id);
          if (!exists) {
            const taskObj = {
              id: task.id,
              title: task.title,
              description: task.description,
              status: task.status,
              priority: task.priority,
              color: task.color,
              start_time: formatDateTimeForBeijing(task.start_time),
              end_time: formatDateTimeForBeijing(task.end_time),
              deadline: formatDateTimeForBeijing(task.deadline),
              is_all_day: task.is_all_day,
              assignee_name: task.assignee_name,
              attachments: safeParseJSON(task.attachments) || [],
              request_start_time: formatDateTimeForBeijing(task.request_start_time),
              request_end_time: formatDateTimeForBeijing(task.request_end_time)
            };

            if (assignees.length > 0) {
              taskObj.assignees = assignees;
            }

            calendar[key].tasks.push(taskObj);
            calendar[key].hasData = true;
          }
        }
      }
    }
    
    // 填充日志数据
    const processedLogs = await Promise.all(logs.map(async log => {
      // 如果有经纬度信息，转换为中文地址
      let locationAddress = null;
      if (log.location_latitude && log.location_longitude) {
        locationAddress = await convertToAddress(log.location_latitude, log.location_longitude);
      }
      return { ...log, location_address: locationAddress };
    }));

    processedLogs.forEach(log => {
      if (log.log_date) {
        const dateKey = log.log_date;
        console.log(`  日志 "${log.title}" 的日期: ${dateKey}, 日历中是否存在: ${!!calendar[dateKey]}`);
        if (calendar[dateKey]) {
          const images = safeParseJSON(log.images) || [];
          const keywords = normalizeKeywordList(log.keywords);
          calendar[dateKey].logs.push({
            id: log.id,
            title: log.title,
            content: log.content,
            category: log.category,
            quadrant: log.quadrant,
            is_completed: log.is_completed,
            created_at: formatDateTimeForBeijing(log.created_at),
            log_date: log.log_date,
            weather: log.weather,
            keywords,
            images,
            location_name: log.location_name,
            location_latitude: log.location_latitude,
            location_longitude: log.location_longitude,
            location_address: log.location_address
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

    // 年份必须是四位整数，例如 2025
    const yearNum = parseInt(year, 10);
    if (!/^\d{4}$/.test(String(year)) || !Number.isInteger(yearNum)) {
      return res.status(400).json({ error: '年份(year)必须是四位整数，例如2025' });
    }

    // 月份必须是 1-12 的整数
    const monthNum = parseInt(month, 10);
    if (!Number.isInteger(monthNum) || monthNum < 1 || monthNum > 12) {
      return res.status(400).json({ error: '月份(month)必须是1-12之间的整数' });
    }
    
    // 计算月份的开始和结束日期
    const startDate = `${yearNum}-${String(monthNum).padStart(2, '0')}-01 00:00:00`;
    const lastDay = new Date(yearNum, monthNum, 0).getDate();
    const endDate = `${yearNum}-${String(monthNum).padStart(2, '0')}-${lastDay} 23:59:59`;
    
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
        t.attachments,
        t.request_start_time,
        t.request_end_time,
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
    
    const startDateOnly = `${yearNum}-${String(monthNum).padStart(2, '0')}-01`;
    const endDateOnly = `${yearNum}-${String(monthNum).padStart(2, '0')}-${lastDay}`;
    
    const [tasks] = await db.execute(taskQuery, [
      userId, 
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly,
      startDateOnly, endDateOnly
    ]);
    
    // 获取个人日志
    // 使用 CONVERT_TZ 将时间转换为北京时间，然后格式化日期
    let logQuery = `
      SELECT 
        pl.id,
        pl.title,
        pl.content,
        pl.category,
        pl.quadrant,
        pl.is_completed,
        pl.created_at,
        pl.images,
        pl.weather,
        pl.keywords,
        pl.location_name,
        pl.location_latitude,
        pl.location_longitude,
        DATE_FORMAT(
          CASE 
            WHEN pl.log_date IS NOT NULL THEN pl.log_date
            ELSE CONVERT_TZ(pl.created_at, @@session.time_zone, '+08:00')
          END,
          '%Y-%m-%d'
        ) as log_date
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
    
    // 处理日志数据，添加地址转换
    const processedLogs = await Promise.all(logs.map(async log => {
      // 如果有经纬度信息，转换为中文地址
      let locationAddress = null;
      if (log.location_latitude && log.location_longitude) {
        locationAddress = await convertToAddress(log.location_latitude, log.location_longitude);
      }

      return {
        id: log.id,
        title: log.title,
        content: log.content,
        category: log.category,
        quadrant: log.quadrant,
        isCompleted: log.is_completed === 1,
        date: log.log_date,
        createdAt: log.created_at,
        weather: log.weather,
        keywords: normalizeKeywordList(log.keywords),
        images: safeParseJSON(log.images) || [],
        location_name: log.location_name,
        location_latitude: log.location_latitude,
        location_longitude: log.location_longitude
      };
    }));
    
    // 获取每个任务的多负责人信息
      tasks: await Promise.all(tasks.map(async (task) => {
        const [assignees] = await db.execute(
          `SELECT assignee_id, assignee_name, progress_percentage, status FROM task_assignees WHERE task_id = ?`,
          [task.id]
        );

        const taskObj = {
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
          date: task.task_date,
          attachments: safeParseJSON(task.attachments) || [],
          requestStartTime: task.request_start_time,
          requestEndTime: task.request_end_time
        };

        if (assignees.length > 0) {
          taskObj.assignees = assignees;
        }

        return taskObj;
      })),

    // 返回简化的数据格式
    res.json({
      month: `${year}-${String(month).padStart(2, '0')}`,
      userId: userId,
      logs: processedLogs,
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
        date: task.task_date,
        attachments: safeParseJSON(task.attachments) || []
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

    // 校验日期格式与取值范围（年份四位，月份 1-12，日期根据月份和闰年规则）
    const dateMatch = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(String(date));
    if (!dateMatch) {
      return res.status(400).json({ error: '日期(date)格式必须为YYYY-MM-DD，例如2025-01-15' });
    }

    const yearNum = parseInt(dateMatch[1], 10);
    const monthNum = parseInt(dateMatch[2], 10);
    const dayNum = parseInt(dateMatch[3], 10);

    if (!Number.isInteger(yearNum)) {
      return res.status(400).json({ error: '年份必须是四位整数，例如2025' });
    }

    if (!Number.isInteger(monthNum) || monthNum < 1 || monthNum > 12) {
      return res.status(400).json({ error: '月份必须是1-12之间的整数' });
    }

    // 根据月份和闰年规则检查日期
    const isLeapYear = (yearNum % 4 === 0 && yearNum % 100 !== 0) || (yearNum % 400 === 0);
    let maxDay;
    if ([1, 3, 5, 7, 8, 10, 12].includes(monthNum)) {
      maxDay = 31;
    } else if (monthNum === 2) {
      maxDay = isLeapYear ? 29 : 28;
    } else {
      maxDay = 30;
    }

    if (!Number.isInteger(dayNum) || dayNum < 1 || dayNum > maxDay) {
      return res.status(400).json({ error: `日期(day)不合法：${yearNum}年${monthNum}月应在1-${maxDay}号之间` });
    }
    
    // 获取该日期的所有任务（包括跨日任务，确保覆盖当天）
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
        (t.start_time IS NOT NULL AND t.end_time IS NOT NULL AND DATE(t.start_time) <= ? AND DATE(t.end_time) >= ?)
        OR (t.start_time IS NOT NULL AND DATE(t.start_time) = ?)
        OR (t.end_time IS NOT NULL AND DATE(t.end_time) = ?)
        OR (t.deadline IS NOT NULL AND DATE(t.deadline) = ?)
      )
      ORDER BY t.start_time, t.priority
    `;
    
    const [tasks] = await db.execute(taskQuery, [
      req.user.id,
      date, date,
      date,
      date,
      date
    ]);
    
    // 获取该日期的所有日志
    let logQuery = `
      SELECT 
        pl.*,
        t.title as task_title
      FROM personal_logs pl
      LEFT JOIN tasks t ON pl.related_task_id = t.id
      WHERE pl.user_id = ?
      AND DATE(
        COALESCE(
          pl.log_date,
          CONVERT_TZ(pl.created_at, @@session.time_zone, '+08:00')
        )
      ) = ?
      ORDER BY pl.created_at DESC
    `;
    
    const [logs] = await db.execute(logQuery, [
      req.user.id,
      date
    ]);
    
    // 处理日志数据，添加地址转换
    const processedLogs = await Promise.all(logs.map(async l => {
      // 如果有经纬度信息，转换为中文地址
      let locationAddress = null;
      if (l.location_latitude && l.location_longitude) {
        locationAddress = await convertToAddress(l.location_latitude, l.location_longitude);
      }

      const images = safeParseJSON(l.images) || [];
      const keywords = normalizeKeywordList(l.keywords);
      return {
        id: l.id,
        title: l.title,
        content: l.content,
        category: l.category,
        quadrant: l.quadrant,
        is_completed: l.is_completed,
        created_at: formatDateTimeForBeijing(l.created_at),
        log_date: l.log_date
          ? formatDateOnlyForBeijing(l.log_date)
          : formatDateOnlyForBeijing(l.created_at),
        weather: l.weather,
        keywords,
        images,
        location_name: l.location_name,
        location_latitude: l.location_latitude,
        location_longitude: l.location_longitude,
        location_address: locationAddress
      };
    }));

    console.log(`[日期详情] 用户 ${req.user.id} 请求 ${date} 的数据: ${tasks.length} 个任务, ${logs.length} 个日志`);
    
    // 获取每个任务的多负责人信息
    const tasksWithAssignees = await Promise.all(tasks.map(async (t) => {
      const [assignees] = await db.execute(
        `SELECT assignee_id, assignee_name, progress_percentage, status FROM task_assignees WHERE task_id = ?`,
        [t.id]
      );

      const taskObj = {
        id: t.id,
        title: t.title,
        description: t.description,
        status: t.status,
        priority: t.priority,
        color: t.color,
        start_time: formatDateTimeForBeijing(t.start_time),
        end_time: formatDateTimeForBeijing(t.end_time),
        deadline: formatDateTimeForBeijing(t.deadline),
        is_all_day: t.is_all_day,
        assignee_name: t.assignee_name,
        department_name: t.department_name,
        creator_name: t.creator_name,
        attachments: safeParseJSON(t.attachments) || [],
        request_start_time: formatDateTimeForBeijing(t.request_start_time),
        request_end_time: formatDateTimeForBeijing(t.request_end_time)
      };

      if (assignees.length > 0) {
        taskObj.assignees = assignees;
      }

      return taskObj;
    }));

    res.json({
      date: date,
      tasks: tasksWithAssignees,
      logs: logs.map(l => {
        const images = safeParseJSON(l.images) || [];
        const keywords = normalizeKeywordList(l.keywords);
        return {
          id: l.id,
          title: l.title,
          content: l.content,
          category: l.category,
          quadrant: l.quadrant,
          is_completed: l.is_completed,
          created_at: formatDateTimeForBeijing(l.created_at),
          log_date: l.log_date
            ? formatDateOnlyForBeijing(l.log_date)
            : formatDateOnlyForBeijing(l.created_at),
          weather: l.weather,
          keywords,
          images,
          location_name: l.location_name,
          location_latitude: l.location_latitude,
          location_longitude: l.location_longitude
        };
      }),
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

// 计算多负责人任务的总进度
async function calculateMultiAssigneeTaskProgress(taskId) {
  try {
    // 获取所有分配给该任务的负责人
    const [assignees] = await db.execute(
      `SELECT progress_percentage FROM task_assignees WHERE task_id = ?`,
      [taskId]
    );

    if (assignees.length === 0) {
      return 0; // 如果没有分配负责人，返回0进度
    }

    // 计算平均进度
    const totalProgress = assignees.reduce((sum, assignee) => sum + (assignee.progress_percentage || 0), 0);
    const averageProgress = totalProgress / assignees.length;

    return Math.round(averageProgress);
  } catch (error) {
    console.error('计算多负责人任务进度错误:', error);
    return 0;
  }
}

// 更新多负责人任务的总体进度
async function updateMultiAssigneeTaskProgress(taskId) {
  try {
    const overallProgress = await calculateMultiAssigneeTaskProgress(taskId);

    // 更新主任务的总体进度
    await db.execute(
      `UPDATE tasks SET progress_percentage = ? WHERE id = ?`,
      [overallProgress, taskId]
    );

    // 根据总体进度更新任务状态
    let newStatus = 'pending';
    if (overallProgress >= 100) {
      newStatus = 'completed';
    } else if (overallProgress > 0) {
      newStatus = 'in_progress';
    }

    await db.execute(
      `UPDATE tasks SET status = ? WHERE id = ?`,
      [newStatus, taskId]
    );

    return overallProgress;
  } catch (error) {
    console.error('更新多负责人任务进度错误:', error);
    throw error;
  }
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

    // 确保confidence_score是数字类型（MySQL DECIMAL可能返回字符串）
    if (typeof record.confidence_score === 'string') {
      record.confidence_score = parseFloat(record.confidence_score) || 0.5;
    }
    if (record.confidence_score == null || isNaN(record.confidence_score)) {
      record.confidence_score = 0.5;
    }

    // 从ai_analysis中提取strengths和weaknesses（如果存在）以便前端直接使用
    if (record.ai_analysis && typeof record.ai_analysis === 'object') {
      if (record.ai_analysis.strengths) {
        record.strengths = record.ai_analysis.strengths;
      }
      if (record.ai_analysis.weaknesses) {
        record.weaknesses = record.ai_analysis.weaknesses;
      }
    }

    res.json(record);
  } catch (error) {
    console.error('获取最新MBTI记录错误:', error);
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
      // 清理 personal_info 对象，将 undefined 转换为 null
      const cleanedPersonalInfo = {};
      for (const [key, value] of Object.entries(updateData.personal_info)) {
        cleanedPersonalInfo[key] = value === undefined ? null : value;
      }
      updateValues.push(JSON.stringify(cleanedPersonalInfo));
    }
    if (updateData.confidence_score !== undefined) {
      updateFields.push('confidence_score = ?');
      updateValues.push(updateData.confidence_score === undefined ? null : updateData.confidence_score);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: '没有提供更新数据' });
    }

    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    // 确保 id 和 userId 不是 undefined
    const safeId = id || null;
    const safeUserId = userId || null;
    updateValues.push(safeId, safeUserId);

    // 确保所有值都不是 undefined
    const safeUpdateValues = updateValues.map(v => v === undefined ? null : v);

    await db.execute(
      `UPDATE mbti_records SET ${updateFields.join(', ')}
       WHERE id = ? AND user_id = ?`,
      safeUpdateValues
    );

    // 记录系统日志 - 确保所有参数都不是 undefined，user_name 不能为 null
    // 即使日志插入失败，也不影响主操作的成功
    try {
    await db.execute(
      `INSERT INTO system_logs (id, user_id, user_name, action, description, category)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        `log-${Date.now()}`,
          safeUserId || null,
          req.user?.name || '未知用户',
        'update_mbti_record',
          `更新MBTI记录: ${safeId || 'unknown'}`,
        'mbti'
        ].map(v => v === undefined ? null : v)
    );
    } catch (logError) {
      // 记录日志错误，但不影响主操作
      console.error('记录系统日志失败:', logError);
    }

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
      `INSERT INTO logs (id, user_id, user_name, action, description, category)
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



// ==================== 管理员总览 API ====================

// 搜索员工（支持按名字、部门、职位搜索）
app.get('/api/admin/search-users', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { keyword } = req.query;
    
    let query = `
      SELECT u.id, u.username, u.name, u.position, u.role, u.department_id,
             d.name as department_name, u.parent_id, p.name as parent_name,
             u.created_at, u.last_login_at
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      LEFT JOIN users p ON u.parent_id = p.id
      WHERE u.is_active = TRUE
    `;
    let params = [];
    
    if (keyword && keyword.trim()) {
      const searchKeyword = `%${keyword.trim()}%`;
      query += ` AND (
        u.name LIKE ? OR 
        u.position LIKE ? OR 
        d.name LIKE ? OR
        u.username LIKE ?
      )`;
      params.push(searchKeyword, searchKeyword, searchKeyword, searchKeyword);
    }
    
    query += ' ORDER BY u.role, u.name';
    
    const [rows] = await db.execute(query, params);
    res.json(rows);
  } catch (error) {
    console.error('搜索员工错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取员工统计数据（每天/每周/每月/全部任务完成情况）
app.get('/api/admin/user-statistics', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { userId, period } = req.query; // period: 'daily', 'weekly', 'monthly', 'all'
    
    if (!userId) {
      return res.status(400).json({ error: '请提供userId参数' });
    }
    
    let startDate, endDate;
    const now = new Date();
    
    switch (period) {
      case 'daily':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
        break;
      case 'weekly':
        const dayOfWeek = now.getDay();
        const diff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1); // 周一
        startDate = new Date(now.getFullYear(), now.getMonth(), diff);
        endDate = new Date(now.getFullYear(), now.getMonth(), diff + 6, 23, 59, 59);
        break;
      case 'monthly':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
        break;
      case 'all':
        // 获取所有任务，不限制时间范围
        startDate = null;
        endDate = null;
        break;
      default:
        return res.status(400).json({ error: 'period参数必须是daily、weekly、monthly或all' });
    }
    
    // 获取任务统计
    let taskQuery, queryParams;

    if (period === 'all') {
      // 获取所有任务的统计
      taskQuery = `
        SELECT
          COUNT(*) as total_tasks,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_tasks,
          SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_tasks,
          SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_tasks
        FROM tasks
        WHERE assignee_id = ?
      `;
      queryParams = [userId];
    } else {
      // 获取指定时间范围内的任务统计
      // 对于今日/本周任务，将非"已完成"状态的任务归类为"进行中"
      taskQuery = `
        SELECT
          COUNT(*) as total_tasks,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
          SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_tasks,
          SUM(CASE WHEN status = 'completed' THEN 0 ELSE 1 END) as in_progress_tasks
        FROM tasks
        WHERE assignee_id = ?
        AND (
          (start_time >= ? AND start_time <= ?) OR
          (end_time >= ? AND end_time <= ?) OR
          (start_time <= ? AND end_time >= ?)
        )
      `;
      queryParams = [
        userId,
        startDate, endDate,
        startDate, endDate,
        startDate, endDate
      ];
    }

    const [taskStats] = await db.execute(taskQuery, queryParams);
    
    const stats = taskStats[0] || {};
    const total = parseInt(stats.total_tasks) || 0;
    const completed = parseInt(stats.completed_tasks) || 0;
    const completionRate = total > 0 ? (completed / total * 100).toFixed(1) : '0.0';
    
    let responseData;

    if (period === 'all') {
      // 对于全部任务，保持原有的状态分类
      responseData = {
        period,
        totalTasks: total,
        completedTasks: completed,
        pendingTasks: parseInt(stats.pending_tasks) || 0,
        inProgressTasks: parseInt(stats.in_progress_tasks) || 0,
        cancelledTasks: parseInt(stats.cancelled_tasks) || 0,
        completionRate: parseFloat(completionRate),
      };
    } else {
      // 对于今日/本周任务，将非"已完成"状态的任务归类为"进行中"
      const inProgress = total - completed - (parseInt(stats.cancelled_tasks) || 0);
      responseData = {
        period,
        totalTasks: total,
        completedTasks: completed,
        pendingTasks: 0, // 对于今日/本周任务，不显示pending状态
        inProgressTasks: inProgress, // 所有非"已完成"且非"已取消"的任务都算作"进行中"
        cancelledTasks: parseInt(stats.cancelled_tasks) || 0,
        completionRate: parseFloat(completionRate),
      };
    }

    // 只有在不是'all'的情况下才添加日期范围
    if (period !== 'all' && startDate && endDate) {
      responseData.startDate = startDate.toISOString();
      responseData.endDate = endDate.toISOString();
    }

    res.json(responseData);
  } catch (error) {
    console.error('获取员工统计数据错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取员工日志（按日期）
app.get('/api/admin/user-logs', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { userId, date } = req.query; // date格式: YYYY-MM-DD
    
    if (!userId) {
      return res.status(400).json({ error: '请提供userId参数' });
    }
    
    let query = `
      SELECT pl.*, t.title as task_title
      FROM personal_logs pl
      LEFT JOIN tasks t ON pl.related_task_id = t.id
      WHERE pl.user_id = ?
    `;
    let params = [userId];
    
    if (date) {
      query += ' AND DATE(pl.created_at) = ?';
      params.push(date);
    }
    
    query += ' ORDER BY pl.created_at DESC';
    
    const [logs] = await db.execute(query, params);
    res.json(logs);
  } catch (error) {
    console.error('获取员工日志错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取员工MBTI测试历史
app.get('/api/admin/user-mbti-history', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({ error: '请提供userId参数' });
    }
    
    const query = `
      SELECT id, mbti_type, test_date, test_scores, personality_traits, 
             confidence_score, created_at
      FROM mbti_records
      WHERE user_id = ? AND is_active = TRUE
      ORDER BY test_date DESC
    `;
    
    const [records] = await db.execute(query, [userId]);
    res.json(records);
  } catch (error) {
    console.error('获取员工MBTI历史错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取公司所有任务（可按日期筛选）
app.get('/api/admin/all-tasks', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { date } = req.query; // date格式: YYYY-MM-DD
    
    let query = `
      SELECT t.*, d.name as department_name, u.name as creator_name,
             assignee.name as assignee_name
      FROM tasks t
      LEFT JOIN departments d ON t.department_id = d.id
      LEFT JOIN users u ON t.created_by = u.id
      LEFT JOIN users assignee ON t.assignee_id = assignee.id
      WHERE 1=1
    `;
    let params = [];
    
    if (date) {
      query += ` AND (
        (t.start_time IS NOT NULL AND t.end_time IS NOT NULL AND DATE(t.start_time) <= ? AND DATE(t.end_time) >= ?)
        OR (t.start_time IS NOT NULL AND DATE(t.start_time) = ?)
        OR (t.end_time IS NOT NULL AND DATE(t.end_time) = ?)
        OR (t.deadline IS NOT NULL AND DATE(t.deadline) = ?)
      )`;
      params.push(date, date, date, date, date);
    }
    
    query += ' ORDER BY t.created_at DESC';
    
    const [tasks] = await db.execute(query, params);
    
    // 处理时区转换
    const processedTasks = tasks.map(task => {
      const processed = { ...task };
      if (task.start_time) processed.start_time = new Date(task.start_time).toISOString();
      if (task.end_time) processed.end_time = new Date(task.end_time).toISOString();
      if (task.deadline) processed.deadline = new Date(task.deadline).toISOString();
      if (task.created_at) processed.created_at = new Date(task.created_at).toISOString();
      if (task.completed_at) processed.completed_at = new Date(task.completed_at).toISOString();
      return processed;
    });
    
    res.json(processedTasks);
  } catch (error) {
    console.error('获取公司所有任务错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取任务树（完整层级结构）
app.get('/api/admin/task-tree', authenticateToken, checkPermission(['admin']), async (req, res) => {
  try {
    const { taskId } = req.query;
    
    if (!taskId) {
      return res.status(400).json({ error: '请提供taskId参数' });
    }
    
    // 递归获取任务树
    async function getTaskTree(currentTaskId) {
      // 获取当前任务
      const [tasks] = await db.execute(
        `SELECT t.*, d.name as department_name, u.name as creator_name,
                assignee.name as assignee_name
         FROM tasks t
         LEFT JOIN departments d ON t.department_id = d.id
         LEFT JOIN users u ON t.created_by = u.id
         LEFT JOIN users assignee ON t.assignee_id = assignee.id
         WHERE t.id = ?`,
        [currentTaskId]
      );
      
      if (tasks.length === 0) {
        return null;
      }
      
      const task = tasks[0];
      
      // 获取所有子任务
      const [subtasks] = await db.execute(
        `SELECT t.*, d.name as department_name, u.name as creator_name,
                assignee.name as assignee_name
         FROM tasks t
         LEFT JOIN departments d ON t.department_id = d.id
         LEFT JOIN users u ON t.created_by = u.id
         LEFT JOIN users assignee ON t.assignee_id = assignee.id
         WHERE t.parent_task_id = ?
         ORDER BY t.created_at ASC`,
        [currentTaskId]
      );
      
      // 递归获取每个子任务的子树
      const subtaskTrees = await Promise.all(
        subtasks.map(async (subtask) => await getTaskTree(subtask.id))
      );
      
      // 如果有父任务，继续向上查找
      let parentTask = null;
      if (task.parent_task_id) {
        parentTask = await getTaskTree(task.parent_task_id);
      }
      
      return {
        ...task,
        parentTask,
        subtasks: subtaskTrees.filter(t => t !== null),
      };
    }
    
    const taskTree = await getTaskTree(taskId);
    
    if (!taskTree) {
      return res.status(404).json({ error: '任务不存在' });
    }
    
    // 找到根任务（最顶层的父任务）
    let rootTask = taskTree;
    while (rootTask.parentTask) {
      rootTask = rootTask.parentTask;
    }
    
    res.json(rootTask);
  } catch (error) {
    console.error('获取任务树错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 数据埋点：记录用户操作
app.post('/api/admin/tracking', authenticateToken, async (req, res) => {
  try {
    const { action, category, metadata } = req.body;
    const userId = req.user.id;
    
    // 记录到系统日志表
    const logId = require('crypto').randomUUID();
    await db.execute(
      `INSERT INTO system_logs (id, user_id, user_name, action, description, category, metadata, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        logId,
        userId,
        req.user.name || req.user.username,
        action || 'unknown',
        metadata?.description || '',
        category || 'admin_tracking',
        metadata ? JSON.stringify(metadata) : null
      ]
    );
    
    res.json({ success: true, logId });
  } catch (error) {
    console.error('数据埋点错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 协同专注：发送“陪我专注”邀请通知
app.post('/api/notify/invite-focus', authenticateToken, async (req, res) => {
  try {
    const { senderId, senderName, targetUserIds } = req.body || {};
    const currentUserId = req.user.id;

    if (!Array.isArray(targetUserIds) || targetUserIds.length === 0) {
      return res.status(400).json({ error: 'targetUserIds 不能为空' });
    }

    // 防止伪造 senderId，必须与当前登录用户一致（或者未传则使用当前用户）
    if (senderId && senderId !== currentUserId) {
      return res.status(403).json({ error: '无权以其它用户身份发送邀请' });
    }

    const safeSenderName = senderName || req.user.name || req.user.username || '一位小伙伴';

    // 只给真实存在且处于激活状态的用户发送
    const [targets] = await db.execute(
      `SELECT id, name, username 
       FROM users 
       WHERE id IN (${targetUserIds.map(() => '?').join(',')})
         AND is_active = TRUE`,
      targetUserIds
    );

    if (!targets || targets.length === 0) {
      return res.status(400).json({ error: '未找到可邀请的目标用户' });
    }

    const clientIp =
      (req.headers['x-forwarded-for'] &&
        String(req.headers['x-forwarded-for']).split(',')[0].trim()) ||
      req.ip ||
      null;

    const metaBase = {
      senderId: currentUserId,
      senderName: safeSenderName,
      targetUserIds,
      clientIp,
      source: 'pomodoro_focus_collaboration',
    };

    let successCount = 0;
    // 为每个目标用户创建通知（使用 createNotification 函数，写入 task_notifications 表）
    console.log('📱 [协同专注通知]');
    console.log(`   发送者: ${safeSenderName} (${currentUserId})`);
    console.log(`   目标用户数: ${targets.length}`);
    console.log(`   目标用户IDs: ${targets.map(t => t.id).join(', ')}`);
    
    const notificationMessage = `${safeSenderName}要开始专注了，你还在摸鱼吗？`;
    // 兼容旧代码中可能使用的 message 变量，避免 ReferenceError
    const message = notificationMessage;
    console.log(`   通知内容: "${notificationMessage}"`);
    console.log(`   时间: ${new Date().toISOString()}`);
    
    for (const target of targets) {
      const targetName = target.name || target.username || '未知用户';
      const targetId = target.id;
      
      console.log(`   正在为用户 ${targetName} (${targetId}) 创建通知...`);

      // 1）去重：同一发送者 -> 同一接收者 的协同专注邀请，只保留一条“最新”通知
      //    删除该组合下历史上所有 focus_invite 通知（无论已读/未读），避免叠加多条
      await db.execute(
        `DELETE FROM task_notifications
         WHERE from_user_id = ?
           AND to_user_id = ?
         AND notification_type = 'focus_invite'`,
        [currentUserId, targetId]
      );
      
      // 2）真正创建新的通知（focus_invite 类型，task_id 为 null）
      const notificationId = await createNotification(
        null, // task_id 为 null（focus_invite 类型不需要任务关联）
        currentUserId,
        targetId,
        'focus_invite',
        notificationMessage
      );

      if (notificationId) {
        successCount++;
        console.log(`   ✅ 通知创建成功: ${notificationId} (用户: ${targetName})`);
      } else {
        console.error(`   ❌ 通知创建失败 (用户: ${targetName})`);
      }

      // 3）同时写入系统日志，便于后续在“通知/日志”中展示
      const logId = require('crypto').randomUUID();
      await db.execute(
        `INSERT INTO system_logs (id, user_id, user_name, action, description, category, metadata, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          logId,
          // 日志归属目标用户，方便其在自己的日志列表中查看
          targetId,
          targetName,
          'invite_focus',
          notificationMessage,
          'focus_invite',
          JSON.stringify({
            ...metaBase,
            targetId,
            targetName,
            notificationId, // 关联的通知ID
          }),
        ]
      );
    }

    res.json({
      success: true,
      sent: successCount,
    });
  } catch (error) {
    console.error('发送协同专注邀请错误:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 启动服务器
async function startServer() {
  await initDatabase();
  // 启动时自动迁移旧的明文密码为 bcrypt 哈希（只迁移非 bcrypt 格式）
  try {
    const [plainRows] = await db.execute(
      `SELECT id, password FROM users WHERE password NOT LIKE '$2%'`
    );
    if (plainRows.length > 0) {
      console.log(`🔒 检测到 ${plainRows.length} 条明文密码，正在迁移为 bcrypt...`);
      for (const row of plainRows) {
        if (row.password && typeof row.password === 'string') {
          const hashed = await hashPassword(row.password);
          await db.execute('UPDATE users SET password = ? WHERE id = ?', [hashed, row.id]);
        }
      }
      console.log('🔒 明文密码迁移完成。');
    }
  } catch (e) {
    console.error('明文密码迁移失败:', e);
  }

  // 将管理员账号密码重置为 admin123（仅用户名为 admin 或 id 为 admin-001）
  try {
    const adminHash = await hashPassword('admin123');
    const [result] = await db.execute(
      `UPDATE users SET password = ? WHERE username = 'admin' OR id = 'admin-001'`,
      [adminHash]
    );
    if (result?.affectedRows > 0) {
      console.log(`🔐 管理员密码已重置为 admin123（用户名=admin 或 id=admin-001），rows=${result.affectedRows}`);
    }
  } catch (e) {
    console.error('重置管理员密码失败:', e);
  }

  // 读取证书文件（请确保 private.key 和 certificate.crt 位于启动目录）
  const privateKey = fs.readFileSync('private.key', 'utf8');
  const certificate = fs.readFileSync('certificate.crt', 'utf8');
  const credentials = { key: privateKey, cert: certificate };

  // 创建 HTTPS 服务器
  const httpsServer = https.createServer(credentials, app);

  httpsServer.listen(PORT, '0.0.0.0', () => {
    console.log(`HTTPS Server running on port ${PORT}`);
    console.log(`API地址: https://localhost:${PORT}/api`);
    console.log(`Swagger UI: https://localhost:${PORT}/swagger`);
    console.log(`Web管理端: https://localhost:${PORT}/web_admin`);
    console.log(`\n📱 手机访问地址（同一WiFi网络）:`);
    console.log(`   请使用电脑的IP地址: https://[电脑IP]:${PORT}/api`);
    console.log(`\n📱 测试账户:`);
    console.log(`   管理员: admin / admin123`);
    console.log(`   创始人: founder1 / founder123, founder2 / founder123`);
    console.log(`   人事总监: hr_head / hr123`);
    console.log(`   财务总监: finance_head / finance123`);
    console.log(`   宣传总监: marketing_head / marketing123`);
    console.log(`   团队长: hr_team1 / hrteam123, finance_team1 / financeteam123, marketing_team1 / marketingteam123`);
    console.log(`   员工: hr_emp1 / hremp123, finance_emp1 / financeemp123, marketing_emp1 / marketingemp123`);
    console.log(`\n🌐 访问地址:`);
    console.log(`   API接口: https://localhost:${PORT}/api`);
    console.log(`   Swagger UI: https://localhost:${PORT}/swagger`);
    console.log(`   Web管理: https://localhost:${PORT}/web_admin`);
  });
}

startServer().catch(console.error);

// ================= AI 文本分析（基础版） =================
// 提取关键词和词频统计
app.post('/api/ai/analyze-log', async (req, res) => {
  try {
    // 检查请求体是否存在
    if (!req.body || typeof req.body !== 'object') {
      return res.status(400).json({ error: '请求体不能为空' });
    }

    const { text, topK = 20 } = req.body;
    
    // 验证text参数
    if (text === undefined || text === null) {
      return res.status(400).json({ error: 'text 参数不能为空' });
    }
    if (typeof text !== 'string') {
      return res.status(400).json({ error: 'text 参数必须是字符串类型' });
    }
    if (text.trim().length === 0) {
      return res.status(400).json({ error: 'text 参数不能是空白字符串' });
    }

    // 验证topK参数
    let parsedTopK = parseInt(topK);
    if (isNaN(parsedTopK) || parsedTopK <= 0 || parsedTopK > 100) {
      parsedTopK = 20; // 默认值
    }

    // 临时使用简单分词（等segmentit安装后恢复）
    const tokens = text.split(/[\s\n\r\t,，。！？；：""''（）()【】\[\]{}]+/)
      .filter(w => w && w.trim().length > 1);
    
    // 处理没有有效分词的情况
    if (tokens.length === 0) {
      return res.json({
        keywords: [],
        wordFrequencies: []
      });
    }

    const freqMap = {};
    for (const w of tokens) {
      freqMap[w] = (freqMap[w] || 0) + 1;
    }
    const wordFrequencies = Object.entries(freqMap)
      .map(([word, count]) => ({ word, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, parsedTopK);

    // 用频次代替简易"权重"，并归一化一个权重字段
    const maxCount = wordFrequencies[0].count;
    const keywords = wordFrequencies.map(x => ({ word: x.word, weight: x.count / maxCount }));

    return res.json({
      keywords,
      wordFrequencies
    });
  } catch (e) {
    console.error('AI分析失败:', e);
    return res.status(500).json({ error: 'AI分析失败' });
  }
});

// 基于个人日志的一键分析（需登录）- 使用DeepSeek API智能分析
// 支持日期范围选择：today（今日）、last7days（最近7天）、all（全部历史）
app.get('/api/ai/analyze-today', authenticateToken, async (req, res) => {
  try {
    const { topK = 20, range = 'today', date } = req.query;
    const userId = req.user.id;

    let rows = [];
    let usedRange = range;
    let selectedDate = null;
    const limitCount = 100; // 默认限制数量，避免数据过大

    if (date) {
      // 如果传入了指定日期，则优先分析该日期
      const sanitizedDate = date.toString().split('T')[0];
      const parsedDate = new Date(sanitizedDate);
      if (isNaN(parsedDate.getTime())) {
        return res.status(400).json({ error: '无效的日期参数' });
      }
      const [dateRows] = await db.execute(
        `SELECT
           COALESCE(log_title, title) as title,
           COALESCE(log_content, content) as content
         FROM personal_logs
         WHERE user_id = ?
           AND (
             (log_date IS NOT NULL AND DATE(log_date) = ?)
             OR (log_date IS NULL AND DATE(created_at) = ?)
           )
         ORDER BY COALESCE(log_date, created_at) DESC`,
        [userId, sanitizedDate, sanitizedDate]
      );
      rows = dateRows;
      usedRange = 'date';
      selectedDate = sanitizedDate;
    } else if (range === 'today') {
      const [todayRows] = await db.execute(
      `SELECT
         COALESCE(log_title, title) as title,
         COALESCE(log_content, content) as content
       FROM personal_logs
       WHERE user_id = ?
         AND (
           (log_date IS NOT NULL AND DATE(log_date) = CURDATE())
           OR (log_date IS NULL AND DATE(created_at) = CURDATE())
           )
         ORDER BY COALESCE(log_date, created_at) DESC`,
      [userId]
    );
      rows = todayRows;
      usedRange = 'today';
    } else if (range === 'last7days') {
      const [rows7] = await db.execute(
        `SELECT
           COALESCE(log_title, title) as title,
           COALESCE(log_content, content) as content
         FROM personal_logs
         WHERE user_id = ?
           AND (
             (log_date IS NOT NULL AND log_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY))
             OR (log_date IS NULL AND created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY))
           )
         ORDER BY COALESCE(log_date, created_at) DESC
         LIMIT ${parseInt(limitCount)}`,
        [userId]
      );
      rows = rows7;
      usedRange = 'last7days';
    } else if (range === 'all') {
      const [allRows] = await db.execute(
        `SELECT
           COALESCE(log_title, title) as title,
           COALESCE(log_content, content) as content
         FROM personal_logs
         WHERE user_id = ?
         ORDER BY COALESCE(log_date, created_at) DESC
         LIMIT ${parseInt(limitCount * 2)}`,
        [userId]
      );
      rows = allRows;
      usedRange = 'all';
    } else {
      const [defaultRows] = await db.execute(
        `SELECT
           COALESCE(log_title, title) as title,
           COALESCE(log_content, content) as content
         FROM personal_logs
         WHERE user_id = ?
           AND (
             (log_date IS NOT NULL AND DATE(log_date) = CURDATE())
             OR (log_date IS NULL AND DATE(created_at) = CURDATE())
           )
         ORDER BY COALESCE(log_date, created_at) DESC`,
        [userId]
      );
      rows = defaultRows;
      usedRange = 'today';
    }

    if (!rows || rows.length === 0) {
      return res.json({ keywords: [], wordFrequencies: [], range: usedRange, isDeepSeek: false });
    }

    // 合并日志内容（title和content），格式化为结构化文本
    const combined = rows
      .map((r, index) => {
        const title = r.title || '';
        const content = r.content || '';
        return `【日志${index + 1}】\n标题：${title}\n内容：${content}`;
      })
      .filter(text => text.trim().length > 0)
      .join('\n\n');

    if (!combined || combined.trim().length === 0) {
      return res.json({ keywords: [], wordFrequencies: [], range: usedRange, isDeepSeek: false });
    }

    let analysisResult;
    let isDeepSeek = false;

    // 优先使用DeepSeek API进行智能分析
    if (DEEPSEEK_API_KEY) {
      try {
        analysisResult = await analyzeWordCloudWithDeepSeek(combined, Number(topK));
        isDeepSeek = true;
        console.log('使用DeepSeek API进行词云分析成功');
      } catch (deepSeekError) {
        console.warn('DeepSeek API词云分析失败，回退到本地算法:', deepSeekError.message);
        // 回退到本地算法
        isDeepSeek = false;
      }
    }

    // 如果DeepSeek API未配置或失败，使用本地算法
    if (!isDeepSeek) {
    // 临时使用简单分词（等segmentit安装后恢复）
    const tokens = combined.split(/[\s\n\r\t,，。！？；：""''（）()【】\[\]{}]+/)
      .filter(w => w && w.trim().length > 1);

    if (tokens.length === 0) {
        return res.json({ keywords: [], wordFrequencies: [], range: usedRange, isDeepSeek: false });
    }

    const freqMap = {};
    for (const w of tokens) {
      freqMap[w] = (freqMap[w] || 0) + 1;
    }
    const wordFrequencies = Object.entries(freqMap)
      .map(([word, count]) => ({ word, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, Number(topK));

    const maxCount = wordFrequencies.length > 0 ? wordFrequencies[0].count : 1;
      const keywords = wordFrequencies.map(x => ({ 
        word: x.word, 
        weight: x.count / (maxCount || 1),
        importance: x.count / (maxCount || 1) // 本地算法使用weight作为importance
      }));

      // 为本地算法添加importance字段
      const wordFrequenciesWithImportance = wordFrequencies.map(x => ({
        word: x.word,
        count: x.count,
        importance: x.count / (maxCount || 1)
      }));

      analysisResult = {
        keywords,
        wordFrequencies: wordFrequenciesWithImportance,
        analysis: {
          summary: '基于词频统计的本地分析结果',
          mainThemes: keywords.slice(0, 3).map(k => k.word),
          workFocus: '基于词频分析的工作重点'
        }
      };
    }

    // 确保返回的数据格式一致
    const result = {
      keywords: analysisResult.keywords || [],
      wordFrequencies: analysisResult.wordFrequencies || [],
      range: usedRange,
      isDeepSeek: isDeepSeek,
      analysis: analysisResult.analysis || null,
      selectedDate
    };

    return res.json(result);
  } catch (e) {
    console.error('AI当天日志分析失败:', e);
    return res.status(500).json({ error: 'AI当天日志分析失败: ' + e.message });
  }
});

// ==================== DeepSeek API 词云分析 ====================

// DeepSeek API 词云分析函数（带重试机制）
async function analyzeWordCloudWithDeepSeek(logText, topK = 20, retryCount = 0) {
  const MAX_RETRIES = 3;
  const RETRY_DELAY = 2000; // 2秒延迟
  
  // 如果日志太长，截取最近的部分（限制在8000字符以内）
  let processedLogText = logText;
  const MAX_LOG_LENGTH = 8000;
  if (logText.length > MAX_LOG_LENGTH) {
    console.warn(`日志内容过长(${logText.length}字符)，截取最近${MAX_LOG_LENGTH}字符`);
    const startPart = logText.substring(0, 2000);
    const endPart = logText.substring(logText.length - (MAX_LOG_LENGTH - 2000));
    processedLogText = startPart + '\n\n[...中间部分已省略...]\n\n' + endPart;
  }
  
  const prompt = `
你是一位专业的数据分析师和文本挖掘专家。请基于用户的工作日志，进行智能词云分析。

## 分析任务

请仔细分析日志内容，提取关键词并评估其重要程度。重要程度不仅考虑词频，还要考虑：
1. **语义重要性**：该词在工作日志中的语义价值和意义
2. **业务相关性**：与工作核心业务的关联度
3. **情感倾向**：是否代表重要的工作内容或成就
4. **上下文价值**：在整体工作模式中的代表性

## 日志内容

${processedLogText}

## 输出格式

请严格按照以下JSON格式返回分析结果，包含${topK}个最重要的关键词：

{
  "keywords": [
    {
      "word": "关键词",
      "importance": 0.95,
      "category": "工作类型/技能/领域/情感等分类",
      "reason": "为什么这个关键词重要（简短说明）"
    }
  ],
  "wordFrequencies": [
    {
      "word": "关键词",
      "count": 15,
      "importance": 0.95
    }
  ],
  "analysis": {
    "summary": "对日志内容的整体分析摘要（50-100字）",
    "mainThemes": ["主题1", "主题2", "主题3"],
    "workFocus": "工作重点和关注领域的描述"
  }
}

## 要求

1. 关键词应该是有意义的词汇或短语（2-6个字），避免无意义的单字
2. importance值范围0-1，表示重要程度（0.9以上为极高重要，0.7-0.9为高重要，0.5-0.7为中等重要，0.5以下为一般重要）
3. 关键词应该反映工作的核心内容、技能、领域、成就等
4. 按importance从高到低排序
5. 确保返回有效的JSON格式，不要包含markdown代码块标记
`;

  try {
    if (!DEEPSEEK_API_KEY) {
      throw new Error('DeepSeek API密钥未配置');
    }

    const response = await axios.post(DEEPSEEK_API_URL, {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'system',
          content: '你是一位专业的数据分析师和文本挖掘专家，擅长从工作日志中提取关键信息并进行智能分析。请严格按照JSON格式返回结果，不要添加任何额外的markdown标记。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3, // 降低温度以获得更稳定的分析结果
      max_tokens: 3000
    }, {
      timeout: 60000, // 60秒超时
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
      },
    });

    const content = response.data.choices[0].message.content.trim();
    
    // 提取JSON部分（去除可能的markdown代码块）
    let jsonStr = content;
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      jsonStr = jsonMatch[0];
    }
    
    const parsedData = JSON.parse(jsonStr);
    
    // 验证和规范化数据
    if (!parsedData.keywords || !Array.isArray(parsedData.keywords)) {
      throw new Error('DeepSeek API返回的数据格式不正确：缺少keywords数组');
    }
    
    if (!parsedData.wordFrequencies || !Array.isArray(parsedData.wordFrequencies)) {
      // 如果没有wordFrequencies，从keywords生成
      parsedData.wordFrequencies = parsedData.keywords.map(k => ({
        word: k.word,
        count: Math.round((k.importance || 0.5) * 20), // 根据importance估算count
        importance: k.importance || 0.5
      }));
    }
    
    // 确保数据按importance排序
    parsedData.keywords.sort((a, b) => (b.importance || 0) - (a.importance || 0));
    parsedData.wordFrequencies.sort((a, b) => (b.importance || 0) - (a.importance || 0));
    
    // 限制返回数量
    parsedData.keywords = parsedData.keywords.slice(0, topK);
    parsedData.wordFrequencies = parsedData.wordFrequencies.slice(0, topK);
    
    console.log(`DeepSeek API词云分析成功，返回${parsedData.keywords.length}个关键词`);
    return parsedData;
    
  } catch (error) {
    // 网络错误或超时，尝试重试
    if (retryCount < MAX_RETRIES && (
      error.code === 'ECONNRESET' || 
      error.code === 'ETIMEDOUT' ||
      error.message?.includes('timeout') ||
      error.message?.includes('aborted')
    )) {
      console.warn(`DeepSeek API调用失败(尝试 ${retryCount + 1}/${MAX_RETRIES}):`, error.message || error.code);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return analyzeWordCloudWithDeepSeek(logText, topK, retryCount + 1);
    }
    
    console.error('DeepSeek API词云分析失败:', error.message || error.code);
    throw error;
  }
}

// ==================== DeepSeek API 性格分析 ====================

// 保存词云分析结果
app.post('/api/ai/save-wordcloud', authenticateToken, async (req, res) => {
  try {
    const { analysisDate, keywords, wordFrequencies, description } = req.body;
    const userId = req.user.id;

    // 解析analysisDate，如果为空则使用当前时间
    const analysisDateTime = analysisDate ? new Date(analysisDate) : new Date();

    const [result] = await db.execute(
      `INSERT INTO wordcloud_analysis (user_id, analysis_date, keywords, word_frequencies, description, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [userId, analysisDateTime, JSON.stringify(keywords), JSON.stringify(wordFrequencies), description || '今日日志分析']
    );

    // 查询刚插入的记录，确保返回完整数据
    const [rows] = await db.execute(
      `SELECT id, user_id, analysis_date, keywords, word_frequencies, description, created_at
       FROM wordcloud_analysis
       WHERE id = ?`,
      [result.insertId]
    );

    if (rows.length === 0) {
      return res.status(500).json({ error: '保存成功但无法查询到记录' });
    }

    const row = rows[0];
    
    // 安全解析JSON，处理可能已经是对象的情况
    let parsedKeywords, parsedWordFrequencies;
    try {
      parsedKeywords = typeof row.keywords === 'string' 
        ? JSON.parse(row.keywords) 
        : row.keywords;
    } catch (e) {
      console.warn('解析keywords失败，使用空数组:', e.message);
      parsedKeywords = [];
    }
    
    try {
      parsedWordFrequencies = typeof row.word_frequencies === 'string'
        ? JSON.parse(row.word_frequencies)
        : row.word_frequencies;
    } catch (e) {
      console.warn('解析word_frequencies失败，使用空数组:', e.message);
      parsedWordFrequencies = [];
    }
    
    const analysis = {
      id: row.id.toString(),
      userId: row.user_id,
      analysisDate: row.analysis_date,
      keywords: parsedKeywords,
      wordFrequencies: parsedWordFrequencies,
      createdAt: row.created_at,
      description: row.description,
      // 兼容前端期望的字段名
      user_id: row.user_id,
      analysis_date: row.analysis_date,
      word_frequencies: parsedWordFrequencies,
      created_at: row.created_at,
    };

    res.json(analysis);
  } catch (error) {
    console.error('保存词云分析失败:', error);
    res.status(500).json({ error: '保存词云分析失败: ' + error.message });
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

    const history = rows.map(row => {
      // 安全解析JSON，避免解析错误
      let keywords = [];
      let wordFrequencies = [];
      
      try {
        if (row.keywords) {
          keywords = typeof row.keywords === 'string' 
            ? JSON.parse(row.keywords) 
            : row.keywords;
        }
      } catch (e) {
        console.warn('解析keywords失败:', e.message);
        keywords = [];
      }
      
      try {
        if (row.word_frequencies) {
          wordFrequencies = typeof row.word_frequencies === 'string'
            ? JSON.parse(row.word_frequencies)
            : row.word_frequencies;
        }
      } catch (e) {
        console.warn('解析word_frequencies失败:', e.message);
        wordFrequencies = [];
      }
      
      return {
        id: row.id.toString(),
        userId: row.user_id,
        analysisDate: row.analysis_date,
        keywords: keywords,
        wordFrequencies: wordFrequencies,
        createdAt: row.created_at,
        description: row.description,
      };
    });

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
    let isDeepSeek = false;

    // 优先使用外部AI（DeepSeek）进行性格分析
    if (DEEPSEEK_API_KEY) {
      let deepSeekAttempted = false;
      try {
        // 尝试使用DeepSeek API进行性格分析（带重试机制）
        analysisResult = await analyzePersonalityWithDeepSeek(logText, mbtiType);
        deepSeekAttempted = true;
        
        // 检查返回结果是否表示失败（包含错误信息）
        const hasError = analysisResult.aiAnalysisText && (
          analysisResult.aiAnalysisText.includes('失败') ||
          analysisResult.aiAnalysisText.includes('错误') ||
          analysisResult.aiAnalysisText.includes('AI分析失败') ||
          analysisResult.aiAnalysisText.includes('使用默认数据')
        );
        
        if (hasError) {
          // DeepSeek API返回了错误结果，但继续使用（至少尝试了）
          console.warn('DeepSeek API返回了可能不完整的结果，但继续使用');
          isDeepSeek = true; // 仍然标记为使用DeepSeek，因为确实调用了API
        } else {
          // 成功获取分析结果
          isDeepSeek = true;
          console.log('DeepSeek API分析成功');
        }
      } catch (deepSeekError) {
        // DeepSeek API调用抛出异常
        console.error('DeepSeek API调用异常:', deepSeekError.message || deepSeekError.code);
        
        // 如果是网络相关错误，尝试最后一次重试
        const isNetworkError = deepSeekError.code === 'ECONNRESET' || 
                              deepSeekError.code === 'ETIMEDOUT' ||
                              deepSeekError.message?.includes('aborted');
        
        if (isNetworkError && !deepSeekAttempted) {
          console.log('检测到网络错误，尝试最后一次重试...');
          try {
            await new Promise(resolve => setTimeout(resolve, 3000)); // 等待3秒
            analysisResult = await analyzePersonalityWithDeepSeek(logText, mbtiType);
            isDeepSeek = true;
            console.log('重试成功，DeepSeek API分析完成');
          } catch (retryError) {
            console.error('重试也失败，回退到本地算法:', retryError.message);
            analysisResult = await analyzePersonalityLocally(logText, mbtiType);
            isDeepSeek = false;
          }
        } else {
          // 其他错误或重试失败，回退到本地算法
          console.warn('DeepSeek API调用失败，回退到本地算法');
          analysisResult = await analyzePersonalityLocally(logText, mbtiType);
          isDeepSeek = false;
        }
      }
    } else {
      // DeepSeek API密钥不存在，使用本地算法进行性格分析
      console.warn('DeepSeek API密钥未配置，使用本地算法');
      analysisResult = await analyzePersonalityLocally(logText, mbtiType);
      isDeepSeek = false;
    }

    // 根据是否使用DeepSeek设置description
    const description = isDeepSeek ? 'DeepSeek AI性格分析报告' : '本地算法性格分析报告';

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
        description
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
      isDeepSeek: isDeepSeek, // 标识是否使用DeepSeek API
      createdAt: new Date(),
      description: description,
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
      // 根据description判断是否使用DeepSeek（兼容历史数据）
      isDeepSeek: row.description && row.description.includes('DeepSeek'),
    }));

    res.json(history);
  } catch (error) {
    console.error('获取性格分析历史失败:', error);
    res.status(500).json({ error: '获取性格分析历史失败' });
  }
});

// ==================== DeepSeek API 分析函数 ====================

// DeepSeek API 性格分析函数（带重试机制）
async function analyzePersonalityWithDeepSeek(logText, mbtiType, retryCount = 0) {
  const MAX_RETRIES = 3;
  const RETRY_DELAY = 2000; // 2秒延迟
  
  // 如果日志太长，截取最近的部分（限制在8000字符以内）
  let processedLogText = logText;
  const MAX_LOG_LENGTH = 8000;
  if (logText.length > MAX_LOG_LENGTH) {
    console.warn(`日志内容过长(${logText.length}字符)，截取最近${MAX_LOG_LENGTH}字符`);
    // 保留开头和结尾，中间截取
    const startPart = logText.substring(0, 2000);
    const endPart = logText.substring(logText.length - (MAX_LOG_LENGTH - 2000));
    processedLogText = startPart + '\n\n[...中间部分已省略...]\n\n' + endPart;
  }
  
  const prompt = `
你是一位资深的职业发展顾问和性格分析师。请基于用户的工作日志进行深入分析，结合MBTI性格类型，给出个性化的职业发展建议。

## 分析任务

### 第一步：深入分析每篇日志的有效信息
请仔细阅读每篇日志，提取以下关键信息：
1. **工作内容**：具体做了哪些工作？涉及哪些领域和行业？
2. **技能体现**：从日志中可以看出哪些技能（如沟通、管理、分析、创新、执行等）？
3. **工作偏好**：更倾向于什么类型的工作（独立工作/团队协作、创新/执行、战略/细节等）？
4. **工作挑战**：遇到了哪些困难或挑战？如何应对的？
5. **成就与成长**：取得了哪些成果？有哪些成长和进步？
6. **工作模式**：工作节奏、优先级管理方式、时间分配特点

### 第二步：结合MBTI类型进行综合分析
${mbtiType ? `已知MBTI类型：${mbtiType}。请结合该MBTI类型的典型特征，分析日志中的行为模式是否与MBTI类型一致，并识别出独特的工作风格。` : '如果无法确定MBTI类型，请基于日志内容推断可能的MBTI类型。'}

### 第三步：给出具体的职业建议
基于日志分析和MBTI类型，提供：
1. **当前工作适配度**：当前工作内容与性格类型的匹配程度
2. **适合的职业方向**：具体列出3-5个最适合的职业方向，并说明原因
3. **职业发展路径**：短期（1-2年）和长期（3-5年）的职业发展建议
4. **能力提升建议**：需要重点发展的技能和能力
5. **工作环境建议**：最适合的工作环境、团队文化、管理风格

## 日志内容

${processedLogText}

${mbtiType ? `\n## 已知MBTI类型\n${mbtiType}\n` : ''}

## 输出格式

请严格按照以下JSON格式返回分析结果：

{
  "personalityTraits": {
    "外向性": 0.8,
    "宜人性": 0.6,
    "尽责性": 0.9,
    "神经质": 0.3,
    "开放性": 0.7
  },
  "mbtiType": "${mbtiType || 'ENFP'}",
  "workSuggestions": {
    "日志分析摘要": "基于日志分析，总结用户的工作特点、技能优势和兴趣方向（100-200字）",
    "当前工作适配度": "评估当前工作内容与性格类型的匹配程度（0-1之间的数值）",
    "适合职业": [
      {
        "职业名称": "具体职业名称",
        "匹配原因": "为什么适合这个职业（结合日志和MBTI分析）",
        "发展前景": "该职业的发展前景和成长空间"
      }
    ],
    "职业发展路径": {
      "短期目标": "1-2年的职业发展建议（具体、可执行）",
      "长期目标": "3-5年的职业发展建议（结合性格特点和职业兴趣）"
    },
    "能力提升建议": [
      "需要重点发展的技能1（结合日志中的不足）",
      "需要重点发展的技能2",
      "需要重点发展的技能3"
    ],
    "工作环境建议": {
      "理想工作环境": "描述最适合的工作环境特点",
      "团队文化": "适合的团队文化和管理风格",
      "工作方式": "推荐的工作方式和节奏"
    },
    "发展建议": "综合性的职业发展建议（200-300字，结合日志分析和MBTI类型）"
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
      "团队合作": 0.8,
      "执行力": 0.85,
      "学习能力": 0.75
    }
  },
  "logAnalysis": {
    "工作领域": "从日志中识别的主要工作领域",
    "核心技能": ["技能1", "技能2", "技能3"],
    "工作偏好": "偏好的工作类型和方式",
    "成长轨迹": "从日志中观察到的成长和进步"
  }
}

请确保：
1. 所有建议都基于日志中的具体内容，不要泛泛而谈
2. 结合MBTI类型特征，但不要完全依赖MBTI，要结合实际工作表现
3. 给出具体、可执行的建议，避免空泛的描述
4. 数值评分要合理，基于日志内容进行客观评估
`;

  try {
    const response = await axios.post(DEEPSEEK_API_URL, {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'system',
          content: '你是一位资深的职业发展顾问和性格分析师，擅长基于工作日志进行深入的职业分析和MBTI性格分析。你能够从日志中提取有效信息，结合MBTI类型特征，给出具体、可执行的职业发展建议。请始终返回有效的JSON格式数据，确保所有建议都基于日志中的具体内容。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 4000  // 增加token数量以支持更详细的分析
    }, {
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000, // 增加到60秒超时
      // 禁用压缩，避免解压问题
      decompress: true,
      // 增加响应大小限制
      maxContentLength: Infinity,
      maxBodyLength: Infinity
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
    // 判断错误类型，决定是否重试
    const isRetryableError = error.code === 'ECONNRESET' || 
                            error.code === 'ETIMEDOUT' || 
                            error.code === 'ECONNREFUSED' ||
                            error.message?.includes('aborted') ||
                            error.message?.includes('timeout');
    
    if (isRetryableError && retryCount < MAX_RETRIES) {
      console.warn(`DeepSeek API调用失败(尝试 ${retryCount + 1}/${MAX_RETRIES}):`, error.message || error.code);
      console.log(`等待 ${RETRY_DELAY}ms 后重试...`);
      
      // 等待后重试
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return analyzePersonalityWithDeepSeek(logText, mbtiType, retryCount + 1);
    }
    
    // 如果重试次数用完或不是可重试错误，抛出异常
    console.error('DeepSeek API调用最终失败:', error.message || error.code);
    throw error; // 抛出异常，让调用者决定如何处理
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
