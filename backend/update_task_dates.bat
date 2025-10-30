@echo off
chcp 65001 >nul
echo 正在更新任务时间数据...
echo.

sqlite3 pdl.db < update_task_dates.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ 任务时间更新成功！
    echo.
    echo 查看更新后的任务数据...
    node check_updated_tasks.js
) else (
    echo.
    echo ✗ 更新失败，请检查SQL脚本
)

pause


