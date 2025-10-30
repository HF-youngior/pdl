-- 更新任务时间，让所有任务都有具体的时间段
-- 根据实际的任务数据进行更新

-- 删除重复的日志（保留最新的）
DELETE t1 FROM personal_logs t1
INNER JOIN personal_logs t2 
WHERE t1.id > t2.id 
  AND t1.user_id = t2.user_id 
  AND t1.title = t2.title 
  AND DATE(t1.created_at) = DATE(t2.created_at);

-- 删除重复的任务（同一天、同一标题的任务只保留一个）
DELETE t1 FROM tasks t1
INNER JOIN tasks t2 
WHERE t1.id > t2.id 
  AND t1.assignee_id = t2.assignee_id 
  AND t1.title = t2.title 
  AND DATE(t1.created_at) = DATE(t2.created_at);

-- 10月份：为没有时间的任务设置具体时间段，部分设为跨多天
-- 第1周 (10月1-6日)
UPDATE tasks SET start_time = '2025-10-01 09:00:00', end_time = '2025-10-03 18:00:00' WHERE title = '制定Q4战略目标' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 10:00:00', end_time = '2025-10-02 17:00:00' WHERE title = '绩效考核方案' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 09:30:00', end_time = '2025-10-01 12:00:00' WHERE title = '现场面试安排' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 14:00:00', end_time = '2025-10-01 17:00:00' WHERE title = '技术架构评审' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 09:00:00', end_time = '2025-10-01 11:00:00' WHERE title = '新员工入职' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 09:00:00', end_time = '2025-10-01 12:00:00' WHERE title = '费用控制分析' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 14:00:00', end_time = '2025-10-01 16:00:00' WHERE title = '供应商对账' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 10:00:00', end_time = '2025-10-03 17:00:00' WHERE title = '审计准备' AND DATE(created_at) = '2025-10-01';
UPDATE tasks SET start_time = '2025-10-01 09:00:00', end_time = '2025-10-01 17:00:00' WHERE title = '员工档案整理' AND DATE(created_at) = '2025-10-01';

UPDATE tasks SET start_time = '2025-10-02 09:00:00', end_time = '2025-10-04 18:00:00' WHERE title = '员工福利体系升级方案' AND DATE(created_at) = '2025-10-02';

UPDATE tasks SET start_time = '2025-10-04 09:00:00', end_time = '2025-10-04 12:00:00' WHERE title = '新员工导师制度优化' AND DATE(created_at) = '2025-10-04';

UPDATE tasks SET start_time = '2025-10-05 09:00:00', end_time = '2025-10-05 12:00:00' WHERE title = '新产品发布' AND DATE(created_at) = '2025-10-05';

UPDATE tasks SET start_time = '2025-10-06 09:00:00', end_time = '2025-10-08 17:00:00' WHERE title = '劳动合同到期续签' AND DATE(created_at) = '2025-10-06';

-- 第2周 (10月7-13日)
UPDATE tasks SET start_time = '2025-10-07 10:00:00', end_time = '2025-10-09 18:00:00' WHERE title = '薪酬调研与对标分析' AND DATE(created_at) = '2025-10-07';

UPDATE tasks SET start_time = '2025-10-08 09:00:00', end_time = '2025-10-08 12:00:00' WHERE title = '员工关系危机处理' AND DATE(created_at) = '2025-10-08';

UPDATE tasks SET start_time = '2025-10-09 09:00:00', end_time = '2025-10-11 17:00:00' WHERE title = '组织文化建设活动策划' AND DATE(created_at) = '2025-10-09';

UPDATE tasks SET start_time = '2025-10-10 14:00:00', end_time = '2025-10-12 17:00:00' WHERE title = 'HR系统供应商演示' AND DATE(created_at) = '2025-10-10';

-- 第3周 (10月14-20日)
UPDATE tasks SET start_time = '2025-10-14 09:00:00', end_time = '2025-10-16 18:00:00' WHERE title LIKE '%校园招聘%' AND DATE(created_at) BETWEEN '2025-10-14' AND '2025-10-16';

UPDATE tasks SET start_time = '2025-10-15 10:00:00', end_time = '2025-10-17 17:00:00' WHERE title LIKE '%培训%' AND DATE(created_at) BETWEEN '2025-10-15' AND '2025-10-17' AND start_time IS NULL;

-- 第4周 (10月21-27日)
UPDATE tasks SET start_time = '2025-10-21 09:00:00', end_time = '2025-10-23 18:00:00' WHERE title LIKE '%人才%' AND DATE(created_at) BETWEEN '2025-10-21' AND '2025-10-23' AND start_time IS NULL;

