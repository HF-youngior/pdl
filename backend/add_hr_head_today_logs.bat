@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: ================================================
:: 为 hr_head 用户添加今日日志数据
:: 用户: hr_head (dept-head-001)
:: 日期: 当前日期
:: ================================================

:: 可配置参数
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl
set DB_PASSWORD=Pdl123456
set SCRIPT_DIR=%~dp0

:: 连接字符串
set MYSQL_BASE=mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

:: 显示环境信息
echo ================================================
echo 为 hr_head 用户添加今日日志数据
echo ================================================
echo   Host: %DB_HOST%
echo   User: %DB_USER%
echo   Database: enterprise_management
echo   User ID: dept-head-001 (hr_head)
echo   Date: %date%
echo ================================================
echo.

:: 检查数据库是否存在
echo 检查数据库连接...
%MYSQL_BASE% -e "USE enterprise_management;" >nul 2>&1
if errorlevel 1 (
  echo [错误] 无法连接到数据库，请检查：
  echo   1. MySQL服务是否已启动
  echo   2. 数据库连接参数是否正确
  echo   3. 数据库是否已初始化
  pause
  exit /b 1
)
echo ✓ 数据库连接成功
echo.

:: 检查SQL文件是否存在
if not exist "%SCRIPT_DIR%add_hr_head_today_logs.sql" (
  echo [错误] 未找到SQL文件: add_hr_head_today_logs.sql
  echo 请确保该文件与bat文件在同一目录下
  pause
  exit /b 1
)

:: 执行SQL脚本
echo 正在添加今日日志数据...
echo.
%MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%add_hr_head_today_logs.sql"
if errorlevel 1 (
  echo.
  echo [错误] 添加日志数据失败
  echo 请检查SQL文件内容是否正确
  pause
  exit /b 1
)

echo.
echo ================================================
echo ✓ 今日日志添加成功！
echo ================================================
echo.
echo 提示：
echo   • 已为 hr_head 用户添加了4条今日日志
echo   • 包括：工作日志、学习日志、个人日志
echo   • 可以在AI地图的词云分析功能中查看和分析
echo.
echo 登录信息：
echo   用户名: hr_head
echo   密码: hr123
echo.
pause
exit /b 0

