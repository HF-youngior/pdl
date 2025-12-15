-- 批量插入 1000 条系统日志（用于系统日志演示）
-- 仅影响 id 以 log-bulk-demo- 前缀的记录，重复执行会先清理旧数据再写入

USE enterprise_management;

-- 关闭外键检查
SET FOREIGN_KEY_CHECKS = 0;

-- 清理旧的同前缀数据
DELETE FROM system_logs WHERE id LIKE 'log-bulk-demo-%';

SET FOREIGN_KEY_CHECKS = 1;

-- 基于自增变量一次性生成 1000 条系统日志（兼容 MySQL 5.7，无需 WITH RECURSIVE）
SET @n := 0;

INSERT INTO system_logs (
  id,
  user_id,
  user_name,
  action,
  description,
  category,
  created_at,
  metadata
)
SELECT
  CONCAT('log-bulk-demo-', LPAD(@n := @n + 1, 4, '0')) AS id,
  'admin-001' AS user_id,
  '系统管理员' AS user_name,
  CONCAT('批量系统日志示例-', @n) AS action,
  CONCAT('这是批量生成的系统日志示例第 ', @n, ' 条，用于系统日志列表展示。') AS description,
  CASE 
    WHEN @n % 3 = 0 THEN 'system'
    WHEN @n % 3 = 1 THEN 'security'
    ELSE 'business'
  END AS category,
  DATE_ADD('2025-12-01 08:00:00', INTERVAL @n HOUR) AS created_at,
  NULL AS metadata
FROM information_schema.COLUMNS
LIMIT 1000;

-- 结果统计
SELECT '批量系统日志插入完成' AS message, COUNT(*) AS inserted_count
FROM system_logs WHERE id LIKE 'log-bulk-demo-%';



