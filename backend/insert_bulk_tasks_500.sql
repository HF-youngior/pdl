-- 批量插入 1000 条任务数据（用于管理后台任务管理演示）
-- 仅影响 id 以 task-bulk-demo- 前缀的记录，重复执行会先清理旧数据再写入

USE enterprise_management;

-- 关闭外键检查，确保批量写入顺畅
SET FOREIGN_KEY_CHECKS = 0;

-- 清理旧的同前缀数据，避免重复主键/唯一键冲突
DELETE FROM tasks WHERE id LIKE 'task-bulk-demo-%';

SET FOREIGN_KEY_CHECKS = 1;

-- 基于自增变量一次性生成 1000 条任务（兼容 MySQL 5.7，无需 WITH RECURSIVE）
SET @n := 0;

INSERT INTO tasks (
  id,
  assignee_id,
  assignee_name,
  department_id,
  title,
  start_time,
  end_time,
  is_all_day,
  status,
  created_at,
  created_by
) 
SELECT
  CONCAT('task-bulk-demo-', LPAD(@n := @n + 1, 4, '0')) AS id,
  'dept-head-001' AS assignee_id,
  '王人事总监' AS assignee_name,
  'dept-001' AS department_id,
  CONCAT('批量任务示例-', @n, ' / 自动生成') AS title,
  DATE_ADD('2025-12-01 09:00:00', INTERVAL @n DAY) AS start_time,
  DATE_ADD('2025-12-01 18:00:00', INTERVAL @n DAY) AS end_time,
  0 AS is_all_day,
  CASE 
    WHEN @n % 3 = 0 THEN 'pending'
    WHEN @n % 3 = 1 THEN 'in_progress'
    ELSE 'completed'
  END AS status,
  DATE_ADD('2025-11-30 09:00:00', INTERVAL @n DAY) AS created_at,
  'dept-head-001' AS created_by
FROM information_schema.COLUMNS
LIMIT 1000;

-- 结果统计
SELECT '批量任务插入完成' AS message, COUNT(*) AS inserted_count
FROM tasks WHERE id LIKE 'task-bulk-demo-%';



