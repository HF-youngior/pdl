@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ================================================
:: 企业管理系统 - 最新版数据库一键初始化脚本
:: 说明：
::  1) 会删除并重建 enterprise_management 数据库（谨慎！）
::  2) 导入最新版表结构与修复后的示例数据
::  3) 将所有测试账号密码重置为明文（便于联调）
:: ================================================

:: 可配置参数（如需修改请编辑下面几行）
set DB_HOST=localhost
set DB_PORT=3306
set DB_USER=root
:: 从用户运行日志确认的密码（如需覆盖，可在运行前修改此变量）
set DB_PASSWORD=hyx123456

:: MySQL 客户端命令（如未在 PATH 中，请写绝对路径，例如："C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe"）
set MYSQL_CMD=mysql

:: 计算脚本与 SQL 文件路径
set SCRIPT_DIR=%~dp0
set CLEAN_SQL=%SCRIPT_DIR%enterprise_management_clean.sql
set FIXED_DATA_SQL=%SCRIPT_DIR%fixed_enhanced_data.sql
set FORCE_PLAINTEXT_SQL=%SCRIPT_DIR%force_update_passwords.sql

:: 校验文件是否存在
if not exist "%CLEAN_SQL%" (
  echo [ERROR] 缺少文件: %CLEAN_SQL%
  goto :fail
)
if not exist "%FIXED_DATA_SQL%" (
  echo [ERROR] 缺少文件: %FIXED_DATA_SQL%
  goto :fail
)
if not exist "%FORCE_PLAINTEXT_SQL%" (
  echo [WARN] 未找到 %FORCE_PLAINTEXT_SQL% ，将跳过明文密码强制脚本。
)

:: 连接字符串拼装（避免交互式输入）
set MYSQL_BASE=%MYSQL_CMD% -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

:: 显示环境信息
echo Starting Enterprise DB Init...
echo   Host: %DB_HOST%
echo   Port: %DB_PORT%
echo   User: %DB_USER%
echo   Database: enterprise_management

:: 1) 删除并重建数据库（使用 clean 脚本，已包含 DROP/CREATE）
echo.
echo [1/3] 导入最新表结构（含 is_active 等字段）...
%MYSQL_BASE% < "%CLEAN_SQL%"
if errorlevel 1 goto :fail

:: 2) 导入修复后的增强示例数据（避免缺失字段/外键问题）
echo.
echo [2/3] 导入修复的增强示例数据...
%MYSQL_BASE% enterprise_management < "%FIXED_DATA_SQL%"
if errorlevel 1 goto :fail

:: 3) 将密码强制更新为明文，便于测试（若脚本存在）
if exist "%FORCE_PLAINTEXT_SQL%" (
  echo.
  echo [3/3] 强制将用户密码更新为明文...
  %MYSQL_BASE% enterprise_management < "%FORCE_PLAINTEXT_SQL%"
  if errorlevel 1 goto :fail
) else (
  echo [SKIP] 未执行密码强制脚本（文件缺失）。
)

echo.
echo ✅ 数据库初始化完成！
echo    - 架构: 最新版（已包含 users.is_active 等字段）
echo    - 示例数据: 已加载修复后的增强数据
echo    - 账号密码: 已重置为明文便于联调

exit /b 0

:fail
echo.
echo ❌ 初始化失败，请检查以上错误信息。
echo    常见原因：
echo      1) 未安装 MySQL 客户端或未在 PATH 中（修改 MYSQL_CMD）
echo      2) 数据库连接信息不正确（DB_HOST/DB_PORT/DB_USER/DB_PASSWORD）
echo      3) MySQL 服务器未启动
exit /b 1

endlocal
