@echo off
echo ========================================
echo 为 hr_head 添加月度任务数据
echo ========================================
echo.

REM 设置数据库连接参数
set DB_HOST=rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl123
set DB_PASS=Pdl1234567
set DB_NAME=enterprise_management

echo 正在执行 SQL 脚本...
echo.

mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASS% %DB_NAME% < add_hr_head_monthly_tasks.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ 月度任务数据添加成功！
    echo ========================================
    echo.
    echo 已添加数据：
    echo - 2025年9月：20条任务
    echo - 2025年10月：20条任务
    echo - 2025年11月：20条任务
    echo - 2025年12月：20条任务
    echo.
    echo 状态分布：
    echo - 待处理：约50%%
    echo - 进行中：约20%%
    echo - 已完成：约30%%
    echo.
    echo 时间跨度：2-4天
    echo ========================================
) else (
    echo.
    echo ========================================
    echo ❌ 数据添加失败，请检查错误信息
    echo ========================================
)

echo.
pause


