@echo off
chcp 65001 >nul
echo ========================================
echo 打开集成测试报告
echo ========================================
echo.

cd /d "%~dp0"

if exist "index.html" (
    echo 正在打开主报告...
    start index.html
) else (
    echo ❌ 找不到 index.html 文件
    pause
    exit /b 1
)

echo ✅ 报告已在浏览器中打开
timeout /t 2 >nul

