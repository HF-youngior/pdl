@echo off
chcp 65001 >nul
echo ========================================
echo 更新 HR Head 任务描述
echo ========================================
echo.

echo 正在更新主要任务描述（58条）...
mysql -h localhost -u root -pasdfgh0625YYH enterprise_management --default-character-set=utf8mb4 -e "source update_hr_task_descriptions.sql"

echo.
echo 正在更新剩余任务描述（22条）...
mysql -h localhost -u root -pasdfgh0625YYH enterprise_management --default-character-set=utf8mb4 -e "source update_remaining_descriptions.sql"

echo.
echo ========================================
echo 验证描述完整性...
echo ========================================
mysql -h localhost -u root -pasdfgh0625YYH enterprise_management --default-character-set=utf8mb4 -e "SELECT COUNT(*) as total_tasks, SUM(CASE WHEN description IS NULL OR description = '' THEN 1 ELSE 0 END) as no_desc, SUM(CASE WHEN description IS NOT NULL AND description != '' THEN 1 ELSE 0 END) as has_desc, MIN(CHAR_LENGTH(description)) as min_length, MAX(CHAR_LENGTH(description)) as max_length, ROUND(AVG(CHAR_LENGTH(description)), 1) as avg_length FROM tasks WHERE assignee_id = 'dept-head-001' AND (id LIKE 'task-hr-sep-%%' OR id LIKE 'task-hr-oct-%%' OR id LIKE 'task-hr-nov-%%' OR id LIKE 'task-hr-dec-%%' OR id LIKE 'task-dec-%%');"

echo.
echo ✅ 所有HR任务描述更新完成！
pause


