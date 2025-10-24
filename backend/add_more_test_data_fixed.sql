-- ================================================================
-- 增加更多测试数据 - 让月视图更丰富（修复版）
-- ================================================================

USE enterprise_management;

-- ================================================================
-- 清理可能存在的旧数据
-- ================================================================
DELETE FROM personal_logs WHERE id LIKE 'log-hr-head-%' OR id LIKE 'log-f001-%' OR id LIKE 'log-emp1-%';
DELETE FROM tasks WHERE id LIKE 'task-hr-head-%' OR id LIKE 'task-f001-%' OR id LIKE 'task-emp1-%';

-- ================================================================
-- 为 hr_head 用户增加更多数据
-- ================================================================

-- 9月的额外日志（5条）
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-hr-head-sep3', 'dept-head-001', '新员工入职培训', '组织了10名新员工的入职培训，介绍公司文化和规章制度。培训效果良好，新员工反馈积极。', 'work', NULL, NULL, 1, '2025-09-06 10:30:00'),
('log-hr-head-sep4', 'dept-head-001', '面试候选人', '今天面试了3位高级开发工程师候选人，其中2位技术能力较强，已推荐进入终面。', 'work', NULL, NULL, 1, '2025-09-10 14:00:00'),
('log-hr-head-sep5', 'dept-head-001', '部门周会', '召开HR部门周会，讨论了Q4招聘进度、员工关怀计划和年底活动筹备等事项。', 'work', NULL, NULL, 1, '2025-09-13 16:00:00'),
('log-hr-head-sep6', 'dept-head-001', '员工离职面谈', '与即将离职的员工进行了深入沟通，了解离职原因，为改进公司管理提供参考。', 'work', NULL, NULL, 1, '2025-09-25 11:00:00'),
('log-hr-head-sep7', 'dept-head-001', '周末家庭聚餐', '周末和家人一起去了新开的日料店，享受了难得的家庭时光。', 'life', NULL, NULL, 1, '2025-09-28 19:00:00');

-- 9月的额外任务（4个）
INSERT INTO tasks (id, title, description, status, priority, color, start_time, end_time, deadline, is_all_day, created_at, created_by, assignee_id, assignee_name, department_id) VALUES
('task-hr-head-sep2', '完成9月招聘报告', '整理9月份的招聘数据，包括简历筛选、面试安排、录用情况等。', 'completed', 'p1', '#4CAF50', NULL, NULL, '2025-09-08 18:00:00', 0, '2025-09-01 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-sep3', '更新员工手册', '根据最新的公司政策，更新员工手册内容，并发送给全体员工。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-09-15 18:00:00', 0, '2025-09-02 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-sep4', '组织团建活动', '策划并组织9月份的部门团建活动，提升团队凝聚力。', 'completed', 'p2', '#4CAF50', '2025-09-22 10:00:00', '2025-09-22 17:00:00', '2025-09-22 17:00:00', 1, '2025-09-05 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-sep5', '薪酬调研报告', '调研同行业薪酬水平，为公司薪酬体系调整提供依据。', 'completed', 'p1', '#4CAF50', NULL, NULL, '2025-09-30 18:00:00', 0, '2025-09-10 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001');

-- 10月的额外日志（6条）
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-hr-head-oct3', 'dept-head-001', 'Q4招聘启动会', '召开Q4招聘启动会议，明确各岗位招聘需求和时间节点。', 'work', NULL, NULL, 1, '2025-10-02 10:00:00'),
('log-hr-head-oct4', 'dept-head-001', '处理员工投诉', '妥善处理了一起员工投诉事件，与相关部门协调解决。', 'work', NULL, NULL, 1, '2025-10-08 14:30:00'),
('log-hr-head-oct5', 'dept-head-001', '参加HR论坛', '参加了本地HR从业者论坛，学习了最新的人力资源管理理念。', 'work', NULL, NULL, 1, '2025-10-12 09:00:00'),
('log-hr-head-oct6', 'dept-head-001', '员工生日会', '为10月生日的员工准备了生日会，营造温馨的企业氛围。', 'work', NULL, NULL, 1, '2025-10-18 16:00:00'),
('log-hr-head-oct7', 'dept-head-001', '健身打卡', '下班后去健身房锻炼了1小时，保持身体健康很重要。', 'life', NULL, NULL, 1, '2025-10-25 19:00:00'),
('log-hr-head-oct8', 'dept-head-001', '阅读管理书籍', '周末阅读了《高效能人士的七个习惯》，很有启发。', 'life', NULL, NULL, 1, '2025-10-27 15:00:00');

