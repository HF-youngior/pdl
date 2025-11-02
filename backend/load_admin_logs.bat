@echo off
chcp 65001 >nul
setlocal

:: 配置数据库连接（按需修改）
set DB_HOST=localhost
set DB_PORT=3306
set DB_USER=root
set DB_PASSWORD=hyx123456
set DB_NAME=enterprise_management
set MYSQL_CMD=mysql

set SCRIPT_DIR=%~dp0
set SQL_FILE=%SCRIPT_DIR%insert_admin_personal_logs.sql

if not exist "%SQL_FILE%" (
  echo [ERROR] 未找到 SQL 文件: %SQL_FILE%
  exit /b 1
)

echo 正在导入 admin 的个人日志示例数据...
%MYSQL_CMD% -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 %DB_NAME% < "%SQL_FILE%"
if errorlevel 1 (
  echo ✗ 导入失败，请检查 MySQL 连接与权限
  exit /b 1
)

echo ✓ 导入完成。
endlocal
exit /b 0


