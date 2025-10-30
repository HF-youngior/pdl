@echo off
chcp 65001 >nul
echo ========================================
echo 重新加载丰富的测试数据
echo ========================================
echo.

echo [1/2] 正在加载数据到数据库...
mysql -h localhost -u root -p23301144 < create_rich_test_data.sql

if %ERRORLEVEL% EQU 0 (
    echo ✓ 数据加载成功！
    echo.
    echo 数据包含:
    echo - 60条日志 ^(9-11月，多个用户^)
    echo - 35条任务 ^(9-11月，多个用户^)
    echo.
    echo ========================================
    echo 数据重新加载完成！
    echo ========================================
) else (
    echo ✗ 数据加载失败！
    echo 请检查MySQL连接和数据库配置
    pause
    exit /b 1
)

pause



















