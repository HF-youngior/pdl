-- 企业管理系统数据库初始化脚本

-- 创建数据库
CREATE DATABASE IF NOT EXISTS enterprise_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE enterprise_management;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    position VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    role ENUM('admin', 'manager', 'employee') NOT NULL DEFAULT 'employee',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP NULL
);

-- 重要事项表
CREATE TABLE IF NOT EXISTS important_items (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    department VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deadline TIMESTAMP NULL,
    created_by VARCHAR(36),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 任务表
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    assignee_id VARCHAR(36) NOT NULL,
    assignee_name VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deadline TIMESTAMP NULL,
    created_by VARCHAR(36),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 个人信息表
CREATE TABLE IF NOT EXISTS personal_info (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    log_date DATE NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    category VARCHAR(50) NOT NULL,
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 日志表
CREATE TABLE IF NOT EXISTS logs (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 个人日志表（与运行时保持一致，支持新建个人日志接口）
CREATE TABLE IF NOT EXISTS personal_logs (
    id VARCHAR(36) PRIMARY KEY,
    log_id VARCHAR(36) UNIQUE,
    user_id VARCHAR(36),
    content TEXT,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    -- 新版字段
    log_date DATE NULL,
    weather VARCHAR(50) NULL,
    keywords TEXT,
    log_title VARCHAR(200) NULL,
    log_content TEXT NULL,
    is_archived BOOLEAN DEFAULT FALSE,
    related_task_id VARCHAR(36) NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (related_task_id) REFERENCES tasks(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS log_task_linkage (
      id INT AUTO_INCREMENT PRIMARY KEY,
      log_id VARCHAR(36) NOT NULL,
      task_id VARCHAR(36) NOT NULL,
      progress_percentage INT DEFAULT 0,
      task_status VARCHAR(50) DEFAULT 'in_progress',
      linkage_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY log_task_unique (log_id, task_id), -- 确保一条日志对一个任务只关联一次
      FOREIGN KEY (log_id) REFERENCES personal_logs(id) ON DELETE CASCADE,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- 插入示例数据
INSERT INTO users (id, username, password, name, position, department, role) VALUES
('admin-001', 'admin', 'admin123', '系统管理员', '管理员', 'IT部门', 'admin'),
('manager-001', 'manager', 'manager123', '张总', '部门老总', '销售部', 'manager'),
('employee-001', 'employee1', 'employee123', '李员工', '销售专员', '销售部', 'employee');

-- 插入示例重要事项
INSERT INTO important_items (id, title, description, priority, department, created_by) VALUES
('item-001', '年度销售目标制定', '制定2024年度销售目标和策略，包括各季度目标分解', 'high', '销售部', 'admin-001'),
('item-002', '新产品研发计划', '启动下一代产品研发项目，预计6个月完成', 'urgent', '研发部', 'admin-001'),
('item-003', '员工培训计划', '制定全年员工技能培训计划', 'medium', '人事部', 'admin-001');

-- 插入示例任务
INSERT INTO tasks (id, title, description, assignee_id, assignee_name, department, priority, created_by) VALUES
('task-001', '客户拜访计划', '制定本周客户拜访计划，重点客户优先', 'manager-001', '张总', '销售部', 'medium', 'admin-001'),
('task-002', '市场调研报告', '完成Q1市场调研报告', 'employee-001', '李员工', '销售部', 'high', 'manager-001'),
('task-003', '系统维护', '定期维护公司内部系统', 'admin-001', '系统管理员', 'IT部门', 'low', 'admin-001');

-- 插入示例个人信息
INSERT INTO personal_info (id, user_id, title, content, category, priority) VALUES
('info-001', 'manager-001', '重要客户联系方式', '王总：13800138000，李总：13900139000', 'contacts', 'high'),
('info-002', 'manager-001', '会议纪要', '今日部门会议讨论了下季度销售策略', 'meeting', 'medium'),
('info-003', 'employee-001', '学习笔记', '学习了新的销售技巧和客户沟通方法', 'learning', 'low');

-- 插入示例日志
INSERT INTO logs (id, user_id, user_name, action, description, category) VALUES
('log-001', 'admin-001', '系统管理员', '系统启动', '企业管理系统启动成功', 'system'),
('log-002', 'manager-001', '张总', '用户登录', '张总登录系统', 'login'),
('log-003', 'employee-001', '李员工', '查看任务', '查看分配的任务列表', 'action'),
('log-004', 'manager-001', '张总', '创建任务', '为客户拜访计划创建了新的任务', 'action');
