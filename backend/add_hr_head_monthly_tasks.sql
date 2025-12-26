-- ========================================
-- 为 hr_head 用户增加大量月度任务数据
-- 目标：每月约20条任务，时间段2-4天，状态分布合理
-- ========================================

USE enterprise_management;

-- ========================================
-- 2025年9月任务 (20条)
-- ========================================

-- 待处理任务 (10条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-sep-001', 'dept-head-001', '王人事总监', 'dept-001', '秋季招聘计划制定', 
 '2025-09-01 09:00:00', '2025-09-03 18:00:00', 0, 'pending', '2025-08-29 10:00:00', 'dept-head-001'),
('task-hr-sep-002', 'dept-head-001', '王人事总监', 'dept-001', '员工满意度调查方案设计', 
 '2025-09-04 10:00:00', '2025-09-06 17:00:00', 0, 'pending', '2025-09-01 09:00:00', 'dept-head-001'),
('task-hr-sep-003', 'dept-head-001', '王人事总监', 'dept-001', 'Q3绩效评估标准修订', 
 '2025-09-09 09:00:00', '2025-09-11 18:00:00', 0, 'pending', '2025-09-05 10:00:00', 'dept-head-001'),
('task-hr-sep-004', 'dept-head-001', '王人事总监', 'dept-001', '新员工培训课程优化', 
 '2025-09-12 14:00:00', '2025-09-14 17:00:00', 0, 'pending', '2025-09-10 09:00:00', 'dept-head-001'),
('task-hr-sep-005', 'dept-head-001', '王人事总监', 'dept-001', '人才测评工具选型调研', 
 '2025-09-16 09:30:00', '2025-09-19 16:30:00', 0, 'pending', '2025-09-13 10:00:00', 'dept-head-001'),
('task-hr-sep-006', 'dept-head-001', '王人事总监', 'dept-001', '薪酬福利市场调研报告', 
 '2025-09-20 10:00:00', '2025-09-23 18:00:00', 0, 'pending', '2025-09-18 09:00:00', 'dept-head-001'),
('task-hr-sep-007', 'dept-head-001', '王人事总监', 'dept-001', '企业文化建设方案研讨', 
 '2025-09-24 09:00:00', '2025-09-26 17:00:00', 0, 'pending', '2025-09-22 10:00:00', 'dept-head-001'),
('task-hr-sep-008', 'dept-head-001', '王人事总监', 'dept-001', '年度人力成本预算编制', 
 '2025-09-25 14:00:00', '2025-09-27 18:00:00', 0, 'pending', '2025-09-23 09:00:00', 'dept-head-001'),
('task-hr-sep-009', 'dept-head-001', '王人事总监', 'dept-001', '组织架构调整方案评审', 
 '2025-09-27 10:00:00', '2025-09-29 16:00:00', 0, 'pending', '2025-09-25 10:00:00', 'dept-head-001'),
('task-hr-sep-010', 'dept-head-001', '王人事总监', 'dept-001', '人才发展规划季度总结', 
 '2025-09-28 09:00:00', '2025-09-30 17:00:00', 0, 'pending', '2025-09-26 09:00:00', 'dept-head-001');

-- 进行中任务 (4条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-sep-011', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘渠道拓展合作', 
 '2025-09-05 10:00:00', '2025-09-07 18:00:00', 0, 'in_progress', '2025-09-03 09:00:00', 'dept-head-001'),
('task-hr-sep-012', 'dept-head-001', '王人事总监', 'dept-001', '管理培训体系搭建项目', 
 '2025-09-10 09:00:00', '2025-09-13 17:00:00', 0, 'in_progress', '2025-09-08 10:00:00', 'dept-head-001'),
('task-hr-sep-013', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统功能需求确认', 
 '2025-09-17 14:00:00', '2025-09-19 18:00:00', 0, 'in_progress', '2025-09-15 09:00:00', 'dept-head-001'),
