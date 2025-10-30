-- 更新任务时间，让所有任务都有具体的时间段
-- 并删除一些重复的任务和日志
-- MySQL版本

-- 首先查看当前没有时间段的任务
-- SELECT id, title, start_time, end_time, deadline FROM tasks WHERE start_time IS NULL OR end_time IS NULL;

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

-- 为"无具体时段"的任务设置合理的时间段
-- 更新2025年10月的任务

-- 统一设置日期（HR部门负责人的任务）
-- 第1周：10月1-5日
UPDATE tasks 
SET 
  start_time = '2025-10-01 09:00:00',
  end_time = '2025-10-01 12:00:00'
WHERE title = '完成Q3绩效评估报告' AND DATE(created_at) = '2025-10-01';

UPDATE tasks 
SET 
  start_time = '2025-10-02 09:00:00',
  end_time = '2025-10-04 18:00:00'  -- 跨3天的任务
WHERE title = '中国人民大学招聘会' AND DATE(created_at) BETWEEN '2025-10-02' AND '2025-10-04';

UPDATE tasks 
SET 
  start_time = '2025-10-03 14:00:00',
  end_time = '2025-10-03 16:00:00'
WHERE title = '绩效改进方案' AND DATE(created_at) = '2025-10-03';

-- 第2周：10月7-11日
UPDATE tasks 
SET 
  start_time = '2025-10-07 09:00:00',
  end_time = '2025-10-09 18:00:00'  -- 跨3天
WHERE title = '发放员工工资' AND DATE(created_at) BETWEEN '2025-10-07' AND '2025-10-09';

UPDATE tasks 
SET 
  start_time = '2025-10-08 10:00:00',
  end_time = '2025-10-08 11:30:00'
WHERE title = '学习信息技巧' AND DATE(created_at) = '2025-10-08';

UPDATE tasks 
SET 
  start_time = '2025-10-09 14:00:00',
  end_time = '2025-10-11 17:00:00'  -- 跨3天
WHERE title = '发放国庆培训计划' AND DATE(created_at) BETWEEN '2025-10-09' AND '2025-10-11';

UPDATE tasks 
SET 
  start_time = '2025-10-10 09:00:00',
  end_time = '2025-10-10 17:00:00'
WHERE title = '制度拜访体系宣讲' AND DATE(created_at) = '2025-10-10';

-- 第3周：10月13-17日
UPDATE tasks 
SET 
  start_time = '2025-10-13 09:00:00',
  end_time = '2025-10-16 18:00:00'  -- 跨4天
WHERE title = '校园招聘调研准备' AND DATE(created_at) BETWEEN '2025-10-13' AND '2025-10-16';

UPDATE tasks 
SET 
  start_time = '2025-10-14 14:00:00',
  end_time = '2025-10-14 17:00:00'
WHERE title = '校园招聘筹备详细' AND DATE(created_at) = '2025-10-14';

UPDATE tasks 
SET 
  start_time = '2025-10-15 10:00:00',
  end_time = '2025-10-15 12:00:00'
WHERE title = '投诉处理统计' AND DATE(created_at) = '2025-10-15';

UPDATE tasks 
SET 
  start_time = '2025-10-16 09:00:00',
  end_time = '2025-10-16 11:00:00'
WHERE title = '人力成本成效会议' AND DATE(created_at) = '2025-10-16';

UPDATE tasks 
SET 
  start_time = '2025-10-17 14:00:00',
  end_time = '2025-10-17 16:00:00'
WHERE title = '审核劳动合同' AND DATE(created_at) = '2025-10-17';

-- 第4周：10月21-25日
UPDATE tasks 
SET 
  start_time = '2025-10-21 09:00:00',
  end_time = '2025-10-23 18:00:00'  -- 跨3天
WHERE title = '人才信息分析' AND DATE(created_at) BETWEEN '2025-10-21' AND '2025-10-23';

UPDATE tasks 
SET 
  start_time = '2025-10-22 10:00:00',
  end_time = '2025-10-22 15:00:00'
WHERE title = '制定国际绩效体系' AND DATE(created_at) = '2025-10-22';

UPDATE tasks 
SET 
  start_time = '2025-10-23 09:00:00',
  end_time = '2025-10-25 17:00:00'  -- 跨3天
WHERE title = '离职率分析讨论' AND DATE(created_at) BETWEEN '2025-10-23' AND '2025-10-25';

UPDATE tasks 
SET 
  start_time = '2025-10-24 14:00:00',
  end_time = '2025-10-24 17:00:00'
WHERE title = '保障体系改进作业' AND DATE(created_at) = '2025-10-24';

-- 第5周：10月28-31日
UPDATE tasks 
SET 
  start_time = '2025-10-28 09:00:00',
  end_time = '2025-10-30 18:00:00'  -- 跨3天
WHERE title = '预训实施培训分析' AND DATE(created_at) BETWEEN '2025-10-28' AND '2025-10-30';

UPDATE tasks 
SET 
  start_time = '2025-10-29 10:00:00',
  end_time = '2025-10-29 12:00:00'
WHERE title = '运动赛事' AND DATE(created_at) = '2025-10-29';

