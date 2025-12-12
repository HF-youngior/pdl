@echo off
chcp 65001 >nul
echo ========================================
echo 生成测试统计报告
echo ========================================
echo.

cd /d "%~dp0\..\backend"

echo 正在生成测试统计...
node test-statistics.js

if %errorlevel% equ 0 (
    echo.
    echo ✅ 统计已生成: backend\test-statistics.json
    echo.
    echo 是否要查看统计结果？(Y/N)
    set /p open="> "
    if /i "%open%"=="Y" (
        notepad test-statistics.json
    )
) else (
    echo.
    echo ❌ 生成失败，请检查错误信息
)

echo.
pause