('task-hr-sep-014', 'dept-head-001', '王人事总监', 'dept-001', '劳动合同模板更新审核', 
 '2025-09-23 10:00:00', '2025-09-25 16:00:00', 0, 'in_progress', '2025-09-20 10:00:00', 'dept-head-001');

-- 已完成任务 (6条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-sep-015', 'dept-head-001', '王人事总监', 'dept-001', '新员工入职培训会', 
 '2025-09-02 09:00:00', '2025-09-04 17:00:00', 0, 'completed', '2025-08-30 10:00:00', 'dept-head-001'),
('task-hr-sep-016', 'dept-head-001', '王人事总监', 'dept-001', '部门负责人管理沟通会', 
 '2025-09-06 14:00:00', '2025-09-08 16:00:00', 0, 'completed', '2025-09-04 09:00:00', 'dept-head-001'),
('task-hr-sep-017', 'dept-head-001', '王人事总监', 'dept-001', 'Q3人才盘点启动会议', 
 '2025-09-11 10:00:00', '2025-09-13 15:00:00', 0, 'completed', '2025-09-09 10:00:00', 'dept-head-001'),
('task-hr-sep-018', 'dept-head-001', '王人事总监', 'dept-001', '员工关怀活动策划执行', 
 '2025-09-15 09:00:00', '2025-09-17 18:00:00', 0, 'completed', '2025-09-12 10:00:00', 'dept-head-001'),
('task-hr-sep-019', 'dept-head-001', '王人事总监', 'dept-001', '中秋节福利发放筹备', 
 '2025-09-13 14:00:00', '2025-09-15 17:00:00', 0, 'completed', '2025-09-11 09:00:00', 'dept-head-001'),
('task-hr-sep-020', 'dept-head-001', '王人事总监', 'dept-001', 'HR数据分析报告编制', 
 '2025-09-26 10:00:00', '2025-09-28 18:00:00', 0, 'completed', '2025-09-24 09:00:00', 'dept-head-001');


-- ========================================
-- 2025年10月任务 (20条)
-- ========================================

-- 待处理任务 (10条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-oct-001', 'dept-head-001', '王人事总监', 'dept-001', '秋季校园招聘行程规划', 
 '2025-10-02 09:00:00', '2025-10-04 17:00:00', 0, 'pending', '2025-09-30 10:00:00', 'dept-head-001'),
('task-hr-oct-002', 'dept-head-001', '王人事总监', 'dept-001', '年度培训需求调研分析', 
 '2025-10-08 10:00:00', '2025-10-10 18:00:00', 0, 'pending', '2025-10-05 09:00:00', 'dept-head-001'),
('task-hr-oct-003', 'dept-head-001', '王人事总监', 'dept-001', 'Q4绩效目标设定指导', 
 '2025-10-15 09:00:00', '2025-10-17 17:00:00', 0, 'pending', '2025-10-12 10:00:00', 'dept-head-001'),
('task-hr-oct-004', 'dept-head-001', '王人事总监', 'dept-001', '关键岗位继任者计划制定', 
 '2025-10-21 14:00:00', '2025-10-23 18:00:00', 0, 'pending', '2025-10-18 09:00:00', 'dept-head-001'),
('task-hr-oct-005', 'dept-head-001', '王人事总监', 'dept-001', '员工职业发展通道设计', 
 '2025-10-23 09:00:00', '2025-10-25 17:00:00', 0, 'pending', '2025-10-20 10:00:00', 'dept-head-001'),
('task-hr-oct-006', 'dept-head-001', '王人事总监', 'dept-001', '年度薪酬调整方案准备', 
 '2025-10-28 10:00:00', '2025-10-31 18:00:00', 0, 'pending', '2025-10-25 09:00:00', 'dept-head-001'),
('task-hr-oct-007', 'dept-head-001', '王人事总监', 'dept-001', '企业文化宣传内容策划', 
 '2025-10-16 14:00:00', '2025-10-18 17:00:00', 0, 'pending', '2025-10-14 10:00:00', 'dept-head-001'),
