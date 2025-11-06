USE enterprise_management;

-- 添加更多有时间段的任务，让时间轴占比达到1/3以上
-- 目标：再增加约15-20个有时间段的任务

-- 10月份日常工作
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
-- 第一周
('task-hr-daily-001', 'dept-head-001', '王人事总监', 'dept-001', '招聘需求对接会', 
 '2025-10-01 14:00:00', '2025-10-01 15:30:00', 0, 'completed', '2025-10-01 09:00:00', 'dept-head-001'),
('task-hr-daily-002', 'dept-head-001', '王人事总监', 'dept-001', '员工入职培训', 
 '2025-10-02 09:30:00', '2025-10-02 11:30:00', 0, 'completed', '2025-10-02 09:00:00', 'dept-head-001'),
('task-hr-daily-003', 'dept-head-001', '王人事总监', 'dept-001', '薪酬方案讨论会', 
 '2025-10-04 14:30:00', '2025-10-04 16:00:00', 0, 'completed', '2025-10-04 09:00:00', 'dept-head-001'),

-- 第二周
('task-hr-daily-004', 'dept-head-001', '王人事总监', 'dept-001', '部门协调会', 
 '2025-10-08 10:00:00', '2025-10-08 11:00:00', 0, 'completed', '2025-10-08 09:00:00', 'dept-head-001'),
('task-hr-daily-005', 'dept-head-001', '王人事总监', 'dept-001', '员工关系处理沟通', 
 '2025-10-08 14:00:00', '2025-10-08 15:30:00', 0, 'completed', '2025-10-08 09:00:00', 'dept-head-001'),
('task-hr-daily-006', 'dept-head-001', '王人事总监', 'dept-001', '福利方案设计评审', 
 '2025-10-09 15:00:00', '2025-10-09 16:30:00', 0, 'completed', '2025-10-09 09:00:00', 'dept-head-001'),
('task-hr-daily-007', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统供应商演示', 
 '2025-10-10 10:00:00', '2025-10-10 11:30:00', 0, 'completed', '2025-10-10 09:00:00', 'dept-head-001'),

-- 第三周
('task-hr-daily-008', 'dept-head-001', '王人事总监', 'dept-001', '劳动合同续签沟通', 
 '2025-10-15 14:00:00', '2025-10-15 16:00:00', 0, 'completed', '2025-10-15 09:00:00', 'dept-head-001'),
('task-hr-daily-009', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘宣传材料审核', 
 '2025-10-16 10:30:00', '2025-10-16 12:00:00', 0, 'completed', '2025-10-16 09:00:00', 'dept-head-001'),
('task-hr-daily-010', 'dept-head-001', '王人事总监', 'dept-001', 'Q4绩效管理培训准备会', 
 '2025-10-18 10:00:00', '2025-10-18 11:30:00', 0, 'completed', '2025-10-18 09:00:00', 'dept-head-001'),

-- 第四周
('task-hr-daily-011', 'dept-head-001', '王人事总监', 'dept-001', '新员工导师沟通会', 
 '2025-10-23 10:00:00', '2025-10-23 11:30:00', 0, 'completed', '2025-10-23 09:00:00', 'dept-head-001'),
('task-hr-daily-012', 'dept-head-001', '王人事总监', 'dept-001', '员工福利预算讨论', 
 '2025-10-24 14:00:00', '2025-10-24 15:30:00', 0, 'completed', '2025-10-24 09:00:00', 'dept-head-001'),

-- 11月份日常工作
('task-hr-daily-013', 'dept-head-001', '王人事总监', 'dept-001', '离职面谈', 
 '2025-11-05 09:00:00', '2025-11-05 10:30:00', 0, 'completed', '2025-11-05 08:00:00', 'dept-head-001'),
('task-hr-daily-014', 'dept-head-001', '王人事总监', 'dept-001', '员工职业发展辅导', 
 '2025-11-06 14:00:00', '2025-11-06 16:00:00', 0, 'completed', '2025-11-06 09:00:00', 'dept-head-001'),
('task-hr-daily-015', 'dept-head-001', '王人事总监', 'dept-001', '员工职业发展辅导', 
 '2025-11-07 14:00:00', '2025-11-07 16:00:00', 0, 'completed', '2025-11-07 09:00:00', 'dept-head-001'),
('task-hr-daily-016', 'dept-head-001', '王人事总监', 'dept-001', '年终奖方案设计会', 
 '2025-11-08 10:00:00', '2025-11-08 12:00:00', 0, 'completed', '2025-11-08 09:00:00', 'dept-head-001'),
('task-hr-daily-017', 'dept-head-001', '王人事总监', 'dept-001', '年终奖预算沟通', 
 '2025-11-08 14:30:00', '2025-11-08 16:00:00', 0, 'completed', '2025-11-08 09:00:00', 'dept-head-001'),
('task-hr-daily-018', 'dept-head-001', '王人事总监', 'dept-001', '供应商评估会议', 
 '2025-11-09 15:00:00', '2025-11-09 16:30:00', 0, 'completed', '2025-11-09 09:00:00', 'dept-head-001'),
('task-hr-daily-019', 'dept-head-001', '王人事总监', 'dept-001', '人才盘点数据分析会', 
 '2025-11-12 10:00:00', '2025-11-12 12:00:00', 0, 'completed', '2025-11-12 09:00:00', 'dept-head-001'),
('task-hr-daily-020', 'dept-head-001', '王人事总监', 'dept-001', '年度规划修订讨论', 
 '2025-11-19 14:00:00', '2025-11-19 16:00:00', 0, 'completed', '2025-11-19 09:00:00', 'dept-head-001'),
('task-hr-daily-021', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会奖项评审', 
 '2025-11-24 10:00:00', '2025-11-24 11:30:00', 0, 'completed', '2025-11-24 09:00:00', 'dept-head-001'),
('task-hr-daily-022', 'dept-head-001', '王人事总监', 'dept-001', '供应商年度评估总结会', 
 '2025-11-26 14:00:00', '2025-11-26 15:30:00', 0, 'completed', '2025-11-26 09:00:00', 'dept-head-001'),
('task-hr-daily-023', 'dept-head-001', '王人事总监', 'dept-001', '员工矛盾调解', 
 '2025-11-27 10:00:00', '2025-11-27 11:30:00', 0, 'completed', '2025-11-27 09:00:00', 'dept-head-001'),
('task-hr-daily-024', 'dept-head-001', '王人事总监', 'dept-001', '年终奖发放准备会', 
 '2025-11-28 15:00:00', '2025-11-28 16:30:00', 0, 'completed', '2025-11-28 09:00:00', 'dept-head-001');

-- 查看最终统计
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN start_time IS NOT NULL AND is_all_day = 0 THEN 1 ELSE 0 END) as tasks_with_time,
  SUM(CASE WHEN start_time IS NOT NULL AND is_all_day = 1 THEN 1 ELSE 0 END) as all_day_tasks,
  SUM(CASE WHEN start_time IS NULL THEN 1 ELSE 0 END) as tasks_without_time
FROM tasks
WHERE assignee_id = 'dept-head-001';

SELECT '更新完成！' as status;






















