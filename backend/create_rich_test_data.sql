-- 创建丰富的测试数据 - 多个用户在不同日期的日志和任务
-- 这个脚本会为2025年9月、10月、11月创建大量数据

USE enterprise_management;

-- 清空现有日志和任务（保留用户和部门数据）
DELETE FROM personal_logs;
DELETE FROM tasks WHERE id LIKE 'test-task-%';

-- ===== 日志数据 (个人日志) =====
-- founder-001 的日志 (9月-11月)
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-f001-sep1', 'founder-001', '公司战略规划讨论', '与管理层讨论了下一季度的战略方向，重点关注市场扩展和产品创新。', 'work', 0, '2025-09-05 09:00:00', '2025-09-05 09:00:00'),
('log-f001-sep2', 'founder-001', '投资人会议准备', '准备了投资人季度会议的材料，包括财务报告和业务进展。', 'work', 1, '2025-09-12 14:30:00', '2025-09-12 14:30:00'),
('log-f001-sep3', 'founder-001', '团队建设', '组织了管理层团建活动。', 'life', 1, '2025-09-22 10:00:00', '2025-09-22 10:00:00'),
('log-f001-oct1', 'founder-001', 'Q3季度总结', '完成了Q3季度的全面总结，各项指标基本达标。', 'work', 1, '2025-10-01 10:30:00', '2025-10-01 10:30:00'),
('log-f001-oct2', 'founder-001', '新产品发布计划', '制定了新产品的发布计划和市场推广策略。', 'work', 1, '2025-10-15 11:00:00', '2025-10-15 11:00:00'),
('log-f001-oct3', 'founder-001', '周末运动', '参加了马拉松比赛。', 'life', 1, '2025-10-20 08:00:00', '2025-10-20 08:00:00'),
('log-f001-nov1', 'founder-001', 'Q4目标制定', '完成了Q4季度目标的制定和分解工作。', 'work', 1, '2025-11-01 09:30:00', '2025-11-01 09:30:00'),
('log-f001-nov2', 'founder-001', '年度预算审批', '审批了各部门的年度预算申请。', 'work', 0, '2025-11-18 15:00:00', '2025-11-18 15:00:00');

-- founder-002 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-f002-sep1', 'founder-002', '产品路线图更新', '更新了产品路线图，增加了几个重要的功能模块。', 'work', 1, '2025-09-08 10:00:00', '2025-09-08 10:00:00'),
('log-f002-sep2', 'founder-002', '技术团队扩张讨论', '与HR讨论了技术团队的扩张计划。', 'work', 0, '2025-09-20 14:00:00', '2025-09-20 14:00:00'),
('log-f002-oct1', 'founder-002', '产品发布会策划', '策划了新产品的发布会，邀请了重要客户和媒体。', 'work', 1, '2025-10-02 14:15:00', '2025-10-02 14:15:00'),
('log-f002-oct2', 'founder-002', '客户反馈分析', '分析了客户的反馈意见，发现了几个改进方向。', 'work', 1, '2025-10-20 16:00:00', '2025-10-20 16:00:00'),
('log-f002-oct3', 'founder-002', '读书会', '参加了技术读书会，分享了新书。', 'life', 1, '2025-10-25 19:00:00', '2025-10-25 19:00:00'),
('log-f002-nov1', 'founder-002', '技术架构优化', '讨论了技术架构的优化方案。', 'work', 1, '2025-11-05 11:00:00', '2025-11-05 11:00:00'),
('log-f002-nov2', 'founder-002', '年终技术规划', '制定了明年的技术发展规划。', 'work', 0, '2025-11-22 10:00:00', '2025-11-22 10:00:00');

-- dept-head-001 (HR部门负责人) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-dh001-sep1', 'dept-head-001', '招聘计划制定', '制定了Q4的招聘计划，重点是技术和销售岗位。', 'work', 1, '2025-09-03 09:00:00', '2025-09-03 09:00:00'),
('log-dh001-sep2', 'dept-head-001', '员工培训方案', '设计了新员工入职培训方案。', 'work', 1, '2025-09-18 13:00:00', '2025-09-18 13:00:00'),
('log-dh001-oct1', 'dept-head-001', '绩效考核方案', '完成了年度绩效考核方案的修订工作。', 'work', 1, '2025-10-03 09:45:00', '2025-10-03 09:45:00'),
('log-dh001-oct2', 'dept-head-001', '薪酬体系优化', '提出了薪酬体系的优化建议。', 'work', 0, '2025-10-22 15:30:00', '2025-10-22 15:30:00'),
('log-dh001-nov1', 'dept-head-001', '年度人力规划', '完成了明年的人力资源规划。', 'work', 1, '2025-11-08 10:00:00', '2025-11-08 10:00:00'),
('log-dh001-nov2', 'dept-head-001', '员工活动策划', '策划了年终员工团建活动。', 'life', 1, '2025-11-25 14:00:00', '2025-11-25 14:00:00');

