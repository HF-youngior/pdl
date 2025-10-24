-- ========================================
-- 丰富 hr_head 用户的时间轴数据
-- 目标：让约1/3的任务和日志显示在时间轴上
-- ========================================

USE enterprise_management;

-- 1. 更新部分任务，添加具体时间段（非全天）
-- 将10个任务从"无时间段"改为"有时间段"

-- 秋季校园招聘启动会议 (10月1日 上午)
UPDATE tasks 
SET start_time = '2025-10-01 10:00:00',
    end_time = '2025-10-01 12:00:00',
    is_all_day = 0
WHERE title = '秋季校园招聘启动' 
AND assignee_id = 'dept-head-001';

-- Q4绩效管理培训 (10月18日 下午)
UPDATE tasks 
SET start_time = '2025-10-18 14:00:00',
    end_time = '2025-10-18 17:00:00',
    is_all_day = 0
WHERE title = 'Q4绩效管理培训' 
AND assignee_id = 'dept-head-001';

-- 员工福利体系升级方案汇报 (10月24日 上午)
UPDATE tasks 
SET start_time = '2025-10-24 09:30:00',
    end_time = '2025-10-24 11:00:00',
    is_all_day = 0
WHERE title = '员工福利体系升级方案' 
AND assignee_id = 'dept-head-001';

-- 人才梯队建设规划会议 (10月28日 下午)
UPDATE tasks 
SET start_time = '2025-10-28 15:00:00',
    end_time = '2025-10-28 17:30:00',
    is_all_day = 0
WHERE title = '人才梯队建设规划' 
AND assignee_id = 'dept-head-001';

-- 年度人力资源规划编制会议 (11月3日 上午)
UPDATE tasks 
SET start_time = '2025-11-03 09:00:00',
    end_time = '2025-11-03 12:00:00',
    is_all_day = 0
WHERE title = '年度人力资源规划编制' 
AND assignee_id = 'dept-head-001';

-- Q4人才盘点启动会 (11月3日 下午)
UPDATE tasks 
SET start_time = '2025-11-03 14:00:00',
    end_time = '2025-11-03 16:00:00',
    is_all_day = 0
WHERE title = 'Q4人才盘点' 
AND assignee_id = 'dept-head-001';

-- 员工职业发展规划辅导 (11月5日 下午)
UPDATE tasks 
SET start_time = '2025-11-05 14:30:00',
    end_time = '2025-11-05 17:30:00',
    is_all_day = 0
WHERE title = '员工职业发展规划辅导' 
AND assignee_id = 'dept-head-001';

-- 年度员工大会筹备会议 (11月14日 上午)
UPDATE tasks 
SET start_time = '2025-11-14 10:00:00',
    end_time = '2025-11-14 12:00:00',
    is_all_day = 0
WHERE title = '年度员工大会筹备' 
AND assignee_id = 'dept-head-001';

-- 劳动法规培训 (11月10日 全天)
UPDATE tasks 
SET start_time = '2025-11-10 09:00:00',
    end_time = '2025-11-10 17:00:00',
    is_all_day = 1
WHERE title = '劳动法规培训' 
AND assignee_id = 'dept-head-001';

-- 管理培训生项目设计研讨 (11月27日 下午)
UPDATE tasks 
SET start_time = '2025-11-27 14:00:00',
    end_time = '2025-11-27 16:30:00',
    is_all_day = 0
WHERE title = '管理培训生项目设计' 
AND assignee_id = 'dept-head-001';


-- 2. 创建新的任务（基于日志内容），让它们显示在时间轴上
-- 这些是会议、宣讲会等有明确时间的活动

-- 10月校园宣讲会
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-log-001', 'dept-head-001', '王人事总监', 'dept-001', '清华大学校园宣讲会', 
 '2025-10-12 14:00:00', '2025-10-12 16:30:00', 0, 'completed', '2025-10-12 09:00:00', 'dept-head-001'),
