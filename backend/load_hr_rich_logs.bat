@echo off
chcp 65001 >nul
echo ========================================
echo 加载 HR 总监大量日志数据
echo ========================================
echo.
echo 正在为 hr_head 用户添加 2025年9-11月的大量日志...
echo   - 覆盖约2/3的天数
echo   - 每天2-3条日志
echo   - 约150条日志
echo.

mysql -u root -pZs462581379 < insert_hr_head_rich_logs.sql

echo.
if %ERRORLEVEL% EQU 0 (
    echo ✓ 数据加载成功！
    echo.
    echo 已为 hr_head 用户创建大量日志：
    echo   - 时间范围：2025年9-11月
    echo   - 日志分类：工作、会议、个人、学习
    echo   - 大部分日志有具体时间段
    echo.
) else (
    echo ✗ 数据加载失败，请检查错误信息
)

echo.
pause