('task-hr-oct-008', 'dept-head-001', '王人事总监', 'dept-001', '员工健康管理体系优化', 
 '2025-10-24 09:00:00', '2025-10-26 16:00:00', 0, 'pending', '2025-10-22 09:00:00', 'dept-head-001'),
('task-hr-oct-009', 'dept-head-001', '王人事总监', 'dept-001', '人才引进政策优化调研', 
 '2025-10-29 10:00:00', '2025-10-31 17:00:00', 0, 'pending', '2025-10-27 10:00:00', 'dept-head-001'),
('task-hr-oct-010', 'dept-head-001', '王人事总监', 'dept-001', '组织能力提升项目规划', 
 '2025-10-30 14:00:00', '2025-11-01 18:00:00', 0, 'pending', '2025-10-28 09:00:00', 'dept-head-001');

-- 进行中任务 (4条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-oct-011', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘宣讲会执行', 
 '2025-10-12 09:00:00', '2025-10-14 18:00:00', 0, 'in_progress', '2025-10-10 10:00:00', 'dept-head-001'),
('task-hr-oct-012', 'dept-head-001', '王人事总监', 'dept-001', '核心人才保留计划实施', 
 '2025-10-19 10:00:00', '2025-10-22 17:00:00', 0, 'in_progress', '2025-10-16 09:00:00', 'dept-head-001'),
('task-hr-oct-013', 'dept-head-001', '王人事总监', 'dept-001', 'HR数字化转型需求调研', 
 '2025-10-25 09:00:00', '2025-10-28 18:00:00', 0, 'in_progress', '2025-10-23 10:00:00', 'dept-head-001'),
('task-hr-oct-014', 'dept-head-001', '王人事总监', 'dept-001', '员工满意度提升行动计划', 
 '2025-10-26 14:00:00', '2025-10-29 17:00:00', 0, 'in_progress', '2025-10-24 09:00:00', 'dept-head-001');

-- 已完成任务 (6条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-oct-015', 'dept-head-001', '王人事总监', 'dept-001', '国庆节值班安排协调', 
 '2025-09-28 14:00:00', '2025-09-30 17:00:00', 0, 'completed', '2025-09-26 10:00:00', 'dept-head-001'),
('task-hr-oct-016', 'dept-head-001', '王人事总监', 'dept-001', '新员工试用期考核评估', 
 '2025-10-05 09:00:00', '2025-10-07 18:00:00', 0, 'completed', '2025-10-03 09:00:00', 'dept-head-001'),
('task-hr-oct-017', 'dept-head-001', '王人事总监', 'dept-001', 'Q3人才盘点结果汇报', 
 '2025-10-09 10:00:00', '2025-10-11 16:00:00', 0, 'completed', '2025-10-07 10:00:00', 'dept-head-001'),
('task-hr-oct-018', 'dept-head-001', '王人事总监', 'dept-001', '部门团建活动组织实施', 
 '2025-10-13 09:00:00', '2025-10-15 18:00:00', 0, 'completed', '2025-10-10 09:00:00', 'dept-head-001'),
('task-hr-oct-019', 'dept-head-001', '王人事总监', 'dept-001', '高潜人才发展研讨会', 
 '2025-10-20 14:00:00', '2025-10-22 17:00:00', 0, 'completed', '2025-10-18 10:00:00', 'dept-head-001'),
('task-hr-oct-020', 'dept-head-001', '王人事总监', 'dept-001', '劳动关系风险排查处理', 
 '2025-10-27 10:00:00', '2025-10-29 16:00:00', 0, 'completed', '2025-10-25 09:00:00', 'dept-head-001');


-- ========================================
-- 2025年11月任务 (20条)
-- ========================================

-- 待处理任务 (10条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-nov-101', 'dept-head-001', '王人事总监', 'dept-001', '年度人力资源战略规划', 
 '2025-11-04 09:00:00', '2025-11-07 18:00:00', 0, 'pending', '2025-11-01 10:00:00', 'dept-head-001'),
