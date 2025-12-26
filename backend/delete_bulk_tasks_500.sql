-- 删除批量插入的任务（仅清理 task-bulk-demo- 前缀）
USE enterprise_management;

DELETE FROM tasks
WHERE id LIKE 'task-bulk-demo-%';

SELECT '批量任务清理完成' AS message, ROW_COUNT() AS deleted_rows;


