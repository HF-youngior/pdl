-- 修复的增强示例数据脚本
-- 确保所有必需字段都有值

USE enterprise_management;

-- 为创始人添加更多任务（使用INSERT IGNORE避免重复）
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, created_by, deadline, start_time, end_time) VALUES
('task-022', 'Q1季度总结会议', '组织Q1季度总结会议，分析各部门业绩', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'pending', 'founder-001', '2024-03-15 14:00:00', '2024-03-15 14:00:00', '2024-03-15 16:00:00'),
('task-023', '新产品发布会筹备', '筹备新产品发布会，包括场地、媒体邀请等', 'founder-002', 'Li Founder', 'dept-003', 'p1', 'in_progress', 'founder-002', '2024-03-20 18:00:00', '2024-03-10 09:00:00', '2024-03-20 18:00:00'),
('task-024', '年度战略规划调整', '根据市场变化调整年度战略规划', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'pending', 'founder-001', '2024-03-25 17:00:00', '2024-03-25 09:00:00', '2024-03-25 17:00:00');

-- 为部门总监添加更多任务
INSERT IGNORE INTO tasks (id, title, description, parent_task_id, assignee_id, assignee_name, department_id, priority, status, created_by, deadline, start_time, end_time) VALUES
('task-025', '员工绩效考核', '制定并执行员工绩效考核方案', 'task-001', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p1', 'pending', 'dept-head-001', '2024-03-10 18:00:00', '2024-03-10 09:00:00', '2024-03-10 18:00:00'),
('task-026', '财务审计准备', '准备年度财务审计所需材料', 'task-002', 'dept-head-002', 'Zhao Finance Director', 'dept-002', 'p0', 'in_progress', 'dept-head-002', '2024-03-12 17:00:00', '2024-03-08 09:00:00', '2024-03-12 17:00:00'),
('task-027', '市场调研分析', '进行市场调研并分析竞争对手情况', 'task-003', 'dept-head-003', 'Chen Marketing Director', 'dept-003', 'p1', 'pending', 'dept-head-003', '2024-03-18 18:00:00', '2024-03-18 09:00:00', '2024-03-18 18:00:00');

-- 为团队长添加更多任务
INSERT IGNORE INTO tasks (id, title, description, parent_task_id, assignee_id, assignee_name, department_id, priority, status, created_by, deadline, start_time, end_time) VALUES
('task-028', '招聘渠道优化', '优化招聘渠道，提高招聘效率', 'task-004', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p1', 'pending', 'team-leader-001', '2024-03-08 18:00:00', '2024-03-08 09:00:00', '2024-03-08 18:00:00'),
('task-029', '培训课程设计', '设计新的员工培训课程', 'task-005', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p2', 'in_progress', 'team-leader-002', '2024-03-14 17:00:00', '2024-03-12 09:00:00', '2024-03-14 17:00:00'),
('task-030', '成本控制方案', '制定详细的成本控制方案', 'task-006', 'team-leader-003', 'Zhou Finance Team Lead', 'dept-002', 'p1', 'pending', 'team-leader-003', '2024-03-11 18:00:00', '2024-03-11 09:00:00', '2024-03-11 18:00:00');

-- 为员工添加更多任务
INSERT IGNORE INTO tasks (id, title, description, parent_task_id, assignee_id, assignee_name, department_id, priority, status, created_by, deadline, start_time, end_time) VALUES
('task-031', 'Java开发岗位面试', '进行Java开发岗位的面试工作', 'task-010', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'completed', 'employee-001', '2024-03-05 18:00:00', '2024-03-05 14:00:00', '2024-03-05 18:00:00'),
('task-032', '销售培训材料准备', '准备销售培训的相关材料', 'task-011', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p1', 'in_progress', 'employee-002', '2024-03-09 17:00:00', '2024-03-07 09:00:00', '2024-03-09 17:00:00'),
('task-033', '新员工入职流程', '完善新员工入职流程', 'task-012', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p2', 'pending', 'employee-003', '2024-03-13 18:00:00', '2024-03-13 09:00:00', '2024-03-13 18:00:00'),
('task-034', '财务数据分析', '分析Q1财务数据并生成报告', 'task-014', 'employee-005', 'Shen Finance Specialist', 'dept-002', 'p1', 'in_progress', 'employee-005', '2024-03-11 17:00:00', '2024-03-09 09:00:00', '2024-03-11 17:00:00'),
('task-035', '社交媒体内容发布', '发布本周的社交媒体内容', 'task-018', 'employee-009', 'Qin Marketing Specialist', 'dept-003', 'p1', 'completed', 'employee-009', '2024-03-06 18:00:00', '2024-03-06 14:00:00', '2024-03-06 18:00:00');

-- 添加更多个人日志（确保所有必需字段都有值，包括指定创建时间）
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-005', 'founder-001', 'Q1季度总结', '完成了Q1季度的业务总结，各部门表现良好', 'work', 'important_urgent', 'task-022', 1, '2025-10-01 10:30:00'),
('log-006', 'founder-002', '产品发布会策划', '制定了新产品发布会的详细策划方案', 'work', 'important_not_urgent', 'task-023', 0, '2025-10-02 14:15:00'),
('log-007', 'dept-head-001', '绩效考核方案', '制定了新的员工绩效考核方案', 'work', 'important_urgent', 'task-025', 1, '2025-10-03 09:45:00'),
('log-008', 'dept-head-002', '审计材料整理', '整理了财务审计所需的所有材料', 'work', 'important_urgent', 'task-026', 0, '2025-10-05 11:20:00'),
('log-009', 'team-leader-001', '招聘渠道分析', '分析了各招聘渠道的效果，优化了招聘策略', 'work', 'important_not_urgent', 'task-028', 1, '2025-10-08 16:30:00'),
('log-010', 'team-leader-002', '培训课程设计', '设计了新的员工培训课程大纲', 'work', 'important_not_urgent', 'task-029', 0, '2025-10-10 13:45:00'),
('log-011', 'employee-001', '面试总结', '完成了Java开发岗位的面试，筛选出3名候选人', 'work', 'important_urgent', 'task-031', 1, '2025-10-12 15:00:00'),
('log-012', 'employee-002', '培训材料制作', '制作了销售培训的PPT和手册', 'work', 'important_not_urgent', 'task-032', 0, '2025-10-14 10:10:00'),
('log-013', 'employee-005', '财务数据分析', '分析了Q1的财务数据，发现成本控制需要加强', 'work', 'important_urgent', 'task-034', 0, '2025-10-16 14:30:00'),
('log-014', 'employee-009', '社交媒体运营', '发布了本周的社交媒体内容，互动率提升了20%', 'work', 'not_important_urgent', 'task-035', 1, '2025-10-18 11:50:00');

-- 添加更多系统日志
INSERT IGNORE INTO system_logs (id, user_id, user_name, action, description, category) VALUES
('sys-log-005', 'founder-001', 'Zhang Founder', 'Task Creation', '创建了Q1季度总结会议任务', 'task'),
('sys-log-006', 'founder-002', 'Li Founder', 'Task Update', '更新了新产品发布会任务进度', 'task'),
('sys-log-007', 'dept-head-001', 'Wang HR Director', 'Task Assignment', '分配了员工绩效考核任务', 'task'),
('sys-log-008', 'dept-head-002', 'Zhao Finance Director', 'Task Progress', '更新了财务审计准备任务进度', 'task'),
('sys-log-009', 'team-leader-001', 'Liu HR Team Lead', 'Task Completion', '完成了招聘渠道优化任务', 'task'),
('sys-log-010', 'employee-001', 'Chen HR Specialist', 'Task Completion', '完成了Java开发岗位面试任务', 'task'),
('sys-log-011', 'employee-009', 'Qin Marketing Specialist', 'Task Completion', '完成了社交媒体内容发布任务', 'task');

-- 更新任务进度
UPDATE tasks SET progress_percentage = 100, completed_at = '2024-03-05 18:00:00' WHERE id = 'task-031';
UPDATE tasks SET progress_percentage = 100, completed_at = '2024-03-06 18:00:00' WHERE id = 'task-035';
UPDATE tasks SET progress_percentage = 60, completed_at = NULL WHERE id = 'task-023';
UPDATE tasks SET progress_percentage = 60, completed_at = NULL WHERE id = 'task-026';
UPDATE tasks SET progress_percentage = 60, completed_at = NULL WHERE id = 'task-029';
UPDATE tasks SET progress_percentage = 60, completed_at = NULL WHERE id = 'task-032';
UPDATE tasks SET progress_percentage = 60, completed_at = NULL WHERE id = 'task-034';
UPDATE tasks SET progress_percentage = 80, completed_at = NULL WHERE id = 'task-025';
UPDATE tasks SET progress_percentage = 80, completed_at = NULL WHERE id = 'task-027';
UPDATE tasks SET progress_percentage = 80, completed_at = NULL WHERE id = 'task-028';
UPDATE tasks SET progress_percentage = 80, completed_at = NULL WHERE id = 'task-030';
UPDATE tasks SET progress_percentage = 80, completed_at = NULL WHERE id = 'task-033';

SELECT 'Fixed enhanced sample data loaded successfully!' AS Message;