-- dept-head-002 (财务部门负责人) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-dh002-sep1', 'dept-head-002', '财务报表审核', '审核了8月份的财务报表。', 'work', 1, '2025-09-06 10:00:00', '2025-09-06 10:00:00'),
('log-dh002-sep2', 'dept-head-002', '成本控制分析', '分析了各部门的成本控制情况。', 'work', 1, '2025-09-25 14:00:00', '2025-09-25 14:00:00'),
('log-dh002-oct1', 'dept-head-002', '审计材料整理', '整理了年度审计所需的各项材料。', 'work', 1, '2025-10-05 11:20:00', '2025-10-05 11:20:00'),
('log-dh002-oct2', 'dept-head-002', '投资回报分析', '分析了几个项目的投资回报情况。', 'work', 1, '2025-10-25 16:00:00', '2025-10-25 16:00:00'),
('log-dh002-nov1', 'dept-head-002', '预算执行分析', '分析了年度预算的执行情况。', 'work', 0, '2025-11-10 11:00:00', '2025-11-10 11:00:00'),
('log-dh002-nov2', 'dept-head-002', '年度财务总结', '完成了年度财务总结报告。', 'work', 1, '2025-11-28 15:00:00', '2025-11-28 15:00:00');

-- team-leader-001 (HR团队负责人) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-tl001-sep1', 'team-leader-001', '面试安排', '安排了本周的候选人面试。', 'work', 1, '2025-09-07 09:00:00', '2025-09-07 09:00:00'),
('log-tl001-sep2', 'team-leader-001', 'Offer发放', '向3位候选人发放了Offer。', 'work', 1, '2025-09-22 16:00:00', '2025-09-22 16:00:00'),
('log-tl001-oct1', 'team-leader-001', '新员工入职', '协助5名新员工完成入职手续。', 'work', 1, '2025-10-08 10:00:00', '2025-10-08 10:00:00'),
('log-tl001-oct2', 'team-leader-001', '员工关怀活动', '组织了员工生日会和下午茶活动。', 'life', 1, '2025-10-18 14:30:00', '2025-10-18 14:30:00'),
('log-tl001-nov1', 'team-leader-001', '绩效面谈', '完成了团队成员的绩效面谈。', 'work', 1, '2025-11-12 09:00:00', '2025-11-12 09:00:00'),
('log-tl001-nov2', 'team-leader-001', '年度总结准备', '准备团队的年度工作总结。', 'work', 0, '2025-11-26 16:00:00', '2025-11-26 16:00:00');

-- team-leader-002 (财务团队负责人) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-tl002-sep1', 'team-leader-002', '月度对账', '完成了各部门的月度对账工作。', 'work', 1, '2025-09-10 11:00:00', '2025-09-10 11:00:00'),
('log-tl002-sep2', 'team-leader-002', '税务申报', '完成了9月份的税务申报。', 'work', 1, '2025-09-28 15:00:00', '2025-09-28 15:00:00'),
('log-tl002-oct1', 'team-leader-002', '费用报销审核', '审核了本月的费用报销单据。', 'work', 1, '2025-10-10 13:30:00', '2025-10-10 13:30:00'),
('log-tl002-oct2', 'team-leader-002', '财务系统优化', '提出了财务系统的优化建议。', 'work', 0, '2025-10-28 10:00:00', '2025-10-28 10:00:00'),
('log-tl002-nov1', 'team-leader-002', '年终奖测算', '测算了各部门的年终奖预算。', 'work', 1, '2025-11-15 14:00:00', '2025-11-15 14:00:00'),
('log-tl002-nov2', 'team-leader-002', '财务培训', '组织了财务知识培训。', 'work', 1, '2025-11-29 10:00:00', '2025-11-29 10:00:00');