('task-hr-log-002', 'dept-head-001', '王人事总监', 'dept-001', '北京大学校园宣讲会', 
 '2025-10-13 15:00:00', '2025-10-13 17:00:00', 0, 'completed', '2025-10-13 09:00:00', 'dept-head-001'),
('task-hr-log-003', 'dept-head-001', '王人事总监', 'dept-001', '中国人民大学宣讲会', 
 '2025-10-14 14:30:00', '2025-10-14 16:30:00', 0, 'completed', '2025-10-14 09:00:00', 'dept-head-001'),
('task-hr-log-004', 'dept-head-001', '王人事总监', 'dept-001', '上海交通大学宣讲会', 
 '2025-10-19 14:00:00', '2025-10-19 16:30:00', 0, 'completed', '2025-10-19 09:00:00', 'dept-head-001'),
('task-hr-log-005', 'dept-head-001', '王人事总监', 'dept-001', '复旦大学校园宣讲会', 
 '2025-10-20 15:00:00', '2025-10-20 17:00:00', 0, 'completed', '2025-10-20 09:00:00', 'dept-head-001'),
('task-hr-log-006', 'dept-head-001', '王人事总监', 'dept-001', '浙江大学校园宣讲会', 
 '2025-10-21 14:00:00', '2025-10-21 16:00:00', 0, 'completed', '2025-10-21 09:00:00', 'dept-head-001'),
('task-hr-log-007', 'dept-head-001', '王人事总监', 'dept-001', '杭州电子科技大学宣讲会', 
 '2025-10-22 14:30:00', '2025-10-22 16:30:00', 0, 'completed', '2025-10-22 09:00:00', 'dept-head-001'),
('task-hr-log-008', 'dept-head-001', '王人事总监', 'dept-001', '哈工大深圳校区宣讲会', 
 '2025-10-27 14:00:00', '2025-10-27 16:00:00', 0, 'completed', '2025-10-27 09:00:00', 'dept-head-001'),
('task-hr-log-009', 'dept-head-001', '王人事总监', 'dept-001', '深圳大学校园宣讲会', 
 '2025-10-28 14:30:00', '2025-10-28 16:30:00', 0, 'completed', '2025-10-28 09:00:00', 'dept-head-001');

-- 重要会议
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-meeting-001', 'dept-head-001', '王人事总监', 'dept-001', '人事部门周会', 
 '2025-10-03 10:00:00', '2025-10-03 11:30:00', 0, 'completed', '2025-10-03 09:50:00', 'dept-head-001'),
('task-hr-meeting-002', 'dept-head-001', '王人事总监', 'dept-001', '人才梯队建设研讨会', 
 '2025-10-05 10:30:00', '2025-10-05 12:00:00', 0, 'completed', '2025-10-05 10:00:00', 'dept-head-001'),
('task-hr-meeting-003', 'dept-head-001', '王人事总监', 'dept-001', '董事会人力资源汇报', 
 '2025-10-07 14:00:00', '2025-10-07 16:00:00', 0, 'completed', '2025-10-07 09:00:00', 'dept-head-001'),
('task-hr-meeting-004', 'dept-head-001', '王人事总监', 'dept-001', '人才盘点战略会议', 
 '2025-10-17 10:00:00', '2025-10-17 12:00:00', 0, 'completed', '2025-10-17 09:00:00', 'dept-head-001'),
('task-hr-meeting-005', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统实施启动会', 
 '2025-10-26 15:00:00', '2025-10-26 16:30:00', 0, 'completed', '2025-10-26 09:00:00', 'dept-head-001'),
('task-hr-meeting-006', 'dept-head-001', '王人事总监', 'dept-001', 'HR数字化需求梳理会', 
 '2025-10-28 10:00:00', '2025-10-28 11:30:00', 0, 'completed', '2025-10-28 09:00:00', 'dept-head-001');

