@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: ================================================
:: 企业管理系统 - 完整数据初始化脚本
:: 说明：
::  1) 会删除并重建 enterprise_management 数据库（谨慎！）
::  2) 导入完整表结构（包含AI和MBTI模块）
::  3) 加载所有测试数据（用户、任务、日志、MBTI、AI分析等）
::  4) 将所有账号密码重置为明文（便于联调）
:: ================================================

:: 可配置参数
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl
set DB_PASSWORD=Pdl1234567
set MYSQL_CMD=mysql
set SCRIPT_DIR=%~dp0

:: 连接字符串
set MYSQL_BASE=%MYSQL_CMD% -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

:: 显示环境信息
echo ================================================
echo Starting Complete Data Initialization...
echo ================================================
echo   Host: %DB_HOST%
echo   Port: %DB_PORT%
echo   User: %DB_USER%
echo   Database: enterprise_management
echo ================================================
echo.

:: 检查必需文件
set CLEAN_SQL=%SCRIPT_DIR%enterprise_management_clean.sql
set FIXED_DATA_SQL=%SCRIPT_DIR%fixed_enhanced_data.sql
set FORCE_PLAINTEXT_SQL=%SCRIPT_DIR%force_update_passwords.sql
set MBTI_TABLE_SQL=%SCRIPT_DIR%mbti_records_table.sql
set MBTI_DATA_SQL=%SCRIPT_DIR%mbti_test_data.sql
set PERSONAL_LOGS_SQL=%SCRIPT_DIR%migrations\2025-10-sample-personal-logs.sql
set HR_HEAD_DATA_SQL=%SCRIPT_DIR%migrations\2025-10-hr-head-data-compatible.sql

if not exist "%CLEAN_SQL%" (
  echo [ERROR] 缺少文件: %CLEAN_SQL%
  goto :fail
)
if not exist "%FIXED_DATA_SQL%" (
  echo [ERROR] 缺少文件: %FIXED_DATA_SQL%
  goto :fail
)

:: 步骤1: 导入基础表结构
echo.
echo [1/7] 导入基础表结构（含 is_active 等字段）...
%MYSQL_BASE% < "%CLEAN_SQL%"
if errorlevel 1 goto :fail
echo ✓ 基础表结构导入成功

:: 步骤2: 导入增强示例数据
echo.
echo [2/7] 导入增强示例数据（任务、日志等）...
%MYSQL_BASE% enterprise_management < "%FIXED_DATA_SQL%"
if errorlevel 1 goto :fail
echo ✓ 增强示例数据导入成功

:: 步骤3: 创建MBTI表
echo.
echo [3/7] 创建MBTI记录表...
if exist "%MBTI_TABLE_SQL%" (
  %MYSQL_BASE% enterprise_management < "%MBTI_TABLE_SQL%"
  if errorlevel 1 (
    echo [WARN] MBTI表创建失败，可能已存在
  ) else (
    echo ✓ MBTI记录表创建成功
  )
) else (
  echo [SKIP] 未找到MBTI表脚本，跳过
)

:: 步骤4: 加载MBTI测试数据
echo.
echo [4/7] 加载MBTI测试数据...
if exist "%MBTI_DATA_SQL%" (
  %MYSQL_BASE% enterprise_management < "%MBTI_DATA_SQL%"
  if errorlevel 1 (
    echo [WARN] MBTI测试数据加载失败
  ) else (
    echo ✓ MBTI测试数据加载成功
  )
) else (
  echo [SKIP] 未找到MBTI测试数据脚本，跳过
)

:: 步骤5: 加载个人日志示例数据
echo.
echo [5/7] 加载个人日志示例数据...
if exist "%PERSONAL_LOGS_SQL%" (
  %MYSQL_BASE% enterprise_management < "%PERSONAL_LOGS_SQL%"
  if errorlevel 1 (
    echo [WARN] 个人日志示例数据加载失败
  ) else (
    echo ✓ 个人日志示例数据加载成功
  )
) else (
  echo [SKIP] 未找到个人日志示例数据脚本，跳过
)

:: 步骤6: 加载HR总监数据
echo.
echo [6/7] 加载HR总监测试数据...
if exist "%HR_HEAD_DATA_SQL%" (
  %MYSQL_BASE% enterprise_management < "%HR_HEAD_DATA_SQL%"
  if errorlevel 1 (
    echo [WARN] HR总监测试数据加载失败
  ) else (
    echo ✓ HR总监测试数据加载成功
  )
) else (
  echo [SKIP] 未找到HR总监测试数据脚本，跳过
)

:: 步骤7: 强制将密码更新为明文（便于测试）
echo.
echo [7/7] 强制将用户密码更新为明文...
if exist "%FORCE_PLAINTEXT_SQL%" (
  %MYSQL_BASE% enterprise_management < "%FORCE_PLAINTEXT_SQL%"
  if errorlevel 1 (
    echo [WARN] 密码更新失败
  ) else (
    echo ✓ 密码已重置为明文便于联调
  )
) else (
  echo [SKIP] 未找到密码强制脚本，跳过
)

:: 显示初始化总结
echo.
echo ================================================
echo ✅ 数据库完整初始化完成！
echo ================================================
echo.
echo 📊 已加载的数据:
echo    ✓ 基础表结构（用户、部门、任务、日志等）
echo    ✓ 增强示例数据（任务、日志、系统日志）
echo    ✓ MBTI记录表和数据
echo    ✓ 个人日志示例数据
echo    ✓ HR总监测试数据
echo    ✓ 账号密码已重置为明文
echo.
echo 👤 测试账户:
echo    管理员: admin / admin123
echo    创始人: founder1 / founder123
echo    人事总监: hr_head / hr123
echo    财务总监: finance_head / finance123
echo    宣传总监: marketing_head / marketing123
echo    员工: employee1 / employee123
echo.
echo 📌 下一步:
echo    1. 启动后端: cd backend && start_enterprise_backend_correct.bat
echo    2. 测试连接: 运行 测试API连接.bat
echo    3. 启动应用: flutter run
echo.
echo ================================================

exit /b 0

:fail
echo.
echo ================================================
echo ❌ 初始化失败，请检查以上错误信息
echo ================================================
echo.
echo 常见原因:
echo   • MySQL 服务器未启动
echo   • 数据库连接信息不正确（DB_HOST/DB_PORT/DB_USER/DB_PASSWORD）
echo   • MySQL 客户端未在 PATH 中
echo   • SQL 文件缺失或路径错误
echo.
pause
exit /b 1

endlocal

