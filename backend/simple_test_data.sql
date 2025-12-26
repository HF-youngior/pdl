-- 简单的测试数据脚本
-- 只添加必要的数据，避免复杂字段问题

USE enterprise_management;

-- 添加一些测试任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, created_by, deadline, start_time, end_time) VALUES
('test-task-001', '测试任务1', '这是一个测试任务', 'founder-001', 'Zhang Founder', 'dept-001', 'p1', 'pending', 'founder-001', '2024-12-31 18:00:00', '2024-12-01 09:00:00', '2024-12-31 18:00:00'),
('test-task-002', '测试任务2', '这是另一个测试任务', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p2', 'in_progress', 'dept-head-001', '2024-12-30 17:00:00', '2024-12-01 10:00:00', '2024-12-30 17:00:00'),
('test-task-003', '测试任务3', '这是第三个测试任务', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'completed', 'employee-001', '2024-12-29 16:00:00', '2024-12-01 11:00:00', '2024-12-29 16:00:00');

-- 添加一些测试个人日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed) VALUES
('test-log-001', 'founder-001', '测试日志1', '这是创始人的测试日志', 'work', 'important_urgent', 'test-task-001', 0),
('test-log-002', 'dept-head-001', '测试日志2', '这是部门总监的测试日志', 'work', 'important_not_urgent', 'test-task-002', 1),
('test-log-003', 'employee-001', '测试日志3', '这是员工的测试日志', 'work', 'not_important_urgent', 'test-task-003', 1);

-- 添加一些测试系统日志
INSERT IGNORE INTO system_logs (id, user_id, user_name, action, description, category) VALUES
('test-sys-log-001', 'founder-001', 'Zhang Founder', 'Test Action', '创建了测试任务1', 'task'),
('test-sys-log-002', 'dept-head-001', 'Wang HR Director', 'Test Action', '更新了测试任务2', 'task'),
('test-sys-log-003', 'employee-001', 'Chen HR Specialist', 'Test Action', '完成了测试任务3', 'task');

SELECT 'Simple test data loaded successfully!' AS Message;
