@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: 删除前缀为 task-bulk-demo- 的批量任务
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl
set DB_PASSWORD=Pdl123456
set SCRIPT_DIR=%~dp0
set SQL_FILE=%SCRIPT_DIR%delete_bulk_tasks_500.sql

set MYSQL_BASE=mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

echo ================================================
echo 清理批量任务数据
echo ================================================
echo   Host: %DB_HOST%
echo   User: %DB_USER%
echo   Database: enterprise_management
echo   Target prefix: task-bulk-demo-
echo ================================================
echo.

if not exist "%SQL_FILE%" (
  echo [错误] 未找到SQL文件: %SQL_FILE%
  pause
  exit /b 1
)

echo 检查数据库连接...
%MYSQL_BASE% -e "USE enterprise_management;" >nul 2>&1
if errorlevel 1 (
  echo [错误] 无法连接到数据库，请检查连接参数或数据库状态
  pause
  exit /b 1
)
echo ✓ 数据库连接成功
echo.

echo 开始删除批量任务...
%MYSQL_BASE% enterprise_management < "%SQL_FILE%"
if errorlevel 1 (
  echo [错误] 删除任务失败，请检查 SQL
  pause
  exit /b 1
)

echo.
echo ================================================
echo ✓ 批量任务删除完成（task-bulk-demo- 前缀）
echo ================================================
echo.
pause
exit /b 0


