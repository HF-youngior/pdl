-- 删除批量插入的系统日志（仅清理 log-bulk-demo- 前缀）
USE enterprise_management;

DELETE FROM system_logs
WHERE id LIKE 'log-bulk-demo-%';

SELECT '批量系统日志清理完成' AS message, ROW_COUNT() AS deleted_rows;