UPDATE tasks 
SET 
  start_time = '2025-10-30 14:00:00',
  end_time = '2025-10-31 17:00:00'  -- 跨2天
WHERE title = '观成体验评估工作' AND DATE(created_at) BETWEEN '2025-10-30' AND '2025-10-31';

UPDATE tasks 
SET 
  start_time = '2025-10-31 09:00:00',
  end_time = '2025-10-31 11:00:00'
WHERE title = '考成换经统计体系' AND DATE(created_at) = '2025-10-31';

-- 11月的任务
-- 第1周：11月1-8日
UPDATE tasks 
SET 
  start_time = '2025-11-01 09:00:00',
  end_time = '2025-11-04 18:00:00'  -- 跨4天
WHERE title = '数字化转型项目' AND DATE(created_at) BETWEEN '2025-11-01' AND '2025-11-04';

UPDATE tasks 
SET 
  start_time = '2025-11-04 10:00:00',
  end_time = '2025-11-04 16:00:00'
WHERE title = '人力资源报告' AND DATE(created_at) = '2025-11-04';

UPDATE tasks 
SET 
  start_time = '2025-11-05 09:00:00',
  end_time = '2025-11-07 18:00:00'  -- 跨3天
WHERE title = '薪酬体系分析' AND DATE(created_at) BETWEEN '2025-11-05' AND '2025-11-07';

UPDATE tasks 
SET 
  start_time = '2025-11-06 14:00:00',
  end_time = '2025-11-06 17:00:00'
WHERE title = '客户关系处理' AND DATE(created_at) = '2025-11-06';

UPDATE tasks 
SET 
  start_time = '2025-11-08 09:00:00',
  end_time = '2025-11-08 11:00:00'
WHERE title = '返聘人员规划' AND DATE(created_at) = '2025-11-08';

-- 第2周：11月11-15日
UPDATE tasks 
SET 
  start_time = '2025-11-11 09:00:00',
  end_time = '2025-11-13 18:00:00'  -- 跨3天
WHERE title = '助复核法律手续' AND DATE(created_at) BETWEEN '2025-11-11' AND '2025-11-13';

UPDATE tasks 
SET 
  start_time = '2025-11-12 10:00:00',
  end_time = '2025-11-12 15:00:00'
WHERE title = '校园招聘协调会议' AND DATE(created_at) = '2025-11-12';

UPDATE tasks 
SET 
  start_time = '2025-11-13 09:00:00',
  end_time = '2025-11-15 17:00:00'  -- 跨3天
WHERE title = '人力统计发送' AND DATE(created_at) BETWEEN '2025-11-13' AND '2025-11-15';

UPDATE tasks 
SET 
  start_time = '2025-11-14 14:00:00',
  end_time = '2025-11-14 16:00:00'
WHERE title = '人事档案完善' AND DATE(created_at) = '2025-11-14';

-- 第3周：11月18-22日
UPDATE tasks 
SET 
  start_time = '2025-11-18 09:00:00',
  end_time = '2025-11-20 18:00:00'  -- 跨3天
WHERE title = '京成终经师作工作' AND DATE(created_at) BETWEEN '2025-11-18' AND '2025-11-20';

UPDATE tasks 
SET 
  start_time = '2025-11-19 10:00:00',
  end_time = '2025-11-19 12:00:00'
WHERE title = '制度审理' AND DATE(created_at) = '2025-11-19';

UPDATE tasks 
SET 
  start_time = '2025-11-20 14:00:00',
  end_time = '2025-11-22 17:00:00'  -- 跨3天
WHERE title = '培训计划制定' AND DATE(created_at) BETWEEN '2025-11-20' AND '2025-11-22';

-- 第4周：11月25-29日
UPDATE tasks 
SET 
  start_time = '2025-11-25 09:00:00',
  end_time = '2025-11-27 18:00:00'  -- 跨3天
WHERE title = '绩效复盘会议' AND DATE(created_at) BETWEEN '2025-11-25' AND '2025-11-27';

UPDATE tasks 
SET 
  start_time = '2025-11-26 10:00:00',
  end_time = '2025-11-26 16:00:00'
WHERE title = '离职面谈' AND DATE(created_at) = '2025-11-26';

UPDATE tasks 
SET 
  start_time = '2025-11-27 09:00:00',
  end_time = '2025-11-29 17:00:00'  -- 跨3天
WHERE title = '年度考核准备' AND DATE(created_at) BETWEEN '2025-11-27' AND '2025-11-29';

-- 对于剩余没有时间的任务，设置默认时间（当天9:00-17:00）
UPDATE tasks 
SET 
  start_time = CONCAT(DATE(created_at), ' 09:00:00'),
  end_time = CONCAT(DATE(created_at), ' 17:00:00')
WHERE start_time IS NULL OR end_time IS NULL;

-- 显示更新后的统计
SELECT 
  COUNT(*) as total_tasks,
  COUNT(CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL THEN 1 END) as tasks_with_dates,
  COUNT(CASE WHEN DATEDIFF(end_time, start_time) > 0 THEN 1 END) as multi_day_tasks
FROM tasks;

