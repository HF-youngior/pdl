@echo off
chcp 65001 >nul
echo 重新加载个人日志数据...
echo.

REM Set database connection parameters
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=hyx123456
set DB_NAME=enterprise_management
set DB_PORT=3306

echo 步骤 1: 删除现有的个人日志数据...
mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "DELETE FROM personal_logs WHERE id LIKE 'log-%%';"

if %errorlevel% neq 0 (
    echo Error: Failed to delete existing logs
    pause
    exit /b 1
)

echo 步骤 2: 重新加载修复后的日志数据...
mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < fixed_enhanced_data.sql

if %errorlevel% neq 0 (
    echo Error: Failed to reload log data
    pause
    exit /b 1
)

echo.
echo ✓ 个人日志数据重新加载成功！
echo.
echo 现在日志数据的 created_at 字段已被设置为 2025年10月的固定日期
echo 每次重新运行此脚本，日期都不会改变（除非主键冲突）
echo.
pause