-- 10月的额外任务（5个）
INSERT INTO tasks (id, title, description, status, priority, color, start_time, end_time, deadline, is_all_day, created_at, created_by, assignee_id, assignee_name, department_id) VALUES
('task-hr-head-oct2', '员工满意度调查', '设计并发放员工满意度调查问卷，收集员工反馈。', 'completed', 'p1', '#4CAF50', NULL, NULL, '2025-10-05 18:00:00', 0, '2025-10-01 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-oct3', '完善考勤制度', '根据公司发展需要，完善考勤管理制度，提交审批。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-10-10 18:00:00', 0, '2025-10-02 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-oct4', '人才库建设', '建立公司人才库系统，录入历史候选人信息。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-10-18 18:00:00', 0, '2025-10-05 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-oct5', '培训体系规划', '规划2026年度员工培训体系，制定培训计划。', 'in_progress', 'p1', '#FF9800', NULL, NULL, '2025-10-28 18:00:00', 0, '2025-10-10 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-oct6', '员工体检安排', '联系体检机构，安排全体员工年度健康体检。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-10-31 18:00:00', 0, '2025-10-15 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001');

-- 11月的额外日志（7条）
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-hr-head-nov3', 'dept-head-001', '年度预算规划', '开始规划2026年HR部门预算，包括招聘、培训、员工活动等各项开支。', 'work', NULL, NULL, 1, '2025-11-01 10:00:00'),
('log-hr-head-nov4', 'dept-head-001', '高管面试', '协助CEO面试副总经理候选人，提供专业的人才评估建议。', 'work', NULL, NULL, 1, '2025-11-05 14:00:00'),
('log-hr-head-nov5', 'dept-head-001', '员工关怀访谈', '走访各部门，与员工进行一对一访谈，了解他们的工作状态和需求。', 'work', NULL, NULL, 1, '2025-11-12 15:30:00'),
('log-hr-head-nov6', 'dept-head-001', '双十一购物', '双十一囤了一些日用品和冬装，省了不少钱。', 'life', NULL, NULL, 1, '2025-11-11 22:00:00'),
('log-hr-head-nov7', 'dept-head-001', '年终奖方案讨论', '与财务部和管理层讨论年终奖发放方案，确保公平合理。', 'work', NULL, NULL, 1, '2025-11-15 16:00:00'),
('log-hr-head-nov8', 'dept-head-001', '劳动法培训', '参加了劳动法更新培训，了解最新的劳动法规变化。', 'work', NULL, NULL, 1, '2025-11-22 14:00:00'),
('log-hr-head-nov9', 'dept-head-001', '感恩节聚会', '参加了朋友组织的感恩节聚会，度过了愉快的周末。', 'life', NULL, NULL, 1, '2025-11-28 18:00:00');

-- 11月的额外任务（5个）
INSERT INTO tasks (id, title, description, status, priority, color, start_time, end_time, deadline, is_all_day, created_at, created_by, assignee_id, assignee_name, department_id) VALUES
('task-hr-head-nov2', '年终绩效准备', '准备年终绩效考核材料，设计考核表格和流程。', 'in_progress', 'p0', '#FF9800', NULL, NULL, '2025-11-10 18:00:00', 0, '2025-11-01 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-nov3', '优化招聘流程', '根据今年的招聘经验，优化招聘流程，提高效率。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-11-12 18:00:00', 0, '2025-11-02 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-nov4', '员工福利方案', '设计2026年员工福利方案，提升员工满意度和归属感。', 'in_progress', 'p1', '#FF9800', NULL, NULL, '2025-11-18 18:00:00', 0, '2025-11-05 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-nov5', '年会筹备', '开始筹备公司年会，包括场地、节目、奖品等安排。', 'pending', 'p1', '#2196F3', NULL, NULL, '2025-11-25 18:00:00', 0, '2025-11-08 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001'),
('task-hr-head-nov6', '人力成本分析', '分析2025年人力成本，为2026年预算提供数据支持。', 'completed', 'p1', '#4CAF50', NULL, NULL, '2025-11-30 18:00:00', 0, '2025-11-10 09:00:00', 'dept-head-001', 'dept-head-001', 'Wang HR Director', 'dept-001');

