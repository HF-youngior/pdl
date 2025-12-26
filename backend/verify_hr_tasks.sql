-- ========================================
-- 验证 HR Head 任务数据
-- ========================================

USE enterprise_management;

-- 1. 总体统计
SELECT '=== HR Head 任务总体统计 ===' as info;
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
  SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
FROM tasks
WHERE assignee_id = 'dept-head-001';

-- 2. 月度分布
SELECT '=== 月度任务分布 ===' as info;
SELECT 
  DATE_FORMAT(start_time, '%Y-%m') as month,
  COUNT(*) as task_count,
  SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END) as pending,
  SUM(CASE WHEN status='in_progress' THEN 1 ELSE 0 END) as in_progress,
  SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) as completed,
  ROUND(AVG(TIMESTAMPDIFF(DAY, start_time, end_time)), 1) as avg_days
FROM tasks
WHERE assignee_id = 'dept-head-001'
  AND start_time IS NOT NULL
GROUP BY DATE_FORMAT(start_time, '%Y-%m')
ORDER BY month;

-- 3. 时间跨度分析
SELECT '=== 任务时间跨度分析 ===' as info;
SELECT 
  TIMESTAMPDIFF(DAY, start_time, end_time) as days_span,
  COUNT(*) as task_count
FROM tasks
WHERE assignee_id = 'dept-head-001'
  AND start_time IS NOT NULL
GROUP BY TIMESTAMPDIFF(DAY, start_time, end_time)
ORDER BY days_span;

-- 4. 最近的任务示例（9月前10条）
SELECT '=== 2025年9月任务示例 ===' as info;
SELECT 
  title,
  DATE_FORMAT(start_time, '%Y-%m-%d') as start_date,
  DATE_FORMAT(end_time, '%Y-%m-%d') as end_date,
  TIMESTAMPDIFF(DAY, start_time, end_time) as days,
  status
FROM tasks
WHERE assignee_id = 'dept-head-001'
  AND start_time >= '2025-09-01'
  AND start_time < '2025-10-01'
ORDER BY start_time
LIMIT 10;

SELECT '✅ 验证完成！' as result;


