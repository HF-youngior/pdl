-- Enterprise Management System Database - Clean Version
-- Multi-level Permission System

-- Drop existing database if exists
DROP DATABASE IF EXISTS enterprise_management;

-- Create database
CREATE DATABASE enterprise_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE enterprise_management;

-- Department table
CREATE TABLE departments (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User table - Extended to support multi-level permissions
CREATE TABLE users (
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
    FOREIGN KEY (department_id) REFERENCES departments(id),
    FOREIGN KEY (parent_id) REFERENCES users(id)
);

-- Company important items table
CREATE TABLE company_important_items (
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
);

-- Task table - Supports hierarchical task relationships
CREATE TABLE tasks (
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
    FOREIGN KEY (parent_task_id) REFERENCES tasks(id),
    FOREIGN KEY (assignee_id) REFERENCES users(id),
    FOREIGN KEY (department_id) REFERENCES departments(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Task notification table
CREATE TABLE task_notifications (
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
);

-- Personal logs table
CREATE TABLE personal_logs (
    id VARCHAR(36) PRIMARY KEY,
    log_id VARCHAR(36) UNIQUE,
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(200) NOT NULL DEFAULT '个人日志',
    content TEXT,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    -- new API fields
    log_date DATE NULL,
    weather VARCHAR(50) NULL,
    keywords VARCHAR(255) NULL,
    log_title VARCHAR(200) NULL,
    log_content TEXT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'work',
    quadrant ENUM('important_urgent', 'important_not_urgent', 'not_important_urgent', 'not_important_not_urgent') DEFAULT 'important_not_urgent',
    is_archived BOOLEAN DEFAULT FALSE,
    related_task_id VARCHAR(36) NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (related_task_id) REFERENCES tasks(id)
);

-- System logs table
CREATE TABLE system_logs (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Log task linkage table
CREATE TABLE log_task_linkage (
    id INT AUTO_INCREMENT PRIMARY KEY,
    log_id VARCHAR(36) NOT NULL,
    task_id VARCHAR(36) NOT NULL,
    progress_percentage INT DEFAULT 0,
    task_status VARCHAR(50) DEFAULT 'in_progress',
    linkage_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY log_task_unique (log_id, task_id),
    FOREIGN KEY (log_id) REFERENCES personal_logs(id) ON DELETE CASCADE,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- Insert department data
INSERT INTO departments (id, name, description) VALUES
('dept-001', 'HR Department', 'Responsible for human resource management and employee relations'),
('dept-002', 'Finance Department', 'Responsible for financial management and capital operations'),
('dept-003', 'Marketing Department', 'Responsible for brand promotion and market expansion');

-- Insert user data
-- Admin (1)
INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES
('admin-001', 'admin', 'admin123', 'System Admin', 'Administrator', 'dept-001', 'admin', NULL);

-- Founders (2)
INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES
('founder-001', 'founder1', 'founder123', 'Zhang Founder', 'Founder', 'dept-001', 'founder', NULL),
('founder-002', 'founder2', 'founder123', 'Li Founder', 'Founder', 'dept-001', 'founder', NULL);

-- Department Heads (3, one for each department)
INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES
('dept-head-001', 'hr_head', 'hr123', 'Wang HR Director', 'HR Director', 'dept-001', 'department_head', 'founder-001'),
('dept-head-002', 'finance_head', 'finance123', 'Zhao Finance Director', 'Finance Director', 'dept-002', 'department_head', 'founder-001'),
('dept-head-003', 'marketing_head', 'marketing123', 'Chen Marketing Director', 'Marketing Director', 'dept-003', 'department_head', 'founder-002');

-- 初始化 HR 总监积分为 100 分，便于在积分商城中测试兑换功能
UPDATE users SET points = 100 WHERE username = 'hr_head';

-- Team Leaders (6, 2 for each department)
INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES
-- HR Department Team Leaders
('team-leader-001', 'hr_team1', 'hrteam123', 'Liu HR Team Lead', 'HR Team Lead', 'dept-001', 'team_leader', 'dept-head-001'),
('team-leader-002', 'hr_team2', 'hrteam123', 'Sun HR Team Lead', 'HR Team Lead', 'dept-001', 'team_leader', 'dept-head-001'),
-- Finance Department Team Leaders
('team-leader-003', 'finance_team1', 'financeteam123', 'Zhou Finance Team Lead', 'Finance Team Lead', 'dept-002', 'team_leader', 'dept-head-002'),
('team-leader-004', 'finance_team2', 'financeteam123', 'Wu Finance Team Lead', 'Finance Team Lead', 'dept-002', 'team_leader', 'dept-head-002'),
-- Marketing Department Team Leaders
('team-leader-005', 'marketing_team1', 'marketingteam123', 'Zheng Marketing Team Lead', 'Marketing Team Lead', 'dept-003', 'team_leader', 'dept-head-003'),
('team-leader-006', 'marketing_team2', 'marketingteam123', 'Feng Marketing Team Lead', 'Marketing Team Lead', 'dept-003', 'team_leader', 'dept-head-003');

-- Employees (12, 2 under each team leader)
INSERT INTO users (id, username, password, name, position, department_id, role, parent_id) VALUES
-- HR Department Employees
('employee-001', 'hr_emp1', 'hremp123', 'Chen HR Specialist', 'HR Specialist', 'dept-001', 'employee', 'team-leader-001'),
('employee-002', 'hr_emp2', 'hremp123', 'Chu HR Specialist', 'HR Specialist', 'dept-001', 'employee', 'team-leader-001'),
('employee-003', 'hr_emp3', 'hremp123', 'Wei HR Specialist', 'HR Specialist', 'dept-001', 'employee', 'team-leader-002'),
('employee-004', 'hr_emp4', 'hremp123', 'Jiang HR Specialist', 'HR Specialist', 'dept-001', 'employee', 'team-leader-002'),
-- Finance Department Employees
('employee-005', 'finance_emp1', 'financeemp123', 'Shen Finance Specialist', 'Finance Specialist', 'dept-002', 'employee', 'team-leader-003'),
('employee-006', 'finance_emp2', 'financeemp123', 'Han Finance Specialist', 'Finance Specialist', 'dept-002', 'employee', 'team-leader-003'),
('employee-007', 'finance_emp3', 'financeemp123', 'Yang Finance Specialist', 'Finance Specialist', 'dept-002', 'employee', 'team-leader-004'),
('employee-008', 'finance_emp4', 'financeemp123', 'Zhu Finance Specialist', 'Finance Specialist', 'dept-002', 'employee', 'team-leader-004'),
-- Marketing Department Employees
('employee-009', 'marketing_emp1', 'marketingemp123', 'Qin Marketing Specialist', 'Marketing Specialist', 'dept-003', 'employee', 'team-leader-005'),
('employee-010', 'marketing_emp2', 'marketingemp123', 'You Marketing Specialist', 'Marketing Specialist', 'dept-003', 'employee', 'team-leader-005'),
('employee-011', 'marketing_emp3', 'marketingemp123', 'Xu Marketing Specialist', 'Marketing Specialist', 'dept-003', 'employee', 'team-leader-006'),
('employee-012', 'marketing_emp4', 'marketingemp123', 'He Marketing Specialist', 'Marketing Specialist', 'dept-003', 'employee', 'team-leader-006');

-- Insert company important items sample data
INSERT INTO company_important_items (id, title, description, priority, is_selected, created_by) VALUES
('item-001', '2024 Annual Strategic Planning', 'Develop company 2024 annual development strategy and business planning', 'p0', TRUE, 'founder-001'),
('item-002', 'New Product R&D Project Launch', 'Launch core product new version R&D work', 'p0', TRUE, 'founder-001'),
('item-003', 'Market Expansion Plan', 'Develop overseas market expansion and localization strategy', 'p1', TRUE, 'founder-002'),
('item-004', 'Talent Recruitment Plan', 'Recruit key position talents and improve team structure', 'p1', TRUE, 'founder-001'),
('item-005', 'Financial Compliance Audit', 'Complete annual financial audit and compliance inspection', 'p1', TRUE, 'founder-002'),
('item-006', 'Brand Upgrade Project', 'Comprehensive upgrade of company brand image and visual identity', 'p2', TRUE, 'founder-002'),
('item-007', 'Employee Training System', 'Establish comprehensive employee training and development system', 'p2', TRUE, 'founder-001'),
('item-008', 'Technical Architecture Upgrade', 'Upgrade company technical architecture and improve system performance', 'p2', TRUE, 'founder-001'),
('item-009', 'Customer Service System', 'Optimize customer service process and improve customer satisfaction', 'p3', TRUE, 'founder-002'),
('item-010', 'Office Environment Improvement', 'Improve office environment and enhance employee work experience', 'p3', TRUE, 'founder-001');

-- Insert task sample data (showing hierarchical task relationships)
INSERT INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, created_by, deadline) VALUES
-- Founder assigned tasks to department heads
('task-001', 'Develop HR Department Annual Plan', 'Develop HR department 2024 annual work plan and goals', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p1', 'pending', 'founder-001', '2024-02-15 18:00:00'),
('task-002', 'Financial Budget Development', 'Develop company 2024 annual financial budget', 'dept-head-002', 'Zhao Finance Director', 'dept-002', 'p0', 'pending', 'founder-001', '2024-02-20 18:00:00'),
('task-003', 'Brand Marketing Strategy', 'Develop 2024 annual brand marketing strategy', 'dept-head-003', 'Chen Marketing Director', 'dept-003', 'p1', 'pending', 'founder-002', '2024-02-25 18:00:00');

-- Department head assigned subtasks to team leaders
INSERT INTO tasks (id, title, description, parent_task_id, assignee_id, assignee_name, department_id, priority, status, created_by, deadline) VALUES
('task-004', 'Recruitment Plan Development', 'Develop recruitment plans and position requirements for each department', 'task-001', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p1', 'pending', 'dept-head-001', '2024-02-10 18:00:00'),
('task-005', 'Training Plan Development', 'Develop employee training plans and course arrangements', 'task-001', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p2', 'pending', 'dept-head-001', '2024-02-12 18:00:00'),
('task-006', 'Cost Control Plan', 'Develop cost control plans for each department', 'task-002', 'team-leader-003', 'Zhou Finance Team Lead', 'dept-002', 'p1', 'pending', 'dept-head-002', '2024-02-15 18:00:00'),
('task-007', 'Budget Execution Monitoring', 'Establish budget execution monitoring mechanism', 'task-002', 'team-leader-004', 'Wu Finance Team Lead', 'dept-002', 'p1', 'pending', 'dept-head-002', '2024-02-18 18:00:00'),
('task-008', 'Online Marketing Plan', 'Develop online marketing and promotion plans', 'task-003', 'team-leader-005', 'Zheng Marketing Team Lead', 'dept-003', 'p1', 'pending', 'dept-head-003', '2024-02-20 18:00:00'),
('task-009', 'Offline Event Planning', 'Plan offline brand promotion events', 'task-003', 'team-leader-006', 'Feng Marketing Team Lead', 'dept-003', 'p2', 'pending', 'dept-head-003', '2024-02-22 18:00:00');

-- Team leader assigned subtasks to employees
INSERT INTO tasks (id, title, description, parent_task_id, assignee_id, assignee_name, department_id, priority, status, created_by, deadline) VALUES
('task-010', 'Technical Position Recruitment', 'Responsible for technical position recruitment work', 'task-004', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'pending', 'team-leader-001', '2024-02-08 18:00:00'),
('task-011', 'Sales Position Recruitment', 'Responsible for sales position recruitment work', 'task-004', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p1', 'pending', 'team-leader-001', '2024-02-08 18:00:00'),
('task-012', 'New Employee Training', 'Organize new employee onboarding training', 'task-005', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p2', 'pending', 'team-leader-002', '2024-02-10 18:00:00'),
('task-013', 'Skill Enhancement Training', 'Organize employee skill enhancement training', 'task-005', 'employee-004', 'Jiang HR Specialist', 'dept-001', 'p2', 'pending', 'team-leader-002', '2024-02-12 18:00:00'),
('task-014', 'Human Cost Analysis', 'Analyze human costs for each department', 'task-006', 'employee-005', 'Shen Finance Specialist', 'dept-002', 'p1', 'pending', 'team-leader-003', '2024-02-12 18:00:00'),
('task-015', 'Operating Cost Analysis', 'Analyze operating cost structure', 'task-006', 'employee-006', 'Han Finance Specialist', 'dept-002', 'p1', 'pending', 'team-leader-003', '2024-02-14 18:00:00'),
('task-016', 'Budget Execution Report', 'Generate regular budget execution reports', 'task-007', 'employee-007', 'Yang Finance Specialist', 'dept-002', 'p1', 'pending', 'team-leader-004', '2024-02-16 18:00:00'),
('task-017', 'Budget Variance Analysis', 'Analyze budget execution variance reasons', 'task-007', 'employee-008', 'Zhu Finance Specialist', 'dept-002', 'p1', 'pending', 'team-leader-004', '2024-02-18 18:00:00'),
('task-018', 'Social Media Management', 'Responsible for social media platform management', 'task-008', 'employee-009', 'Qin Marketing Specialist', 'dept-003', 'p1', 'pending', 'team-leader-005', '2024-02-18 18:00:00'),
('task-019', 'Content Creation', 'Create marketing content and materials', 'task-008', 'employee-010', 'You Marketing Specialist', 'dept-003', 'p1', 'pending', 'team-leader-005', '2024-02-20 18:00:00'),
('task-020', 'Event Execution', 'Execute offline promotion events', 'task-009', 'employee-011', 'Xu Marketing Specialist', 'dept-003', 'p2', 'pending', 'team-leader-006', '2024-02-20 18:00:00'),
('task-021', 'Event Performance Evaluation', 'Evaluate event performance and ROI', 'task-009', 'employee-012', 'He Marketing Specialist', 'dept-003', 'p2', 'pending', 'team-leader-006', '2024-02-22 18:00:00');

-- Insert personal logs sample data
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id) VALUES
('log-001', 'employee-001', 'Technical Interview Preparation', 'Prepared Java development position interview questions and scoring criteria', 'work', 'important_urgent', 'task-010'),
('log-002', 'employee-002', 'Sales Training Insights', 'Attended sales skills training and learned new customer communication methods', 'learning', 'important_not_urgent', NULL),
('log-003', 'employee-005', 'Cost Analysis Report', 'Completed Q1 human cost analysis report and found some optimization points', 'work', 'important_not_urgent', 'task-014'),
('log-004', 'employee-009', 'Social Media Data', 'Analyzed last week social media data with 15% increase in engagement rate', 'work', 'not_important_urgent', 'task-018');

-- Insert system logs sample data
INSERT INTO system_logs (id, user_id, user_name, action, description, category) VALUES
('sys-log-001', 'founder-001', 'Zhang Founder', 'User Login', 'Zhang Founder logged into the system', 'login'),
('sys-log-002', 'founder-001', 'Zhang Founder', 'Task Creation', 'Created HR department annual plan task', 'task'),
('sys-log-003', 'dept-head-001', 'Wang HR Director', 'Task Assignment', 'Assigned recruitment plan task to Liu HR Team Lead', 'task'),
('sys-log-004', 'team-leader-001', 'Liu HR Team Lead', 'Task Assignment', 'Assigned technical position recruitment task to Chen HR Specialist', 'task');

-- Create indexes to improve query performance
CREATE INDEX idx_users_department ON users(department_id);
-- Checkin records table
CREATE TABLE checkin_records (
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
);

-- Points transactions table (earn & spend history)
CREATE TABLE points_transactions (
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
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_parent ON users(parent_id);
CREATE INDEX idx_users_points ON users(points);
CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX idx_tasks_parent ON tasks(parent_task_id);
CREATE INDEX idx_tasks_department ON tasks(department_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_notifications_to_user ON task_notifications(to_user_id);
CREATE INDEX idx_notifications_is_read ON task_notifications(is_read);
CREATE INDEX idx_company_items_selected ON company_important_items(is_selected);
CREATE INDEX idx_personal_logs_user ON personal_logs(user_id);
CREATE INDEX idx_personal_logs_related_task ON personal_logs(related_task_id);
