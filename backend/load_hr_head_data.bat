@echo off
chcp 65001 >nul
echo ========================================
echo 加载 HR 总监测试数据
echo ========================================
echo.
echo 正在为 hr_head 用户添加 2025年10月份的数据...
echo.

mysql -u root -pZs462581379 < migrations\2025-10-hr-head-data-compatible.sql

echo.
if %ERRORLEVEL% EQU 0 (
    echo ✓ 数据加载成功！
    echo.
    echo 已为 hr_head 用户创建：
    echo   - 10个任务（涵盖招聘、培训、绩效、员工关系等）
    echo   - 16条个人日志（2025年10月1-18日）
    echo   - 日志与任务的关联关系
    echo.
) else (
    echo ✗ 数据加载失败，请检查错误信息
)

echo.
pause