('task-hr-nov-102', 'dept-head-001', '王人事总监', 'dept-001', '年终绩效评估流程优化', 
 '2025-11-08 10:00:00', '2025-11-11 17:00:00', 0, 'pending', '2025-11-05 09:00:00', 'dept-head-001'),
('task-hr-nov-103', 'dept-head-001', '王人事总监', 'dept-001', '2026年培训计划编制', 
 '2025-11-12 09:00:00', '2025-11-15 18:00:00', 0, 'pending', '2025-11-09 10:00:00', 'dept-head-001'),
('task-hr-nov-104', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘offer发放审批', 
 '2025-11-18 14:00:00', '2025-11-20 17:00:00', 0, 'pending', '2025-11-15 09:00:00', 'dept-head-001'),
('task-hr-nov-105', 'dept-head-001', '王人事总监', 'dept-001', '年度员工关怀计划设计', 
 '2025-11-21 09:00:00', '2025-11-23 18:00:00', 0, 'pending', '2025-11-18 10:00:00', 'dept-head-001'),
('task-hr-nov-106', 'dept-head-001', '王人事总监', 'dept-001', '组织架构优化方案讨论', 
 '2025-11-25 10:00:00', '2025-11-28 17:00:00', 0, 'pending', '2025-11-22 09:00:00', 'dept-head-001'),
('task-hr-nov-107', 'dept-head-001', '王人事总监', 'dept-001', '人才发展体系年度回顾', 
 '2025-11-26 14:00:00', '2025-11-29 18:00:00', 0, 'pending', '2025-11-24 10:00:00', 'dept-head-001'),
('task-hr-nov-108', 'dept-head-001', '王人事总监', 'dept-001', '2026年招聘预算编制', 
 '2025-11-27 09:00:00', '2025-11-30 17:00:00', 0, 'pending', '2025-11-25 09:00:00', 'dept-head-001'),
('task-hr-nov-109', 'dept-head-001', '王人事总监', 'dept-001', '员工离职率分析报告', 
 '2025-11-28 10:00:00', '2025-11-30 18:00:00', 0, 'pending', '2025-11-26 10:00:00', 'dept-head-001'),
('task-hr-nov-110', 'dept-head-001', '王人事总监', 'dept-001', '年度HR工作总结材料', 
 '2025-11-29 14:00:00', '2025-12-02 17:00:00', 0, 'pending', '2025-11-27 09:00:00', 'dept-head-001');

-- 进行中任务 (4条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-nov-111', 'dept-head-001', '王人事总监', 'dept-001', '年度员工大会筹备执行', 
 '2025-11-10 09:00:00', '2025-11-13 18:00:00', 0, 'in_progress', '2025-11-08 10:00:00', 'dept-head-001'),
('task-hr-nov-112', 'dept-head-001', '王人事总监', 'dept-001', 'Q4人才盘点实施推进', 
 '2025-11-15 10:00:00', '2025-11-18 17:00:00', 0, 'in_progress', '2025-11-12 09:00:00', 'dept-head-001'),
('task-hr-nov-113', 'dept-head-001', '王人事总监', 'dept-001', 'HR系统上线培训组织', 
 '2025-11-22 09:00:00', '2025-11-25 18:00:00', 0, 'in_progress', '2025-11-20 10:00:00', 'dept-head-001'),
('task-hr-nov-114', 'dept-head-001', '王人事总监', 'dept-001', '年终奖方案制定审核', 
 '2025-11-24 14:00:00', '2025-11-27 17:00:00', 0, 'in_progress', '2025-11-22 09:00:00', 'dept-head-001');

-- 已完成任务 (6条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-nov-115', 'dept-head-001', '王人事总监', 'dept-001', '新员工转正评估面谈', 
 '2025-11-01 09:00:00', '2025-11-03 17:00:00', 0, 'completed', '2025-10-30 10:00:00', 'dept-head-001'),
('task-hr-nov-116', 'dept-head-001', '王人事总监', 'dept-001', '部门管理者领导力培训', 
 '2025-11-05 10:00:00', '2025-11-07 18:00:00', 0, 'completed', '2025-11-02 09:00:00', 'dept-head-001'),