UPDATE tasks SET start_time = '2025-10-24 09:00:00', end_time = '2025-10-26 17:00:00' WHERE title LIKE '%绩效%' AND DATE(created_at) BETWEEN '2025-10-24' AND '2025-10-26' AND start_time IS NULL;

-- 第5周 (10月28-31日)
UPDATE tasks SET start_time = '2025-10-28 10:00:00', end_time = '2025-10-30 18:00:00' WHERE title LIKE '%规划%' AND DATE(created_at) BETWEEN '2025-10-28' AND '2025-10-31' AND start_time IS NULL;

-- 11月份：为没有时间的任务设置具体时间段
-- 第1周 (11月1-3日)
UPDATE tasks SET start_time = '2025-11-01 09:00:00', end_time = '2025-11-03 18:00:00' WHERE title = '年度预算审批' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 09:00:00', end_time = '2025-11-04 17:00:00' WHERE title = '年度人力规划' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 10:00:00', end_time = '2025-11-01 12:00:00' WHERE title = 'Offer谈判' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 14:00:00', end_time = '2025-11-01 16:00:00' WHERE title = '绩效面谈' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 09:00:00', end_time = '2025-11-02 17:00:00' WHERE title = '年度体检安排' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 09:00:00', end_time = '2025-11-01 17:00:00' WHERE title = '银行对账' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 10:00:00', end_time = '2025-11-03 18:00:00' WHERE title = '明年技术规划' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 14:00:00', end_time = '2025-11-01 17:00:00' WHERE title = '年终奖测算' AND DATE(created_at) = '2025-11-01';
UPDATE tasks SET start_time = '2025-11-01 09:00:00', end_time = '2025-11-05 18:00:00' WHERE title = '年度财务报告' AND DATE(created_at) = '2025-11-01';

-- 第2周 (11月4-10日)
UPDATE tasks SET start_time = '2025-11-05 10:00:00', end_time = '2025-11-07 18:00:00' WHERE title = '离职面谈与保留策略' AND DATE(created_at) = '2025-11-05';

UPDATE tasks SET start_time = '2025-11-07 09:00:00', end_time = '2025-11-09 17:00:00' WHERE title = '员工健康管理计划' AND DATE(created_at) = '2025-11-07';

UPDATE tasks SET start_time = '2025-11-08 09:00:00', end_time = '2025-11-10 18:00:00' WHERE title = '年终奖金方案设计' AND DATE(created_at) = '2025-11-08';

UPDATE tasks SET start_time = '2025-11-09 09:00:00', end_time = '2025-11-11 17:00:00' WHERE title = '供应商年度评估' AND DATE(created_at) = '2025-11-09';

-- 第3周 (11月11-17日)
UPDATE tasks SET start_time = '2025-11-11 09:00:00', end_time = '2025-11-13 18:00:00' WHERE title LIKE '%年终%' AND DATE(created_at) BETWEEN '2025-11-11' AND '2025-11-17' AND start_time IS NULL;

UPDATE tasks SET start_time = '2025-11-12 10:00:00', end_time = '2025-11-14 17:00:00' WHERE title LIKE '%员工大会%' AND DATE(created_at) BETWEEN '2025-11-11' AND '2025-11-17' AND start_time IS NULL;

-- 第4周 (11月18-24日)
UPDATE tasks SET start_time = '2025-11-18 09:00:00', end_time = '2025-11-20 18:00:00' WHERE title LIKE '%盘点%' AND DATE(created_at) BETWEEN '2025-11-18' AND '2025-11-24' AND start_time IS NULL;

UPDATE tasks SET start_time = '2025-11-19 10:00:00', end_time = '2025-11-21 17:00:00' WHERE title LIKE '%培训生%' AND DATE(created_at) BETWEEN '2025-11-18' AND '2025-11-24' AND start_time IS NULL;

-- 第5周 (11月25-30日)
UPDATE tasks SET start_time = '2025-11-25 09:00:00', end_time = '2025-11-27 18:00:00' WHERE title LIKE '%年度%' AND DATE(created_at) BETWEEN '2025-11-25' AND '2025-11-30' AND start_time IS NULL;

-- 对于剩余没有时间的任务，设置默认时间（当天9:00-17:00）
UPDATE tasks 
SET 
  start_time = CONCAT(DATE(created_at), ' 09:00:00'),
  end_time = CONCAT(DATE(created_at), ' 17:00:00')
WHERE start_time IS NULL OR end_time IS NULL;