-- employee-001 (HR普通员工) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-e001-sep1', 'employee-001', '简历筛选', '筛选了50份技术岗位的简历。', 'work', 1, '2025-09-04 10:00:00', '2025-09-04 10:00:00'),
('log-e001-sep2', 'employee-001', '电话面试', '完成了10个候选人的电话面试。', 'work', 1, '2025-09-15 14:00:00', '2025-09-15 14:00:00'),
('log-e001-sep3', 'employee-001', '健身房', '晚上去健身房锻炼了1小时。', 'life', 1, '2025-09-19 19:00:00', '2025-09-19 19:00:00'),
('log-e001-oct1', 'employee-001', '候选人面试', '安排并参与了5场候选人面试。', 'work', 1, '2025-10-06 09:30:00', '2025-10-06 09:30:00'),
('log-e001-oct2', 'employee-001', '招聘数据整理', '整理了Q3的招聘数据报告。', 'work', 1, '2025-10-16 16:00:00', '2025-10-16 16:00:00'),
('log-e001-oct3', 'employee-001', '周末爬山', '和朋友去爬山，天气很好。', 'life', 1, '2025-10-27 10:00:00', '2025-10-27 10:00:00'),
('log-e001-nov1', 'employee-001', 'Offer谈判', '与2位候选人进行薪资谈判。', 'work', 1, '2025-11-04 14:30:00', '2025-11-04 14:30:00'),
('log-e001-nov2', 'employee-001', '招聘渠道优化', '分析了各招聘渠道的效果。', 'work', 0, '2025-11-20 11:00:00', '2025-11-20 11:00:00'),
('log-e001-nov3', 'employee-001', '看电影', '晚上看了新上映的电影。', 'life', 1, '2025-11-23 20:00:00', '2025-11-23 20:00:00');

-- employee-002 (HR普通员工) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-e002-sep1', 'employee-002', '入职培训', '组织了新员工的入职培训。', 'work', 1, '2025-09-09 09:00:00', '2025-09-09 09:00:00'),
('log-e002-sep2', 'employee-002', '员工手册更新', '更新了员工手册的部分内容。', 'work', 1, '2025-09-24 15:00:00', '2025-09-24 15:00:00'),
('log-e002-sep3', 'employee-002', '瑜伽课', '参加了瑜伽课程。', 'life', 1, '2025-09-28 18:00:00', '2025-09-28 18:00:00'),
('log-e002-oct1', 'employee-002', '员工档案整理', '整理了新入职员工的档案。', 'work', 1, '2025-10-09 11:00:00', '2025-10-09 11:00:00'),
('log-e002-oct2', 'employee-002', '社保办理', '为新员工办理了社保。', 'work', 1, '2025-10-19 14:00:00', '2025-10-19 14:00:00'),
('log-e002-nov1', 'employee-002', '年度体检安排', '安排了员工年度体检。', 'work', 1, '2025-11-06 10:00:00', '2025-11-06 10:00:00'),
('log-e002-nov2', 'employee-002', '团建活动策划', '策划年底团建活动。', 'work', 0, '2025-11-21 15:30:00', '2025-11-21 15:30:00');

-- employee-003 (财务普通员工) 的日志
INSERT IGNORE INTO personal_logs (id, user_id, title, content, category, is_completed, created_at, updated_at) VALUES
('log-e003-sep1', 'employee-003', '发票录入', '录入了本周的各类发票。', 'work', 1, '2025-09-11 10:00:00', '2025-09-11 10:00:00'),
('log-e003-sep2', 'employee-003', '费用报销', '处理了20笔费用报销。', 'work', 1, '2025-09-26 14:00:00', '2025-09-26 14:00:00'),
('log-e003-oct1', 'employee-003', '对账工作', '完成了供应商对账工作。', 'work', 1, '2025-10-11 09:00:00', '2025-10-11 09:00:00'),
('log-e003-oct2', 'employee-003', '凭证整理', '整理了9月份的会计凭证。', 'work', 1, '2025-10-21 16:00:00', '2025-10-21 16:00:00'),
('log-e003-oct3', 'employee-003', '音乐会', '晚上去听了音乐会。', 'life', 1, '2025-10-26 19:00:00', '2025-10-26 19:00:00'),
('log-e003-nov1', 'employee-003', '银行对账单', '核对了银行对账单。', 'work', 1, '2025-11-13 11:00:00', '2025-11-13 11:00:00'),
('log-e003-nov2', 'employee-003', '年度账目整理', '整理年度账目准备审计。', 'work', 0, '2025-11-27 14:00:00', '2025-11-27 14:00:00');

