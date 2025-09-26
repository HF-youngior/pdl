-- 数据库迁移脚本：为任务表添加新字段
-- 运行此脚本以更新现有的任务表结构

-- 添加新字段到任务表
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS end_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS color VARCHAR(7) DEFAULT '#4CAF50',
ADD COLUMN IF NOT EXISTS location VARCHAR(200) NULL,
ADD COLUMN IF NOT EXISTS is_all_day BOOLEAN DEFAULT FALSE;

-- 更新现有任务的时间字段（使用created_at作为默认值）
UPDATE tasks 
SET start_time = COALESCE(deadline, created_at),
    end_time = COALESCE(deadline, DATE_ADD(created_at, INTERVAL 1 HOUR))
WHERE start_time = end_time;

-- 插入一些示例任务数据（如果表为空）
INSERT IGNORE INTO tasks (
    id, title, description, assignee_id, assignee_name, department,
    priority, status, created_at, deadline, created_by,
    start_time, end_time, color, location, is_all_day
) VALUES 
(
    UUID(), '晨会', '每日晨会讨论', 
    (SELECT id FROM users WHERE role = 'manager' LIMIT 1),
    (SELECT name FROM users WHERE role = 'manager' LIMIT 1),
    '销售部', 'medium', 'pending', NOW(), NULL,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
    DATE_ADD(NOW(), INTERVAL 1 DAY), DATE_ADD(NOW(), INTERVAL 1 DAY 1 HOUR),
    '#4CAF50', '会议室', FALSE
),
(
    UUID(), '项目筹划', '新项目前期筹划',
    (SELECT id FROM users WHERE role = 'manager' LIMIT 1),
    (SELECT name FROM users WHERE role = 'manager' LIMIT 1),
    '销售部', 'high', 'pending', NOW(), NULL,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
    DATE_ADD(NOW(), INTERVAL 2 DAY), DATE_ADD(NOW(), INTERVAL 3 DAY),
    '#2196F3', '办公室', TRUE
),
(
    UUID(), '客户拜访', '重要客户拜访',
    (SELECT id FROM users WHERE role = 'manager' LIMIT 1),
    (SELECT name FROM users WHERE role = 'manager' LIMIT 1),
    '销售部', 'high', 'pending', NOW(), NULL,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
    DATE_ADD(NOW(), INTERVAL 5 DAY), DATE_ADD(NOW(), INTERVAL 5 DAY 2 HOUR),
    '#FF9800', '客户办公室', FALSE
),
(
    UUID(), '视频剪辑', '项目宣传视频制作',
    (SELECT id FROM users WHERE role = 'manager' LIMIT 1),
    (SELECT name FROM users WHERE role = 'manager' LIMIT 1),
    '销售部', 'medium', 'pending', NOW(), NULL,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
    DATE_ADD(NOW(), INTERVAL 7 DAY), DATE_ADD(NOW(), INTERVAL 8 DAY),
    '#E91E63', '制作室', TRUE
),
(
    UUID(), '年中总结', '半年度工作总结',
    (SELECT id FROM users WHERE role = 'manager' LIMIT 1),
    (SELECT name FROM users WHERE role = 'manager' LIMIT 1),
    '销售部', 'high', 'pending', NOW(), NULL,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
    DATE_ADD(NOW(), INTERVAL 10 DAY), DATE_ADD(NOW(), INTERVAL 10 DAY 3 HOUR),
    '#9C27B0', '会议室A', FALSE
);

-- 显示更新后的任务表结构
DESCRIBE tasks;