-- 11月会议
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-nov-001', 'dept-head-001', '王人事总监', 'dept-001', '员工福利升级方案发布会', 
 '2025-11-01 10:00:00', '2025-11-01 11:30:00', 0, 'completed', '2025-11-01 09:00:00', 'dept-head-001'),
('task-hr-nov-002', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会筹备启动会', 
 '2025-11-02 14:00:00', '2025-11-02 16:00:00', 0, 'completed', '2025-11-02 09:00:00', 'dept-head-001'),
('task-hr-nov-003', 'dept-head-001', '王人事总监', 'dept-001', 'Q4人才盘点启动会议', 
 '2025-11-03 10:00:00', '2025-11-03 11:30:00', 0, 'completed', '2025-11-03 09:00:00', 'dept-head-001'),
('task-hr-nov-004', 'dept-head-001', '王人事总监', 'dept-001', '与创始人沟通年度规划', 
 '2025-11-03 15:00:00', '2025-11-03 16:30:00', 0, 'completed', '2025-11-03 09:00:00', 'dept-head-001'),
('task-hr-nov-005', 'dept-head-001', '王人事总监', 'dept-001', '技术人才保留策略会议', 
 '2025-11-05 15:00:00', '2025-11-05 17:00:00', 0, 'completed', '2025-11-05 09:00:00', 'dept-head-001'),
('task-hr-nov-006', 'dept-head-001', '王人事总监', 'dept-001', '人才盘点高层汇报会', 
 '2025-11-14 10:00:00', '2025-11-14 12:00:00', 0, 'completed', '2025-11-14 09:00:00', 'dept-head-001'),
('task-hr-nov-007', 'dept-head-001', '王人事总监', 'dept-001', '年终奖方案高层评审会', 
 '2025-11-14 14:00:00', '2025-11-14 16:00:00', 0, 'completed', '2025-11-14 09:00:00', 'dept-head-001'),
('task-hr-nov-008', 'dept-head-001', '王人事总监', 'dept-001', '管理培训生项目评审会', 
 '2025-11-14 16:30:00', '2025-11-14 17:30:00', 0, 'completed', '2025-11-14 09:00:00', 'dept-head-001'),
('task-hr-nov-009', 'dept-head-001', '王人事总监', 'dept-001', '年度人力资源规划高层评审', 
 '2025-11-21 09:30:00', '2025-11-21 11:30:00', 0, 'completed', '2025-11-21 09:00:00', 'dept-head-001'),
('task-hr-nov-010', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会流程评审会', 
 '2025-11-21 14:00:00', '2025-11-21 15:30:00', 0, 'completed', '2025-11-21 09:00:00', 'dept-head-001');

-- HR系统培训
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-training-001', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统第一轮培训', 
 '2025-11-23 10:00:00', '2025-11-23 12:00:00', 0, 'completed', '2025-11-23 09:00:00', 'dept-head-001'),
('task-hr-training-002', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统第二轮培训', 
 '2025-11-25 10:00:00', '2025-11-25 12:00:00', 0, 'completed', '2025-11-25 09:00:00', 'dept-head-001'),
('task-hr-training-003', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统第三轮培训', 
 '2025-11-29 14:00:00', '2025-11-29 16:30:00', 0, 'completed', '2025-11-29 09:00:00', 'dept-head-001');

-- 其他活动
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-other-001', 'dept-head-001', '王人事总监', 'dept-001', '职场压力管理健康讲座', 
 '2025-11-23 15:00:00', '2025-11-23 16:30:00', 0, 'completed', '2025-11-23 09:00:00', 'dept-head-001'),
('task-hr-other-002', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会筹备推进会', 
 '2025-11-25 14:00:00', '2025-11-25 15:30:00', 0, 'completed', '2025-11-25 09:00:00', 'dept-head-001'),
('task-hr-other-003', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会彩排安排会', 
 '2025-11-29 10:00:00', '2025-11-29 11:00:00', 0, 'completed', '2025-11-29 09:00:00', 'dept-head-001'),