-- ===== 任务数据 (tasks) =====
-- founder-001 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-f001-sep1', '完成Q3总结报告', '整理Q3季度的各项数据和成果。', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'completed', '2025-09-30 18:00:00', '2025-09-01 09:00:00', 'founder-001'),
('test-task-f001-oct1', '制定Q4战略目标', '制定Q4季度的战略目标和关键指标。', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'completed', '2025-10-10 17:00:00', '2025-10-01 09:00:00', 'founder-001'),
('test-task-f001-oct2', '新产品发布', '组织新产品的发布会。', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'completed', '2025-10-20 18:00:00', '2025-10-05 10:00:00', 'founder-001'),
('test-task-f001-nov1', '年度预算审批', '审批各部门的年度预算。', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'in_progress', '2025-11-30 18:00:00', '2025-11-01 09:00:00', 'founder-001'),
('test-task-f001-nov2', '年度战略规划', '制定明年的年度战略规划。', 'founder-001', 'Zhang Founder', 'dept-001', 'p0', 'pending', '2025-12-15 18:00:00', '2025-11-15 09:00:00', 'founder-001');

-- founder-002 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-f002-sep1', '产品路线图更新', '更新产品路线图。', 'founder-002', 'Li Founder', 'dept-001', 'p0', 'completed', '2025-09-25 16:00:00', '2025-09-01 10:00:00', 'founder-002'),
('test-task-f002-oct1', '技术架构评审', '评审当前技术架构。', 'founder-002', 'Li Founder', 'dept-001', 'p1', 'completed', '2025-10-15 18:00:00', '2025-10-01 09:00:00', 'founder-002'),
('test-task-f002-nov1', '明年技术规划', '制定明年的技术发展规划。', 'founder-002', 'Li Founder', 'dept-001', 'p0', 'in_progress', '2025-11-30 18:00:00', '2025-11-01 10:00:00', 'founder-002');