-- ================================================================
-- 为其他用户也增加一些数据
-- ================================================================

-- 为 founder-001 增加更多数据
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-f001-sep4', 'founder-001', '投资人会议', '与潜在投资人会面，讨论新一轮融资计划。', 'work', NULL, NULL, 1, '2025-09-12 14:00:00'),
('log-f001-oct4', 'founder-001', '产品路线图规划', '与产品团队讨论未来6个月的产品路线图。', 'work', NULL, NULL, 1, '2025-10-08 10:00:00'),
('log-f001-nov3', 'founder-001', '商务谈判', '成功与大客户签订战略合作协议。', 'work', NULL, NULL, 1, '2025-11-15 16:00:00');

INSERT INTO tasks (id, title, description, status, priority, color, start_time, end_time, deadline, is_all_day, created_at, created_by, assignee_id, assignee_name, department_id) VALUES
('task-f001-sep2', '业务战略会议', '召开业务战略规划会议，确定下一阶段发展方向。', 'completed', 'p0', '#4CAF50', '2025-09-15 09:00:00', '2025-09-15 17:00:00', '2025-09-15 17:00:00', 1, '2025-09-01 09:00:00', 'founder-001', 'founder-001', 'Zhang Founder', 'dept-001'),
('task-f001-oct3', '市场拓展计划', '制定Q4市场拓展计划，包括目标客户和营销策略。', 'completed', 'p0', '#4CAF50', NULL, NULL, '2025-10-20 18:00:00', 0, '2025-10-01 09:00:00', 'founder-001', 'founder-001', 'Zhang Founder', 'dept-001');

-- 为 employee-001 增加更多数据
INSERT INTO personal_logs (id, user_id, title, content, category, quadrant, related_task_id, is_completed, created_at) VALUES
('log-emp1-sep4', 'employee-001', '筛选技术简历', '筛选了50份技术岗位简历，筛出15份合适的进入面试。', 'work', NULL, NULL, 1, '2025-09-14 16:00:00'),
('log-emp1-oct4', 'employee-001', '协调面试安排', '协调本周的10场面试安排，确保时间不冲突。', 'work', NULL, NULL, 1, '2025-10-16 11:00:00'),
('log-emp1-nov4', 'employee-001', '入职手续办理', '为3名新员工办理入职手续，讲解公司制度。', 'work', NULL, NULL, 1, '2025-11-06 14:00:00');

INSERT INTO tasks (id, title, description, status, priority, color, start_time, end_time, deadline, is_all_day, created_at, created_by, assignee_id, assignee_name, department_id) VALUES
('task-emp1-sep3', '更新招聘渠道', '评估各招聘渠道效果，优化招聘渠道组合。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-09-25 18:00:00', 0, '2025-09-10 09:00:00', 'employee-001', 'employee-001', 'Chen HR Specialist', 'dept-001'),
('task-emp1-oct3', '招聘数据分析', '整理10月招聘数据，制作月度招聘报表。', 'completed', 'p2', '#4CAF50', NULL, NULL, '2025-10-30 18:00:00', 0, '2025-10-20 09:00:00', 'employee-001', 'employee-001', 'Chen HR Specialist', 'dept-001'),
('task-emp1-nov3', '校招宣传准备', '准备校园招聘宣传材料，设计招聘海报。', 'in_progress', 'p1', '#FF9800', NULL, NULL, '2025-11-20 18:00:00', 0, '2025-11-05 09:00:00', 'employee-001', 'employee-001', 'Chen HR Specialist', 'dept-001');

-- ================================================================
-- 数据导入完成
-- ================================================================
SELECT '✅ 成功增加更多测试数据！' AS message;
SELECT '📊 hr_head 用户新增数据统计：' AS info;
SELECT '   9月：新增5条日志，4个任务' AS detail1;
SELECT '   10月：新增6条日志，5个任务' AS detail2;
SELECT '   11月：新增7条日志，5个任务' AS detail3;
SELECT '🎉 月视图数据现在更加丰富了！' AS final_message;