('task-hr-nov-117', 'dept-head-001', '王人事总监', 'dept-001', '薪酬福利满意度调研', 
 '2025-11-09 09:00:00', '2025-11-11 16:00:00', 0, 'completed', '2025-11-06 10:00:00', 'dept-head-001'),
('task-hr-nov-118', 'dept-head-001', '王人事总监', 'dept-001', '校园招聘简历筛选面试', 
 '2025-11-16 14:00:00', '2025-11-19 18:00:00', 0, 'completed', '2025-11-14 09:00:00', 'dept-head-001'),
('task-hr-nov-119', 'dept-head-001', '王人事总监', 'dept-001', '企业文化宣传月启动', 
 '2025-11-19 09:00:00', '2025-11-21 17:00:00', 0, 'completed', '2025-11-17 10:00:00', 'dept-head-001'),
('task-hr-nov-120', 'dept-head-001', '王人事总监', 'dept-001', '劳动合同续签集中办理', 
 '2025-11-23 10:00:00', '2025-11-26 16:00:00', 0, 'completed', '2025-11-21 09:00:00', 'dept-head-001');


-- ========================================
-- 2025年12月任务 (20条)
-- ========================================

-- 待处理任务 (10条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-dec-001', 'dept-head-001', '王人事总监', 'dept-001', '年终绩效评估启动会', 
 '2025-12-02 09:00:00', '2025-12-04 17:00:00', 0, 'pending', '2025-11-29 10:00:00', 'dept-head-001'),
('task-hr-dec-002', 'dept-head-001', '王人事总监', 'dept-001', '2026年人力资源预算汇报', 
 '2025-12-05 10:00:00', '2025-12-08 18:00:00', 0, 'pending', '2025-12-02 09:00:00', 'dept-head-001'),
('task-hr-dec-003', 'dept-head-001', '王人事总监', 'dept-001', '年度优秀员工评选组织', 
 '2025-12-09 09:00:00', '2025-12-12 17:00:00', 0, 'pending', '2025-12-06 10:00:00', 'dept-head-001'),
('task-hr-dec-004', 'dept-head-001', '王人事总监', 'dept-001', '春节福利方案审批发放', 
 '2025-12-13 14:00:00', '2025-12-16 18:00:00', 0, 'pending', '2025-12-10 09:00:00', 'dept-head-001'),
('task-hr-dec-005', 'dept-head-001', '王人事总监', 'dept-001', '年度人才盘点总结报告', 
 '2025-12-16 09:00:00', '2025-12-19 17:00:00', 0, 'pending', '2025-12-13 10:00:00', 'dept-head-001'),
('task-hr-dec-006', 'dept-head-001', '王人事总监', 'dept-001', '2026年组织发展规划', 
 '2025-12-20 10:00:00', '2025-12-23 18:00:00', 0, 'pending', '2025-12-17 09:00:00', 'dept-head-001'),
('task-hr-dec-007', 'dept-head-001', '王人事总监', 'dept-001', '年终奖金方案高层评审', 
 '2025-12-23 09:00:00', '2025-12-25 17:00:00', 0, 'pending', '2025-12-20 10:00:00', 'dept-head-001'),
('task-hr-dec-008', 'dept-head-001', '王人事总监', 'dept-001', '年度HR数据统计分析', 
 '2025-12-24 14:00:00', '2025-12-27 18:00:00', 0, 'pending', '2025-12-22 09:00:00', 'dept-head-001'),
('task-hr-dec-009', 'dept-head-001', '王人事总监', 'dept-001', '员工年假统筹安排通知', 
 '2025-12-26 09:00:00', '2025-12-28 16:00:00', 0, 'pending', '2025-12-24 10:00:00', 'dept-head-001'),
('task-hr-dec-010', 'dept-head-001', '王人事总监', 'dept-001', '2026年人才战略规划', 
 '2025-12-27 10:00:00', '2025-12-30 18:00:00', 0, 'pending', '2025-12-25 09:00:00', 'dept-head-001');