-- dept-head-001 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-dh001-sep1', 'Q4招聘计划', '制定Q4招聘计划。', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p0', 'completed', '2025-09-20 17:00:00', '2025-09-01 09:00:00', 'dept-head-001'),
('test-task-dh001-oct1', '绩效考核方案', '修订年度绩效考核方案。', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p0', 'completed', '2025-10-15 16:00:00', '2025-10-01 09:00:00', 'dept-head-001'),
('test-task-dh001-nov1', '年度人力规划', '完成明年人力规划。', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p0', 'completed', '2025-11-20 18:00:00', '2025-11-01 09:00:00', 'dept-head-001'),
('test-task-dh001-nov2', '年终活动策划', '策划年终员工活动。', 'dept-head-001', 'Wang HR Director', 'dept-001', 'p1', 'in_progress', '2025-12-10 18:00:00', '2025-11-10 10:00:00', 'dept-head-001');

-- dept-head-002 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-dh002-sep1', 'Q3财务总结', '完成Q3财务总结。', 'dept-head-002', 'Zhao Finance Director', 'dept-002', 'p0', 'completed', '2025-09-30 18:00:00', '2025-09-01 10:00:00', 'dept-head-002'),
('test-task-dh002-oct1', '审计准备', '准备年度审计材料。', 'dept-head-002', 'Zhao Finance Director', 'dept-002', 'p0', 'completed', '2025-10-20 17:00:00', '2025-10-01 10:00:00', 'dept-head-002'),
('test-task-dh002-nov1', '年度财务报告', '编制年度财务报告。', 'dept-head-002', 'Zhao Finance Director', 'dept-002', 'p0', 'in_progress', '2025-12-05 18:00:00', '2025-11-01 10:00:00', 'dept-head-002');

-- team-leader-001 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-tl001-sep1', '技术岗位招聘', '招聘5名技术人员。', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p0', 'completed', '2025-09-30 16:00:00', '2025-09-01 09:00:00', 'team-leader-001'),
('test-task-tl001-oct1', '新员工入职', '协助新员工入职。', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p1', 'completed', '2025-10-15 17:00:00', '2025-10-01 09:00:00', 'team-leader-001'),
('test-task-tl001-nov1', '绩效面谈', '完成团队绩效面谈。', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p0', 'completed', '2025-11-15 18:00:00', '2025-11-01 09:00:00', 'team-leader-001'),
('test-task-tl001-nov2', '团队年度总结', '完成团队年度总结。', 'team-leader-001', 'Liu HR Team Lead', 'dept-001', 'p1', 'in_progress', '2025-12-01 18:00:00', '2025-11-15 10:00:00', 'team-leader-001');

-- team-leader-002 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-tl002-sep1', '月度财务报表', '完成9月财务报表。', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p0', 'completed', '2025-09-30 18:00:00', '2025-09-25 10:00:00', 'team-leader-002'),
('test-task-tl002-oct1', '费用控制分析', '分析各部门费用控制情况。', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p1', 'completed', '2025-10-25 17:00:00', '2025-10-01 10:00:00', 'team-leader-002'),
('test-task-tl002-nov1', '年终奖测算', '完成年终奖测算。', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p0', 'completed', '2025-11-20 16:00:00', '2025-11-01 10:00:00', 'team-leader-002'),
('test-task-tl002-nov2', '财务系统优化', '优化财务管理系统。', 'team-leader-002', 'Sun HR Team Lead', 'dept-001', 'p2', 'in_progress', '2025-12-15 18:00:00', '2025-11-10 11:00:00', 'team-leader-002');

-- employee-001 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-e001-sep1', '简历筛选', '筛选技术岗位简历。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'completed', '2025-09-10 18:00:00', '2025-09-01 09:00:00', 'employee-001'),
('test-task-e001-sep2', '电话面试', '完成候选人电话面试。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'completed', '2025-09-20 17:00:00', '2025-09-11 09:00:00', 'employee-001'),
('test-task-e001-oct1', '现场面试安排', '安排候选人现场面试。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p0', 'completed', '2025-10-15 16:00:00', '2025-10-01 09:00:00', 'employee-001'),
('test-task-e001-oct2', '招聘数据统计', '统计Q3招聘数据。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p2', 'completed', '2025-10-25 18:00:00', '2025-10-16 10:00:00', 'employee-001'),
('test-task-e001-nov1', 'Offer谈判', '与候选人进行薪资谈判。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p0', 'completed', '2025-11-10 17:00:00', '2025-11-01 09:00:00', 'employee-001'),
('test-task-e001-nov2', '招聘渠道分析', '分析各招聘渠道效果。', 'employee-001', 'Chen HR Specialist', 'dept-001', 'p1', 'in_progress', '2025-11-30 18:00:00', '2025-11-15 10:00:00', 'employee-001');

-- employee-002 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-e002-sep1', '新员工培训', '组织新员工入职培训。', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p0', 'completed', '2025-09-15 17:00:00', '2025-09-01 09:00:00', 'employee-002'),
('test-task-e002-oct1', '员工档案整理', '整理员工档案。', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p1', 'completed', '2025-10-20 16:00:00', '2025-10-01 10:00:00', 'employee-002'),
('test-task-e002-nov1', '年度体检安排', '安排员工年度体检。', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p0', 'completed', '2025-11-15 17:00:00', '2025-11-01 09:00:00', 'employee-002'),
('test-task-e002-nov2', '团建活动策划', '策划年底团建。', 'employee-002', 'Chu HR Specialist', 'dept-001', 'p1', 'in_progress', '2025-12-10 18:00:00', '2025-11-10 10:00:00', 'employee-002');

-- employee-003 的任务
INSERT IGNORE INTO tasks (id, title, description, assignee_id, assignee_name, department_id, priority, status, deadline, created_at, created_by) VALUES
('test-task-e003-sep1', '发票管理', '录入和管理发票。', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p0', 'completed', '2025-09-25 18:00:00', '2025-09-01 10:00:00', 'employee-003'),
('test-task-e003-oct1', '供应商对账', '完成供应商对账。', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p0', 'completed', '2025-10-20 17:00:00', '2025-10-01 10:00:00', 'employee-003'),
('test-task-e003-nov1', '银行对账', '核对银行对账单。', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p0', 'completed', '2025-11-15 16:00:00', '2025-11-01 10:00:00', 'employee-003'),
('test-task-e003-nov2', '年度账目整理', '整理年度账目。', 'employee-003', 'Wei HR Specialist', 'dept-001', 'p0', 'in_progress', '2025-12-05 18:00:00', '2025-11-15 10:00:00', 'employee-003');

-- 显示统计信息
SELECT '=== 数据统计 ===' AS info;
SELECT 'personal_logs' AS table_name, COUNT(*) AS count FROM personal_logs;
SELECT 'tasks' AS table_name, COUNT(*) AS count FROM tasks WHERE id LIKE 'test-task-%';

SELECT '=== 按月份统计日志 ===' AS info;
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS log_count
FROM personal_logs
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;

SELECT '=== 按月份统计任务 ===' AS info;
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS task_count
FROM tasks
WHERE id LIKE 'test-task-%'
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;