('task-hr-other-004', 'dept-head-001', '王人事总监', 'dept-001', '中国人力资源管理峰会', 
 '2025-10-11 09:00:00', '2025-10-11 17:00:00', 1, 'completed', '2025-10-11 08:00:00', 'dept-head-001');

-- 面试任务
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-interview-001', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘面试-上午场', 
 '2025-10-25 09:00:00', '2025-10-25 12:00:00', 0, 'completed', '2025-10-25 08:00:00', 'dept-head-001'),
('task-hr-interview-002', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘面试-下午场', 
 '2025-10-25 14:00:00', '2025-10-25 17:00:00', 0, 'completed', '2025-10-25 08:00:00', 'dept-head-001'),
('task-hr-interview-003', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘面试-全天', 
 '2025-10-26 09:00:00', '2025-10-26 17:00:00', 0, 'completed', '2025-10-26 08:00:00', 'dept-head-001');

-- 周例会
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-weekly-001', 'dept-head-001', '王人事总监', 'dept-001', '核心员工一对一面谈', 
 '2025-10-07 09:00:00', '2025-10-07 10:30:00', 0, 'completed', '2025-10-07 08:00:00', 'dept-head-001'),
('task-hr-weekly-002', 'dept-head-001', '王人事总监', 'dept-001', '核心员工一对一面谈', 
 '2025-10-14 09:00:00', '2025-10-14 10:30:00', 0, 'completed', '2025-10-14 08:00:00', 'dept-head-001'),
('task-hr-weekly-003', 'dept-head-001', '王人事总监', 'dept-001', '核心员工一对一面谈', 
 '2025-10-21 09:00:00', '2025-10-21 10:30:00', 0, 'completed', '2025-10-21 08:00:00', 'dept-head-001'),
('task-hr-weekly-004', 'dept-head-001', '王人事总监', 'dept-001', 'HR部门周例会', 
 '2025-11-04 09:00:00', '2025-11-04 10:00:00', 0, 'completed', '2025-11-04 08:00:00', 'dept-head-001'),
('task-hr-weekly-005', 'dept-head-001', '王人事总监', 'dept-001', 'HR部门周例会', 
 '2025-11-11 09:00:00', '2025-11-11 10:00:00', 0, 'completed', '2025-11-11 08:00:00', 'dept-head-001'),
('task-hr-weekly-006', 'dept-head-001', '王人事总监', 'dept-001', 'HR部门周例会', 
 '2025-11-18 09:00:00', '2025-11-18 10:00:00', 0, 'completed', '2025-11-18 08:00:00', 'dept-head-001'),
('task-hr-weekly-007', 'dept-head-001', '王人事总监', 'dept-001', 'HR部门周例会', 
 '2025-11-25 09:00:00', '2025-11-25 10:00:00', 0, 'completed', '2025-11-25 08:00:00', 'dept-head-001');

-- Q4团建活动 (2天全天)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-teambuilding-001', 'dept-head-001', '王人事总监', 'dept-001', 'Q4团建活动-第一天', 
 '2025-11-16 09:00:00', '2025-11-16 18:00:00', 1, 'completed', '2025-11-15 09:00:00', 'dept-head-001'),
('task-hr-teambuilding-002', 'dept-head-001', '王人事总监', 'dept-001', 'Q4团建活动-第二天', 
 '2025-11-17 09:00:00', '2025-11-17 17:00:00', 1, 'completed', '2025-11-15 09:00:00', 'dept-head-001');


-- 查看更新结果
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN start_time IS NOT NULL AND is_all_day = 0 THEN 1 ELSE 0 END) as tasks_with_time,
  SUM(CASE WHEN start_time IS NOT NULL AND is_all_day = 1 THEN 1 ELSE 0 END) as all_day_tasks,
  SUM(CASE WHEN start_time IS NULL THEN 1 ELSE 0 END) as tasks_without_time
FROM tasks
WHERE assignee_id = 'dept-head-001';

SELECT '更新完成！' as status;
