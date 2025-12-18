@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: 批量插入 1000 条任务，用于后台“任务管理”演示
set DB_HOST=rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl123
set DB_PASSWORD=Pdl1234567
set SCRIPT_DIR=%~dp0
set SQL_FILE=%SCRIPT_DIR%insert_bulk_tasks_500.sql

set MYSQL_BASE=mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

echo ================================================
echo 批量插入任务数据
echo ================================================
echo   Host: %DB_HOST%
echo   User: %DB_USER%
echo   Database: enterprise_management
echo   Records: 1000
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

echo 开始写入 1000 条任务...
%MYSQL_BASE% enterprise_management < "%SQL_FILE%"
if errorlevel 1 (
  echo [错误] 插入任务失败，请检查 SQL
  pause
  exit /b 1
)

echo.
echo ================================================
echo ✓ 批量任务插入完成（task-bulk-demo- 前缀）
echo 在管理后台“任务管理”刷新即可查看 500+ 条记录
echo ================================================
echo.
pause
exit /b 0