-- 进行中任务 (4条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-dec-011', 'dept-head-001', '王人事总监', 'dept-001', '年度员工满意度调研', 
 '2025-12-10 09:00:00', '2025-12-13 18:00:00', 0, 'in_progress', '2025-12-08 10:00:00', 'dept-head-001'),
('task-hr-dec-012', 'dept-head-001', '王人事总监', 'dept-001', '年会节目排练组织协调', 
 '2025-12-17 10:00:00', '2025-12-20 17:00:00', 0, 'in_progress', '2025-12-14 09:00:00', 'dept-head-001'),
('task-hr-dec-013', 'dept-head-001', '王人事总监', 'dept-001', '新入职员工关怀计划', 
 '2025-12-21 09:00:00', '2025-12-24 18:00:00', 0, 'in_progress', '2025-12-19 10:00:00', 'dept-head-001'),
('task-hr-dec-014', 'dept-head-001', '王人事总监', 'dept-001', '年终绩效面谈指导培训', 
 '2025-12-28 14:00:00', '2025-12-31 17:00:00', 0, 'in_progress', '2025-12-26 09:00:00', 'dept-head-001');

-- 已完成任务 (6条)
INSERT INTO tasks (id, assignee_id, assignee_name, department_id, title, start_time, end_time, is_all_day, status, created_at, created_by)
VALUES 
('task-hr-dec-015', 'dept-head-001', '王人事总监', 'dept-001', '年度工作总结会议召开', 
 '2025-12-01 09:00:00', '2025-12-03 17:00:00', 0, 'completed', '2025-11-28 10:00:00', 'dept-head-001'),
('task-hr-dec-016', 'dept-head-001', '王人事总监', 'dept-001', '核心人才年终面谈沟通', 
 '2025-12-06 10:00:00', '2025-12-09 18:00:00', 0, 'completed', '2025-12-04 09:00:00', 'dept-head-001'),
('task-hr-dec-017', 'dept-head-001', '王人事总监', 'dept-001', '社保公积金年度核算', 
 '2025-12-11 09:00:00', '2025-12-13 16:00:00', 0, 'completed', '2025-12-09 10:00:00', 'dept-head-001'),
('task-hr-dec-018', 'dept-head-001', '王人事总监', 'dept-001', '年度招聘效果评估分析', 
 '2025-12-14 14:00:00', '2025-12-17 18:00:00', 0, 'completed', '2025-12-12 09:00:00', 'dept-head-001'),
('task-hr-dec-019', 'dept-head-001', '王人事总监', 'dept-001', '年终晚会筹备最终确认', 
 '2025-12-18 09:00:00', '2025-12-20 17:00:00', 0, 'completed', '2025-12-16 10:00:00', 'dept-head-001'),
('task-hr-dec-020', 'dept-head-001', '王人事总监', 'dept-001', '劳动用工合规性自查', 
 '2025-12-22 10:00:00', '2025-12-24 16:00:00', 0, 'completed', '2025-12-20 09:00:00', 'dept-head-001');


-- ========================================
-- 数据统计验证
-- ========================================

-- 查看各月任务统计
SELECT 
  DATE_FORMAT(start_time, '%Y-%m') as month,
  COUNT(*) as total_tasks,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_tasks,
  SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_tasks,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
  ROUND(AVG(TIMESTAMPDIFF(DAY, start_time, end_time)), 1) as avg_days
FROM tasks
WHERE assignee_id = 'dept-head-001'
  AND start_time >= '2025-09-01'
GROUP BY DATE_FORMAT(start_time, '%Y-%m')
ORDER BY month;

-- 查看总体统计
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
  SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
  CONCAT(ROUND(SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1), '%') as pending_percent,
  CONCAT(ROUND(SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1), '%') as in_progress_percent,
  CONCAT(ROUND(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1), '%') as completed_percent
FROM tasks
WHERE assignee_id = 'dept-head-001'
  AND start_time >= '2025-09-01';

SELECT '✅ HR Head 月度任务数据添加完成！' as status;


