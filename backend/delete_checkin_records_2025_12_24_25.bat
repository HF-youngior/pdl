@echo off
chcp 65001 >nul
echo ========================================
echo 删除2025年12月24日和25日的签到记录
echo ========================================
echo.

REM 设置数据库连接信息（根据实际情况修改）
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=your_password
set DB_NAME=enterprise_management

echo 正在执行SQL脚本...
echo.

mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < delete_checkin_records_2025_12_24_25.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ 删除成功！
    echo.
    echo 已删除2025-12-24和2025-12-25的所有签到记录
    echo 已恢复相关用户的积分
    echo 已删除相关的积分流水记录
) else (
    echo.
    echo ❌ 删除失败，请检查：
    echo 1. 数据库连接信息是否正确
    echo 2. MySQL服务是否运行
    echo 3. 数据库名称是否正确
)

echo.
pause

